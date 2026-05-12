-- ============================================================================
-- Migration 020 — social profile RPCs (RLS bypass for sociable fields)
--
-- Bug: incoming friend requests parse correctly from Supabase (count: 1
-- in the debug report) but the UI shows "Incoming (0)" because
-- FriendViewModel.refresh() compactMaps each request through a profile
-- lookup, and `fetchProfilesByIds` hits `user_profiles` directly. The
-- only SELECT policy on user_profiles is `auth.uid() = id` so strangers'
-- profiles return zero rows → guard fails → request silently dropped.
--
-- Same disconnect blocks friendships display, outgoing requests UI, and
-- single-profile detail view (FriendProfileSheet). isUsernameAvailable
-- is also affected (it returns "available" for taken usernames belonging
-- to other users, masked only by the DB-level unique index at insert).
--
-- Fix: three SECURITY DEFINER RPCs that bypass RLS but return ONLY the
-- safe, social-display fields (no email, dob, weight, etc). iOS client
-- calls these instead of raw PostgREST queries on user_profiles.
-- ============================================================================

-- Defensive column adds in case earlier migrations weren't applied to
-- this database. `add column if not exists` is idempotent and cheap.
alter table user_profiles
    add column if not exists last_seen_at timestamptz;
alter table user_profiles
    add column if not exists profile_photo_url text;

-- ----------------------------------------------------------------------------
-- get_social_profiles: batch-fetch public profile fields for a list of ids.
-- Replaces the direct `user_profiles?id=in.(...)` query in the iOS client.
-- ----------------------------------------------------------------------------
create or replace function get_social_profiles(p_ids uuid[])
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
    last_seen_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
    select
        id, username, name, avatar_system_name, profile_photo_url,
        tier, points, total_workouts, current_streak, latest_score,
        privacy_mode, last_seen_at
    from user_profiles
    where id = any(p_ids);
$$;

grant execute on function get_social_profiles(uuid[]) to authenticated;

-- ----------------------------------------------------------------------------
-- get_social_profile_detail: single profile + bio for the friend-profile
-- sheet. Same field set as `get_social_profiles` plus `bio`. No
-- `last_seen_at` here because the sheet shows presence via a separate
-- channel and the detail view doesn't need an online dot.
-- ----------------------------------------------------------------------------
create or replace function get_social_profile_detail(p_user_id uuid)
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
    privacy_mode text
)
language sql
security definer
set search_path = public
stable
as $$
    select
        id, username, name, bio, avatar_system_name, profile_photo_url,
        tier, points, total_workouts, current_streak, latest_score,
        privacy_mode
    from user_profiles
    where id = p_user_id;
$$;

grant execute on function get_social_profile_detail(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- is_username_taken: returns the owning user id if a username is taken,
-- nil otherwise. Lets the client show accurate availability without
-- needing to read other users' full profile rows.
-- ----------------------------------------------------------------------------
create or replace function is_username_taken(p_username text)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
    select id
    from user_profiles
    where lower(username) = lower(p_username)
      and username <> ''
    limit 1;
$$;

grant execute on function is_username_taken(text) to authenticated;
