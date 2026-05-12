-- ============================================================================
-- 023_social_pro_badge.sql
--
-- Surface `is_premium` through the two social-profile RPCs so the iOS
-- client can render a Pro crown next to a friend's name on the friend
-- card and profile sheet. The column already exists on `user_profiles`
-- (added in migration 001); this migration only updates the RPC return
-- shapes.
--
-- NOTE: we drop-then-create instead of `create or replace` because
-- Postgres rejects column changes to `returns table(...)` (error 42P13).
-- Drops are idempotent (`if exists`) so this migration is safe to re-run.
-- ============================================================================

-- batch profile lookup ------------------------------------------------------

drop function if exists get_social_profiles(uuid[]);

create function get_social_profiles(p_ids uuid[])
returns table (
    id uuid,
    username text,
    name text,
    avatar_system_name text,
    profile_photo_url text,
    tier text,
    points int,
    total_workouts int,
    current_streak int,
    latest_score double precision,
    privacy_mode text,
    last_seen_at timestamptz,
    is_premium boolean
)
language sql
security definer
set search_path = public
stable
as $$
    select
        id, username, name, avatar_system_name, profile_photo_url,
        tier, points, total_workouts, current_streak, latest_score,
        privacy_mode, last_seen_at, is_premium
    from user_profiles
    where id = any(p_ids);
$$;

grant execute on function get_social_profiles(uuid[]) to authenticated;

-- single-profile detail -----------------------------------------------------

drop function if exists get_social_profile_detail(uuid);

create function get_social_profile_detail(p_user_id uuid)
returns table (
    id uuid,
    username text,
    name text,
    bio text,
    avatar_system_name text,
    profile_photo_url text,
    tier text,
    points int,
    total_workouts int,
    current_streak int,
    latest_score double precision,
    privacy_mode text,
    is_premium boolean
)
language sql
security definer
set search_path = public
stable
as $$
    select
        id, username, name, bio, avatar_system_name, profile_photo_url,
        tier, points, total_workouts, current_streak, latest_score,
        privacy_mode, is_premium
    from user_profiles
    where id = p_user_id;
$$;

grant execute on function get_social_profile_detail(uuid) to authenticated;
