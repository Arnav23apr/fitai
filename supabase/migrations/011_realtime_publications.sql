-- Enable Supabase Realtime broadcasting for the Compete-tab tables.
--
-- Realtime only emits change events for tables explicitly listed in the
-- supabase_realtime publication. Adding them here lets the iOS client
-- subscribe via the Realtime channel instead of polling.
--
-- Tables included:
--   friend_requests  — new request, accept/decline status flips
--   friendships      — when an accept materializes a friendship
--   challenges       — challenge created, photo submitted, completed
--   notifications    — for the bell badge + inbox
--
-- RLS continues to apply on the broadcast — clients only receive rows
-- they could have selected via REST anyway, so no privacy regression.

-- The publication exists by default on every Supabase project. Some
-- projects start with `for all tables`; checking + branching keeps this
-- migration idempotent across project setups.
do $$
declare
    v_pub_for_all boolean;
begin
    select puballtables into v_pub_for_all
      from pg_publication
     where pubname = 'supabase_realtime';

    if v_pub_for_all is true then
        -- Already broadcasting all tables, nothing to do.
        return;
    end if;

    -- Idempotent ADD — Postgres errors if the table is already in the
    -- publication, so wrap in exception block per table.
    begin
        alter publication supabase_realtime add table friend_requests;
    exception when duplicate_object then null; end;

    begin
        alter publication supabase_realtime add table friendships;
    exception when duplicate_object then null; end;

    begin
        alter publication supabase_realtime add table challenges;
    exception when duplicate_object then null; end;

    begin
        alter publication supabase_realtime add table notifications;
    exception when duplicate_object then null; end;
end $$;

-- For UPDATE events to carry old values (needed if you ever want to know
-- "the request used to be pending, now it's accepted"), set REPLICA
-- IDENTITY FULL on these tables. Default identity is just the primary key
-- which is enough for INSERT/DELETE but limits UPDATE diffing.
alter table friend_requests replica identity full;
alter table challenges replica identity full;
alter table notifications replica identity full;
