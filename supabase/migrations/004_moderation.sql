-- ============================================================================
-- 004_moderation.sql
--
-- App Store Guideline 1.2 (UGC) hardening:
--   - Username content policy: reserved-word list + profanity filter (server-side
--     enforced via trigger so client-side bypass is impossible).
--   - Friend request rate limit: max 50 outgoing requests per rolling hour, to
--     prevent spam / harassment.
--
-- Safe to re-run: every object is created with `or replace` / `if not exists`.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Username content policy
-- ----------------------------------------------------------------------------

create or replace function is_username_allowed(p_username text)
returns boolean
language plpgsql
immutable
as $$
declare
    u text := lower(trim(p_username));
    -- Names that impersonate the platform, support staff, or major brands.
    -- Add to this list over time.
    reserved text[] := ARRAY[
        'admin', 'administrator', 'root', 'support', 'help', 'staff',
        'moderator', 'mod', 'team', 'system', 'official', 'fitai',
        'fit_ai', 'fit-ai', 'fitaiapp', 'fitaiteam', 'george', 'arnav',
        'apple', 'applehealth', 'google', 'meta', 'facebook',
        'instagram', 'tiktok', 'twitter', 'youtube', 'snapchat',
        'security', 'billing', 'sales', 'info', 'contact',
        'legal', 'privacy', 'terms', 'noreply', 'no_reply', 'abuse',
        'null', 'undefined', 'anonymous', 'guest',
        'me', 'self', 'everyone', 'nobody', 'test', 'testing',
        'developer', 'dev', 'api'
    ];
    -- Substring match — catches "fucker", "shitlord", etc.
    -- Conservative list. Tune over time based on reports.
    profane text[] := ARRAY[
        'fuck', 'shit', 'bitch', 'cunt', 'whore', 'slut',
        'nigger', 'nigga', 'faggot', 'retard', 'rape', 'rapist',
        'pedo', 'pedophile', 'kike', 'spic', 'chink', 'tranny',
        'kys', 'killyourself', 'nazi', 'hitler', 'isis', 'terrorist',
        'porn', 'xxx', 'sex', 'cum', 'penis', 'vagina',
        'asshole', 'dick', 'cock', 'incel', 'simp4'
    ];
    word text;
begin
    -- Empty allowed (default state for new accounts).
    if u = '' then return true; end if;

    -- Length: 3–20 chars.
    if length(u) < 3 or length(u) > 20 then return false; end if;

    -- Allowed character set: lowercase alpha, digit, underscore, period.
    -- (Matches the iOS UsernameValidator client-side rules.)
    if u !~ '^[a-z0-9_.]+$' then return false; end if;

    -- Cannot be all numbers.
    if u ~ '^[0-9]+$' then return false; end if;

    -- Reserved: exact match.
    if u = ANY(reserved) then return false; end if;

    -- Profanity: substring match.
    foreach word in array profane loop
        if u like '%' || word || '%' then return false; end if;
    end loop;

    return true;
end;
$$;

-- Trigger: enforce policy on every insert/update of username.
create or replace function enforce_username_policy()
returns trigger
language plpgsql
as $$
begin
    if (TG_OP = 'INSERT' and coalesce(NEW.username, '') <> '')
       or (TG_OP = 'UPDATE' and NEW.username is distinct from OLD.username) then
        if not is_username_allowed(NEW.username) then
            raise exception 'username_not_allowed'
                using errcode = 'check_violation';
        end if;
    end if;
    return NEW;
end;
$$;

drop trigger if exists user_profiles_username_policy on user_profiles;
create trigger user_profiles_username_policy
    before insert or update of username on user_profiles
    for each row execute function enforce_username_policy();

-- ----------------------------------------------------------------------------
-- 2. Friend request rate limit
--
-- Replaces the existing send_friend_request to add a sliding-window rate
-- check (max 50 outgoing pending+accepted+declined in the last hour). This
-- mirrors the original signature and behavior — the only addition is the
-- rate-limit guard near the top.
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
    v_recent_count int;
begin
    if v_from is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    -- Sliding-window rate limit: 50 friend requests per rolling hour.
    -- Counts every request the user initiated in the window regardless of
    -- whether it was accepted/declined/cancelled — pure send-volume cap.
    select count(*) into v_recent_count
    from friend_requests
    where from_user_id = v_from
      and created_at > now() - interval '1 hour';

    if v_recent_count >= 50 then
        return jsonb_build_object('ok', false, 'reason', 'rate_limited');
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
-- 3. Index to keep the rate-limit count cheap.
-- ----------------------------------------------------------------------------

create index if not exists friend_requests_from_recent_idx
    on friend_requests (from_user_id, created_at desc);
