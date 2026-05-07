-- 018_presence.sql
--
-- Real-time-ish presence indicator for the friends tab.
-- Each iOS client bumps its own `last_seen_at` on app foreground (debounced),
-- and the UI shows a green dot for any friend whose `last_seen_at` is within
-- the last 5 minutes. Not true realtime (no socket subscription), but
-- accurate within the polling window — and honest, unlike the prior dot
-- that just lit up whenever the friends list was non-empty.
--
-- Idempotent.

alter table user_profiles
    add column if not exists last_seen_at timestamptz;

-- Index so "list online friends" queries don't full-scan. Sorted desc
-- because that's the natural query direction (most recently active first).
create index if not exists idx_user_profiles_last_seen
    on user_profiles(last_seen_at desc);
