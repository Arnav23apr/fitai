-- ============================================================================
-- 022_progression_check_column.sql
--
-- Add `last_progression_check_at` to user_profiles so the weekly AI
-- progression-suggestion throttle holds across devices. Without it, a
-- Pro user switching devices (or reinstalling) resets the 7-day throttle
-- and could see two progression suggestions in the same calendar week.
--
-- iOS client (FriendViewModel + ProgressionService + AppState restore
-- flow) mirrors this column to the local profile blob and uses it as
-- the source of truth for the "is it time to ask the AI again?" gate.
--
-- Safe to re-run.
-- ============================================================================

alter table public.user_profiles
    add column if not exists last_progression_check_at timestamptz;

-- No backfill: nil/null is the correct "never checked" state. Real users
-- will get the column populated on their next PlanView appear (Pro only).
