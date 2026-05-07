-- Social spine: friend requests + friendships + 1v1 challenges + blocks +
-- reports + activity feed + group challenges + notifications.
-- All tables get RLS, all writes go through SECURITY DEFINER RPCs that
-- enforce the rules (so the client doesn't have to be trusted).

-- ============================================================================
-- 0. Profile additions
-- ============================================================================

alter table user_profiles
    add column if not exists privacy_mode text not null default 'public'
        check (privacy_mode in ('public', 'friends_only', 'private')),
    add column if not exists allow_username_search boolean not null default true,
    add column if not exists username_changed_at timestamptz;

-- Case-insensitive uniqueness on username (skip empty rows).
create unique index if not exists user_profiles_username_unique
    on user_profiles (lower(username))
    where username <> '';

-- ============================================================================
-- 1. Friend requests + friendships
-- ============================================================================

create table if not exists friend_requests (
    id uuid primary key default gen_random_uuid(),
    from_user_id uuid not null references user_profiles(id) on delete cascade,
    to_user_id uuid not null references user_profiles(id) on delete cascade,
    status text not null default 'pending'
        check (status in ('pending', 'accepted', 'declined', 'cancelled')),
    created_at timestamptz not null default now(),
    responded_at timestamptz,
    constraint friend_requests_no_self check (from_user_id <> to_user_id)
);

-- Only one active (pending/accepted) request per ordered pair.
create unique index if not exists friend_requests_active_pair
    on friend_requests (from_user_id, to_user_id)
    where status in ('pending', 'accepted');

create index if not exists friend_requests_to_user_idx
    on friend_requests (to_user_id) where status = 'pending';
create index if not exists friend_requests_from_user_idx
    on friend_requests (from_user_id) where status = 'pending';

-- Canonical-pair friendship table. Always stores the smaller uuid as user_a
-- so a friendship can't be duplicated.
create table if not exists friendships (
    user_a uuid not null references user_profiles(id) on delete cascade,
    user_b uuid not null references user_profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (user_a, user_b),
    constraint friendships_canonical_order check (user_a < user_b)
);

create index if not exists friendships_user_b_idx on friendships (user_b);

alter table friend_requests enable row level security;
alter table friendships enable row level security;

drop policy if exists friend_requests_read_own on friend_requests;
create policy friend_requests_read_own on friend_requests
    for select using (auth.uid() = from_user_id or auth.uid() = to_user_id);

drop policy if exists friendships_read_own on friendships;
create policy friendships_read_own on friendships
    for select using (auth.uid() = user_a or auth.uid() = user_b);

-- Helper: canonical-pair tuple for two uuids.
create or replace function _canonical_pair(a uuid, b uuid)
returns table(user_a uuid, user_b uuid)
language sql
immutable
as $$
    select least(a, b), greatest(a, b)
$$;

-- ----------------------------------------------------------------------------
-- send_friend_request: target by username, blocks self, ignores blocked users.
-- Creates a pending row; if a row already exists in either direction returns
-- a soft "already_pending" / "already_friends" rather than blowing up.
-- ----------------------------------------------------------------------------
create or replace function send_friend_request(p_to_username text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_from uuid := auth.uid();
    v_to uuid;
    v_pair record;
    v_request_id uuid;
begin
    if v_from is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    select id into v_to
    from user_profiles
    where lower(username) = lower(p_to_username)
      and username <> ''
      and allow_username_search = true
    limit 1;

    if v_to is null then
        return jsonb_build_object('ok', false, 'reason', 'user_not_found');
    end if;

    if v_to = v_from then
        return jsonb_build_object('ok', false, 'reason', 'self_target');
    end if;

    -- Block check (either direction).
    if exists (
        select 1 from blocks
        where (blocker_id = v_to and blocked_id = v_from)
           or (blocker_id = v_from and blocked_id = v_to)
    ) then
        return jsonb_build_object('ok', false, 'reason', 'blocked');
    end if;

    -- Already friends?
    select user_a, user_b into v_pair from _canonical_pair(v_from, v_to);
    if exists (select 1 from friendships
               where user_a = v_pair.user_a and user_b = v_pair.user_b) then
        return jsonb_build_object('ok', false, 'reason', 'already_friends');
    end if;

    -- Existing pending request either direction?
    if exists (select 1 from friend_requests
               where status = 'pending'
                 and ((from_user_id = v_from and to_user_id = v_to)
                   or (from_user_id = v_to and to_user_id = v_from))) then
        return jsonb_build_object('ok', false, 'reason', 'already_pending');
    end if;

    insert into friend_requests (from_user_id, to_user_id)
    values (v_from, v_to)
    returning id into v_request_id;

    perform _enqueue_notification(
        v_to,
        'friend_request_received',
        jsonb_build_object('request_id', v_request_id, 'from_user_id', v_from)
    );

    return jsonb_build_object('ok', true, 'request_id', v_request_id);
end;
$$;

-- ----------------------------------------------------------------------------
-- respond_friend_request: accept or decline a pending request addressed to me.
-- On accept, inserts the canonical friendship row.
-- ----------------------------------------------------------------------------
create or replace function respond_friend_request(p_request_id uuid, p_accept boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
    v_req record;
    v_pair record;
begin
    if v_me is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    select * into v_req from friend_requests where id = p_request_id;
    if v_req is null then
        return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;

    if v_req.to_user_id <> v_me then
        return jsonb_build_object('ok', false, 'reason', 'not_recipient');
    end if;

    if v_req.status <> 'pending' then
        return jsonb_build_object('ok', false, 'reason', 'not_pending');
    end if;

    update friend_requests
       set status = case when p_accept then 'accepted' else 'declined' end,
           responded_at = now()
     where id = p_request_id;

    if p_accept then
        select user_a, user_b into v_pair
        from _canonical_pair(v_req.from_user_id, v_req.to_user_id);
        insert into friendships (user_a, user_b)
        values (v_pair.user_a, v_pair.user_b)
        on conflict do nothing;

        perform _enqueue_notification(
            v_req.from_user_id,
            'friend_request_accepted',
            jsonb_build_object('by_user_id', v_me)
        );
    end if;

    return jsonb_build_object('ok', true, 'accepted', p_accept);
end;
$$;

-- ----------------------------------------------------------------------------
-- cancel_friend_request: only the sender can cancel a pending request.
-- ----------------------------------------------------------------------------
create or replace function cancel_friend_request(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
begin
    if v_me is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    update friend_requests
       set status = 'cancelled', responded_at = now()
     where id = p_request_id
       and from_user_id = v_me
       and status = 'pending';

    if not found then
        return jsonb_build_object('ok', false, 'reason', 'not_found_or_invalid_state');
    end if;
    return jsonb_build_object('ok', true);
end;
$$;

-- ----------------------------------------------------------------------------
-- remove_friendship: bilateral removal — both users lose the friendship.
-- ----------------------------------------------------------------------------
create or replace function remove_friendship(p_other_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
    v_pair record;
begin
    if v_me is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    select user_a, user_b into v_pair from _canonical_pair(v_me, p_other_user_id);
    delete from friendships where user_a = v_pair.user_a and user_b = v_pair.user_b;
    return jsonb_build_object('ok', true);
end;
$$;

-- ============================================================================
-- 2. Blocks + reports
-- ============================================================================

create table if not exists blocks (
    blocker_id uuid not null references user_profiles(id) on delete cascade,
    blocked_id uuid not null references user_profiles(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (blocker_id, blocked_id),
    constraint blocks_no_self check (blocker_id <> blocked_id)
);

create table if not exists reports (
    id uuid primary key default gen_random_uuid(),
    reporter_id uuid not null references user_profiles(id) on delete cascade,
    reported_user_id uuid not null references user_profiles(id) on delete cascade,
    reason text not null,
    details text,
    created_at timestamptz not null default now()
);

alter table blocks enable row level security;
alter table reports enable row level security;

drop policy if exists blocks_read_own on blocks;
create policy blocks_read_own on blocks
    for select using (auth.uid() = blocker_id);

drop policy if exists reports_read_none on reports;
create policy reports_read_none on reports
    for select using (false); -- only service role / admin can read

-- block_user: blocks the target and removes any existing friendship + pending requests.
create or replace function block_user(p_other_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
    v_pair record;
begin
    if v_me is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;
    if v_me = p_other_user_id then
        return jsonb_build_object('ok', false, 'reason', 'self_target');
    end if;

    insert into blocks (blocker_id, blocked_id)
    values (v_me, p_other_user_id)
    on conflict do nothing;

    select user_a, user_b into v_pair from _canonical_pair(v_me, p_other_user_id);
    delete from friendships where user_a = v_pair.user_a and user_b = v_pair.user_b;

    update friend_requests
       set status = 'cancelled', responded_at = now()
     where status = 'pending'
       and ((from_user_id = v_me and to_user_id = p_other_user_id)
         or (from_user_id = p_other_user_id and to_user_id = v_me));

    return jsonb_build_object('ok', true);
end;
$$;

create or replace function unblock_user(p_other_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid();
begin
    if v_me is null then return jsonb_build_object('ok', false, 'reason', 'unauthenticated'); end if;
    delete from blocks where blocker_id = v_me and blocked_id = p_other_user_id;
    return jsonb_build_object('ok', true);
end;
$$;

create or replace function report_user(p_other_user_id uuid, p_reason text, p_details text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid(); v_id uuid;
begin
    if v_me is null then return jsonb_build_object('ok', false, 'reason', 'unauthenticated'); end if;
    insert into reports (reporter_id, reported_user_id, reason, details)
    values (v_me, p_other_user_id, p_reason, p_details)
    returning id into v_id;
    return jsonb_build_object('ok', true, 'report_id', v_id);
end;
$$;

-- ============================================================================
-- 3. 1v1 Challenges
-- ============================================================================

create table if not exists challenges (
    id uuid primary key default gen_random_uuid(),
    challenger_id uuid not null references user_profiles(id) on delete cascade,
    opponent_id uuid not null references user_profiles(id) on delete cascade,
    status text not null default 'pending'
        check (status in ('pending', 'accepted', 'in_progress', 'completed', 'declined', 'expired')),
    category text not null default 'physique',
    challenger_score double precision,
    opponent_score double precision,
    challenger_photo_url text,
    opponent_photo_url text,
    winner_user_id uuid references user_profiles(id),
    created_at timestamptz not null default now(),
    responded_at timestamptz,
    completed_at timestamptz,
    constraint challenges_no_self check (challenger_id <> opponent_id)
);

create index if not exists challenges_opponent_idx on challenges (opponent_id, status);
create index if not exists challenges_challenger_idx on challenges (challenger_id, status);

alter table challenges enable row level security;
drop policy if exists challenges_read_own on challenges;
create policy challenges_read_own on challenges
    for select using (auth.uid() = challenger_id or auth.uid() = opponent_id);

create or replace function send_challenge(p_opponent_username text, p_category text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
    v_opp uuid;
    v_pair record;
    v_id uuid;
begin
    if v_me is null then return jsonb_build_object('ok', false, 'reason', 'unauthenticated'); end if;

    select id into v_opp from user_profiles
    where lower(username) = lower(p_opponent_username) and username <> '' limit 1;
    if v_opp is null then
        return jsonb_build_object('ok', false, 'reason', 'user_not_found');
    end if;
    if v_opp = v_me then
        return jsonb_build_object('ok', false, 'reason', 'self_target');
    end if;

    -- Must be friends to challenge.
    select user_a, user_b into v_pair from _canonical_pair(v_me, v_opp);
    if not exists (select 1 from friendships
                   where user_a = v_pair.user_a and user_b = v_pair.user_b) then
        return jsonb_build_object('ok', false, 'reason', 'not_friends');
    end if;

    insert into challenges (challenger_id, opponent_id, category)
    values (v_me, v_opp, p_category)
    returning id into v_id;

    perform _enqueue_notification(
        v_opp, 'challenge_received',
        jsonb_build_object('challenge_id', v_id, 'from_user_id', v_me, 'category', p_category)
    );

    return jsonb_build_object('ok', true, 'challenge_id', v_id);
end;
$$;

create or replace function respond_challenge(p_challenge_id uuid, p_accept boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid(); v_ch record;
begin
    if v_me is null then return jsonb_build_object('ok', false, 'reason', 'unauthenticated'); end if;
    select * into v_ch from challenges where id = p_challenge_id;
    if v_ch is null or v_ch.opponent_id <> v_me or v_ch.status <> 'pending' then
        return jsonb_build_object('ok', false, 'reason', 'invalid_state');
    end if;
    update challenges
       set status = case when p_accept then 'accepted' else 'declined' end,
           responded_at = now()
     where id = p_challenge_id;
    perform _enqueue_notification(
        v_ch.challenger_id,
        case when p_accept then 'challenge_accepted' else 'challenge_declined' end,
        jsonb_build_object('challenge_id', p_challenge_id, 'by_user_id', v_me)
    );
    return jsonb_build_object('ok', true, 'accepted', p_accept);
end;
$$;

-- submit_challenge_score: the caller submits their own score + photo URL.
-- When both scores are in, the challenge auto-completes and a winner is set.
create or replace function submit_challenge_score(
    p_challenge_id uuid,
    p_score double precision,
    p_photo_url text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
    v_ch record;
    v_both boolean := false;
    v_winner uuid;
begin
    if v_me is null then return jsonb_build_object('ok', false, 'reason', 'unauthenticated'); end if;
    select * into v_ch from challenges where id = p_challenge_id;
    if v_ch is null then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
    if v_ch.status not in ('accepted', 'in_progress') then
        return jsonb_build_object('ok', false, 'reason', 'invalid_state');
    end if;

    if v_me = v_ch.challenger_id then
        update challenges
           set challenger_score = p_score,
               challenger_photo_url = p_photo_url,
               status = 'in_progress'
         where id = p_challenge_id;
    elsif v_me = v_ch.opponent_id then
        update challenges
           set opponent_score = p_score,
               opponent_photo_url = p_photo_url,
               status = 'in_progress'
         where id = p_challenge_id;
    else
        return jsonb_build_object('ok', false, 'reason', 'not_participant');
    end if;

    -- Re-fetch to check both scores
    select * into v_ch from challenges where id = p_challenge_id;
    if v_ch.challenger_score is not null and v_ch.opponent_score is not null then
        v_winner := case when v_ch.challenger_score >= v_ch.opponent_score
                         then v_ch.challenger_id else v_ch.opponent_id end;
        update challenges
           set status = 'completed', winner_user_id = v_winner, completed_at = now()
         where id = p_challenge_id;

        perform _enqueue_notification(v_ch.challenger_id, 'challenge_completed',
            jsonb_build_object('challenge_id', p_challenge_id, 'winner_id', v_winner));
        perform _enqueue_notification(v_ch.opponent_id, 'challenge_completed',
            jsonb_build_object('challenge_id', p_challenge_id, 'winner_id', v_winner));
        v_both := true;
    end if;

    return jsonb_build_object('ok', true, 'completed', v_both);
end;
$$;

-- ============================================================================
-- 4. Notifications inbox
-- ============================================================================

create table if not exists notifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references user_profiles(id) on delete cascade,
    kind text not null,
    payload jsonb not null default '{}'::jsonb,
    read boolean not null default false,
    created_at timestamptz not null default now()
);

create index if not exists notifications_user_unread_idx
    on notifications (user_id, read, created_at desc);

alter table notifications enable row level security;
drop policy if exists notifications_read_own on notifications;
create policy notifications_read_own on notifications
    for select using (auth.uid() = user_id);
drop policy if exists notifications_update_own on notifications;
create policy notifications_update_own on notifications
    for update using (auth.uid() = user_id);

-- Internal helper used by RPCs above to drop a notification on a user.
create or replace function _enqueue_notification(p_user_id uuid, p_kind text, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into notifications (user_id, kind, payload) values (p_user_id, p_kind, p_payload);
end;
$$;

create or replace function mark_notifications_read(p_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid();
begin
    if v_me is null then return jsonb_build_object('ok', false, 'reason', 'unauthenticated'); end if;
    update notifications set read = true
     where user_id = v_me and id = any(p_ids);
    return jsonb_build_object('ok', true);
end;
$$;

-- ============================================================================
-- 5. Activity feed
-- ============================================================================

create table if not exists activity_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references user_profiles(id) on delete cascade,
    kind text not null
        check (kind in ('scan_completed', 'pr_set', 'streak_milestone', 'challenge_won', 'workout_completed')),
    payload jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists activity_events_user_idx on activity_events (user_id, created_at desc);
create index if not exists activity_events_recent_idx on activity_events (created_at desc);

alter table activity_events enable row level security;

-- Visibility: my own events + my friends' events (but only if their privacy_mode allows).
drop policy if exists activity_events_read_friends on activity_events;
create policy activity_events_read_friends on activity_events
    for select using (
        auth.uid() = user_id
        or exists (
            select 1 from friendships f, user_profiles p
            where p.id = activity_events.user_id
              and p.privacy_mode in ('public', 'friends_only')
              and (
                  (f.user_a = auth.uid() and f.user_b = activity_events.user_id)
               or (f.user_b = auth.uid() and f.user_a = activity_events.user_id)
              )
        )
        or exists (
            -- Public profiles are visible to anyone who isn't blocked
            select 1 from user_profiles p
            where p.id = activity_events.user_id
              and p.privacy_mode = 'public'
              and not exists (
                  select 1 from blocks
                  where (blocker_id = activity_events.user_id and blocked_id = auth.uid())
                     or (blocker_id = auth.uid() and blocked_id = activity_events.user_id)
              )
        )
    );

-- post_activity: the user logs an event for themselves.
create or replace function post_activity(p_kind text, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid();
begin
    if v_me is null then return jsonb_build_object('ok', false, 'reason', 'unauthenticated'); end if;
    insert into activity_events (user_id, kind, payload) values (v_me, p_kind, p_payload);
    return jsonb_build_object('ok', true);
end;
$$;

-- ============================================================================
-- 6. Group challenges
-- ============================================================================

create table if not exists group_challenges (
    id uuid primary key default gen_random_uuid(),
    creator_id uuid not null references user_profiles(id) on delete cascade,
    title text not null,
    description text not null default '',
    metric text not null check (metric in ('scan_score', 'workout_count', 'streak_days', 'volume_kg')),
    target double precision not null default 0,
    starts_at timestamptz not null default now(),
    ends_at timestamptz not null,
    created_at timestamptz not null default now()
);

create table if not exists group_challenge_members (
    challenge_id uuid not null references group_challenges(id) on delete cascade,
    user_id uuid not null references user_profiles(id) on delete cascade,
    score double precision not null default 0,
    last_updated timestamptz not null default now(),
    primary key (challenge_id, user_id)
);

create index if not exists group_challenge_members_user_idx on group_challenge_members (user_id);

alter table group_challenges enable row level security;
alter table group_challenge_members enable row level security;

drop policy if exists group_challenges_read_member on group_challenges;
create policy group_challenges_read_member on group_challenges
    for select using (
        exists (select 1 from group_challenge_members m
                where m.challenge_id = group_challenges.id and m.user_id = auth.uid())
    );

drop policy if exists group_challenge_members_read_member on group_challenge_members;
create policy group_challenge_members_read_member on group_challenge_members
    for select using (
        exists (select 1 from group_challenge_members m
                where m.challenge_id = group_challenge_members.challenge_id and m.user_id = auth.uid())
    );

create or replace function create_group_challenge(
    p_title text,
    p_description text,
    p_metric text,
    p_target double precision,
    p_ends_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid(); v_id uuid;
begin
    if v_me is null then return jsonb_build_object('ok', false, 'reason', 'unauthenticated'); end if;
    insert into group_challenges (creator_id, title, description, metric, target, ends_at)
    values (v_me, p_title, p_description, p_metric, p_target, p_ends_at)
    returning id into v_id;

    -- Creator is the first member.
    insert into group_challenge_members (challenge_id, user_id) values (v_id, v_me);
    return jsonb_build_object('ok', true, 'challenge_id', v_id);
end;
$$;

create or replace function invite_to_group_challenge(p_challenge_id uuid, p_friend_username text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid(); v_friend uuid; v_pair record;
begin
    if v_me is null then return jsonb_build_object('ok', false, 'reason', 'unauthenticated'); end if;

    -- Only existing members can invite.
    if not exists (select 1 from group_challenge_members
                   where challenge_id = p_challenge_id and user_id = v_me) then
        return jsonb_build_object('ok', false, 'reason', 'not_member');
    end if;

    select id into v_friend from user_profiles
     where lower(username) = lower(p_friend_username) and username <> '' limit 1;
    if v_friend is null then return jsonb_build_object('ok', false, 'reason', 'user_not_found'); end if;

    -- Inviter must be friends with the invitee.
    select user_a, user_b into v_pair from _canonical_pair(v_me, v_friend);
    if not exists (select 1 from friendships
                   where user_a = v_pair.user_a and user_b = v_pair.user_b) then
        return jsonb_build_object('ok', false, 'reason', 'not_friends');
    end if;

    insert into group_challenge_members (challenge_id, user_id)
    values (p_challenge_id, v_friend)
    on conflict do nothing;

    perform _enqueue_notification(
        v_friend, 'group_challenge_invited',
        jsonb_build_object('challenge_id', p_challenge_id, 'invited_by', v_me)
    );

    return jsonb_build_object('ok', true);
end;
$$;

create or replace function update_group_challenge_score(p_challenge_id uuid, p_score double precision)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_me uuid := auth.uid();
begin
    if v_me is null then return jsonb_build_object('ok', false, 'reason', 'unauthenticated'); end if;
    update group_challenge_members
       set score = greatest(score, p_score), last_updated = now()
     where challenge_id = p_challenge_id and user_id = v_me;
    if not found then return jsonb_build_object('ok', false, 'reason', 'not_member'); end if;
    return jsonb_build_object('ok', true);
end;
$$;

-- ============================================================================
-- 7. Grants
-- ============================================================================

grant execute on function send_friend_request(text) to authenticated;
grant execute on function respond_friend_request(uuid, boolean) to authenticated;
grant execute on function cancel_friend_request(uuid) to authenticated;
grant execute on function remove_friendship(uuid) to authenticated;
grant execute on function block_user(uuid) to authenticated;
grant execute on function unblock_user(uuid) to authenticated;
grant execute on function report_user(uuid, text, text) to authenticated;
grant execute on function send_challenge(text, text) to authenticated;
grant execute on function respond_challenge(uuid, boolean) to authenticated;
grant execute on function submit_challenge_score(uuid, double precision, text) to authenticated;
grant execute on function mark_notifications_read(uuid[]) to authenticated;
grant execute on function post_activity(text, jsonb) to authenticated;
grant execute on function create_group_challenge(text, text, text, double precision, timestamptz) to authenticated;
grant execute on function invite_to_group_challenge(uuid, text) to authenticated;
grant execute on function update_group_challenge_score(uuid, double precision) to authenticated;
