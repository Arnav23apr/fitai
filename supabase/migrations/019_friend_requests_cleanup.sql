-- ============================================================================
-- Migration 019 — friend_requests cleanup on unfriend + send-retry resilience
--
-- Bug: users hit "duplicate key value violates unique constraint
-- friend_requests_active_pair" when sending a friend request to someone
-- they were previously friends with.
--
-- Root cause: the unique index `friend_requests_active_pair` covers
-- rows where status IN ('pending', 'accepted'). The `remove_friendship`
-- RPC only deletes from `friendships` — the linked friend_requests row
-- (status = 'accepted') stays behind. Next send_friend_request between
-- the same pair hits the constraint because the orphaned accepted row
-- still occupies the unique-index slot.
--
-- Fix is two parts:
--   1) remove_friendship now also clears friend_requests for this pair
--      (in either direction).
--   2) send_friend_request defensively deletes any stale non-pending
--      rows for the same pair before inserting, so previously stuck
--      users can recover without manual SQL surgery.
-- ============================================================================

-- 1) Update remove_friendship to also clear friend_requests for the pair.
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

    -- Clean up any lingering friend_requests rows for this pair (any
    -- direction, any status). Without this, the unique index
    -- friend_requests_active_pair blocks future send_friend_request
    -- between the same two users.
    delete from friend_requests
     where (from_user_id = v_me and to_user_id = p_other_user_id)
        or (from_user_id = p_other_user_id and to_user_id = v_me);

    return jsonb_build_object('ok', true);
end;
$$;

-- 2) Make send_friend_request resilient to stale rows.
--    Replaces the implementation in 003_social.sql. Only difference vs
--    the original is the defensive cleanup before insert — pending /
--    already_friends checks are unchanged so the function's contract
--    is otherwise identical.
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

    -- Already friends? (canonical-pair lookup against friendships table)
    select user_a, user_b into v_pair from _canonical_pair(v_from, v_to);
    if exists (select 1 from friendships
               where user_a = v_pair.user_a and user_b = v_pair.user_b) then
        return jsonb_build_object('ok', false, 'reason', 'already_friends');
    end if;

    -- Existing pending request in either direction?
    if exists (select 1 from friend_requests
               where status = 'pending'
                 and ((from_user_id = v_from and to_user_id = v_to)
                   or (from_user_id = v_to and to_user_id = v_from))) then
        return jsonb_build_object('ok', false, 'reason', 'already_pending');
    end if;

    -- Defensive cleanup: drop any stale non-pending rows for this pair
    -- (in either direction). The unique index covers status IN
    -- ('pending', 'accepted'); an orphaned 'accepted' row left behind
    -- by a prior unfriend would otherwise re-trigger the duplicate-key
    -- violation. Pre-019 friendships are now repairable simply by
    -- retrying the request — no manual SQL needed.
    delete from friend_requests
     where status <> 'pending'
       and ((from_user_id = v_from and to_user_id = v_to)
         or (from_user_id = v_to and to_user_id = v_from));

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
