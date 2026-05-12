-- ============================================================================
-- 022_friend_hype.sql
--
-- "Send hype" — low-stakes friend interaction. User taps a button next to a
-- friend's row, friend gets a push notification ("@you sent you hype!"). Just
-- a dopamine hit, no game state changes.
--
-- Architecture: same as every other push in this app — insert a row into
-- `notifications` and the existing `_dispatch_push` trigger from migration 007
-- fans it out to the send_push edge function.
--
-- Guardrails:
--   - Must be friends (accepted friendship). Strangers can't spam.
--   - Throttle: max 1 hype per (sender, target) per 24h. Otherwise users
--     would tap-spam the button.
--
-- Safe to re-run.
-- ============================================================================

create or replace function send_hype(p_target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
    v_my_username text;
    v_target_username text;
    v_friendship_ok boolean;
    v_recent_hype_count int;
begin
    if v_me is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    if v_me = p_target_user_id then
        return jsonb_build_object('ok', false, 'reason', 'cannot_hype_self');
    end if;

    -- Must be friends. Membership in `friendships` is itself the accepted
    -- state (the pending/declined states live in `friend_requests`). Table
    -- stores the canonical pair with the smaller uuid as user_a, so check
    -- both orderings.
    select exists (
        select 1 from friendships
        where (user_a = v_me and user_b = p_target_user_id)
           or (user_a = p_target_user_id and user_b = v_me)
    ) into v_friendship_ok;

    if not v_friendship_ok then
        return jsonb_build_object('ok', false, 'reason', 'not_friends');
    end if;

    -- Throttle: one hype per (sender, target) per 24h. Track via the
    -- notifications table itself — every hype this user has sent that
    -- has this target as recipient counts.
    select count(*) into v_recent_hype_count
    from notifications
    where user_id = p_target_user_id
      and kind = 'hype_received'
      and (payload->>'from_user_id')::uuid = v_me
      and created_at > now() - interval '24 hours';

    if v_recent_hype_count > 0 then
        return jsonb_build_object('ok', false, 'reason', 'throttled');
    end if;

    -- Look up usernames for the push copy.
    select username into v_my_username from user_profiles where id = v_me;
    select username into v_target_username from user_profiles where id = p_target_user_id;

    insert into notifications (user_id, kind, payload, read)
    values (
        p_target_user_id,
        'hype_received',
        jsonb_build_object(
            'from_user_id', v_me,
            'from_username', coalesce(v_my_username, 'A friend')
        ),
        false
    );

    return jsonb_build_object('ok', true);
end;
$$;

grant execute on function send_hype(uuid) to authenticated;
