-- Block social actions for users who haven't set a username.
--
-- Why: a friend request created by a username-less user shows up to the
-- recipient as "@" — unidentifiable, harassable, useless. The receiving
-- side's UI then offers Accept/Decline on a ghost. Stop it at the source.
--
-- Approach: re-issue send_friend_request with an early check on the
-- caller's own username. Same pattern would apply to send_challenge if
-- we ever discover the same bug there — added preemptively below.

create or replace function send_friend_request(p_to_username text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_from uuid := auth.uid();
    v_from_username text;
    v_to uuid;
    v_pair record;
    v_request_id uuid;
begin
    if v_from is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    -- New: caller must have a username. The iOS UI also disables the send
    -- button in this state, but we re-check server-side so a malicious
    -- client can't forge requests.
    select username into v_from_username from user_profiles where id = v_from;
    if v_from_username is null or v_from_username = '' then
        return jsonb_build_object('ok', false, 'reason', 'username_required');
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

    if v_from = v_to then
        return jsonb_build_object('ok', false, 'reason', 'cannot_friend_self');
    end if;

    -- Refuse if recipient has blocked sender.
    if exists (
        select 1 from blocks
         where blocker_id = v_to and blocked_id = v_from
    ) then
        return jsonb_build_object('ok', false, 'reason', 'blocked');
    end if;

    -- Already friends or pending request in either direction → soft success.
    select * into v_pair from friendships
     where (user_a = least(v_from, v_to) and user_b = greatest(v_from, v_to));
    if v_pair is not null then
        return jsonb_build_object('ok', true, 'state', 'already_friends');
    end if;

    select * into v_pair from friend_requests
     where status = 'pending'
       and ((from_user_id = v_from and to_user_id = v_to)
         or (from_user_id = v_to   and to_user_id = v_from));
    if v_pair is not null then
        return jsonb_build_object('ok', true, 'state', 'already_pending');
    end if;

    insert into friend_requests (from_user_id, to_user_id, status)
    values (v_from, v_to, 'pending')
    returning id into v_request_id;

    perform _enqueue_notification(
        v_to,
        'friend_request_received',
        jsonb_build_object('request_id', v_request_id, 'from', v_from_username)
    );

    return jsonb_build_object('ok', true, 'state', 'created', 'request_id', v_request_id);
end;
$$;

-- Same guard on send_challenge — challenge is a social action that should
-- also identify the sender by handle.
create or replace function send_challenge(
    p_opponent_username text,
    p_category text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_from uuid := auth.uid();
    v_from_username text;
    v_to uuid;
    v_challenge_id uuid;
begin
    if v_from is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    select username into v_from_username from user_profiles where id = v_from;
    if v_from_username is null or v_from_username = '' then
        return jsonb_build_object('ok', false, 'reason', 'username_required');
    end if;

    select id into v_to from user_profiles
     where lower(username) = lower(p_opponent_username)
       and username <> ''
     limit 1;
    if v_to is null then
        return jsonb_build_object('ok', false, 'reason', 'user_not_found');
    end if;
    if v_from = v_to then
        return jsonb_build_object('ok', false, 'reason', 'cannot_challenge_self');
    end if;

    -- Must be friends to challenge (existing rule).
    if not exists (
        select 1 from friendships
         where (user_a = least(v_from, v_to) and user_b = greatest(v_from, v_to))
    ) then
        return jsonb_build_object('ok', false, 'reason', 'not_friends');
    end if;

    insert into challenges (challenger_id, opponent_id, category, status)
    values (v_from, v_to, p_category, 'pending')
    returning id into v_challenge_id;

    perform _enqueue_notification(
        v_to,
        'challenge_sent',
        jsonb_build_object('challenge_id', v_challenge_id, 'category', p_category, 'from', v_from_username)
    );

    return jsonb_build_object('ok', true, 'challenge_id', v_challenge_id);
end;
$$;
