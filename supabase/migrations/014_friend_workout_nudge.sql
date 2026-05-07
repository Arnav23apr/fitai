-- ============================================================================
-- 014_friend_workout_nudge.sql
--
-- "Don't fall behind" nudge: when a user completes a workout, every friend
-- who hasn't worked out yet today gets a push:
--   "@george just finished Pull Day. You skip today, he's +50 XP ahead."
--
-- Wired off the existing activity_events table — workouts already log
-- there via the postActivity RPC, so we don't need an extra surface from
-- the iOS side.
--
-- Guardrails:
--   - Only fires for kind = 'workout_completed'
--   - Skips friends who already worked out today (no nudge if they're
--     already logged for the day)
--   - Throttled to 1 nudge per friend per calendar day so a user with
--     20 friends working out doesn't get bombed
--
-- Safe to re-run.
-- ============================================================================

create or replace function _nudge_friends_on_workout()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_actor_id uuid := NEW.user_id;
    v_actor_username text;
    v_workout_name text;
    v_xp int;
    v_friend_id uuid;
    v_today_start timestamptz := date_trunc('day', now());
begin
    if NEW.kind <> 'workout_completed' then return NEW; end if;

    select username into v_actor_username
    from user_profiles where id = v_actor_id;

    -- Username is required for the nudge copy to make sense
    if v_actor_username is null or v_actor_username = '' then return NEW; end if;

    v_workout_name := coalesce(NEW.payload->>'workout_name', 'a workout');
    -- XP isn't in the payload today; default to 50 (matches the in-app
    -- award curve). Override here if/when the workout finisher passes it.
    v_xp := coalesce((NEW.payload->>'xp')::int, 50);

    -- For each accepted friend of the actor, enqueue a nudge if eligible.
    for v_friend_id in
        select case when user_a = v_actor_id then user_b else user_a end
        from friendships
        where user_a = v_actor_id or user_b = v_actor_id
    loop
        -- Skip if the friend already worked out today
        if exists (
            select 1 from activity_events
             where user_id = v_friend_id
               and kind = 'workout_completed'
               and created_at >= v_today_start
        ) then
            continue;
        end if;

        -- Skip if the friend has already received a nudge today
        if exists (
            select 1 from notifications
             where user_id = v_friend_id
               and kind = 'friend_workout_nudge'
               and created_at >= v_today_start
        ) then
            continue;
        end if;

        perform _enqueue_notification(
            v_friend_id,
            'friend_workout_nudge',
            jsonb_build_object(
                'actor_id', v_actor_id,
                'actor_username', v_actor_username,
                'workout_name', v_workout_name,
                'xp', v_xp
            )
        );
    end loop;

    return NEW;
end;
$$;

drop trigger if exists trg_nudge_friends_on_workout on activity_events;
create trigger trg_nudge_friends_on_workout
    after insert on activity_events
    for each row execute function _nudge_friends_on_workout();
