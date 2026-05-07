-- 016_photo_storage_ttl.sql
--
-- GDPR-compliant retention enforcement for user-uploaded photos.
-- Two pg_cron jobs run nightly and delete:
--   1. goal_projections/sources/* older than 30 days
--   2. challenge_photos/* older than 7 days post-battle (or 30 days
--      absolute, whichever is sooner)
--
-- Rationale: privacy posture promises in PRIVACY_POLICY.md (§7) and
-- in-app PhotoConsentSheet are ENFORCED here, not just claimed. Any
-- photo that lingers beyond the policy is a regulator-visible breach
-- of the disclosed retention period.
--
-- Prerequisites:
--   - pg_cron extension enabled (Supabase: Database → Extensions)
--   - service_role key has DELETE permission on storage.objects
--   - Both buckets must be set to "Public bucket = OFF" in the
--     Supabase dashboard (Storage → bucket → Settings)
--
-- DEPLOY: `supabase db push` (preferred) or paste into SQL editor.

create extension if not exists pg_cron with schema extensions;

-- ──────────────────────────────────────────────────────────────────
-- 1. Goal-projection source photos: 30-day hard TTL
-- ──────────────────────────────────────────────────────────────────

create or replace function public.purge_expired_goal_projection_sources()
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
declare
    deleted_count int;
begin
    with deleted as (
        delete from storage.objects
        where bucket_id = 'goal_projections'
          and name like '%/sources/%'
          and created_at < (now() - interval '30 days')
        returning 1
    )
    select count(*) into deleted_count from deleted;

    raise notice 'purge_expired_goal_projection_sources: removed % objects', deleted_count;
end;
$$;

-- ──────────────────────────────────────────────────────────────────
-- 2. Challenge photos: delete 7 days post-resolution OR 30 days absolute
--
-- A challenge has `status` ∈ {pending, active, completed, declined,
-- expired} on the `challenges` table (see migration 003_social.sql).
-- We delete the photo when EITHER:
--   • the parent challenge is completed/declined/expired AND finished
--     >7 days ago, OR
--   • the photo is >30 days old regardless of challenge state (defense
--     against rows that never resolve)
-- ──────────────────────────────────────────────────────────────────

create or replace function public.purge_expired_challenge_photos()
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
declare
    deleted_count int;
begin
    -- A) hard 30-day cap regardless of challenge state
    with deleted_old as (
        delete from storage.objects o
        where o.bucket_id = 'challenge_photos'
          and o.created_at < (now() - interval '30 days')
        returning 1
    )
    select count(*) into deleted_count from deleted_old;

    -- B) post-resolution 7-day cleanup. Path layout is
    --    `{user_id}/{challenge_id}.jpg` so we can join on the parsed id.
    with parsed as (
        select
            o.id as object_id,
            o.bucket_id,
            o.name,
            -- second path segment (between first '/' and '.jpg')
            split_part(split_part(o.name, '/', 2), '.', 1)::uuid as challenge_id
        from storage.objects o
        where o.bucket_id = 'challenge_photos'
          and o.name ~ '^[0-9a-f-]+/[0-9a-f-]+\.jpg$'
    ),
    resolved as (
        select p.object_id
        from parsed p
        join public.challenges c on c.id = p.challenge_id
        where c.status in ('completed', 'declined', 'expired')
          and coalesce(c.updated_at, c.created_at) < (now() - interval '7 days')
    ),
    deleted_resolved as (
        delete from storage.objects o
        using resolved r
        where o.id = r.object_id
        returning 1
    )
    select count(*) + deleted_count into deleted_count from deleted_resolved;

    raise notice 'purge_expired_challenge_photos: removed % objects', deleted_count;
exception
    when undefined_table then
        -- challenges table not present yet (e.g., older env) — skip
        -- the post-resolution sweep; the absolute 30-day cap above
        -- still ran.
        raise notice 'purge_expired_challenge_photos: challenges table missing, ran 30d cap only';
end;
$$;

-- ──────────────────────────────────────────────────────────────────
-- Schedule both jobs nightly at 03:00 UTC. Idempotent: re-running this
-- migration unschedules and re-creates with the same name.
-- ──────────────────────────────────────────────────────────────────

do $$
begin
    perform cron.unschedule('purge_goal_projection_sources_daily');
exception when others then null;
end $$;

select cron.schedule(
    'purge_goal_projection_sources_daily',
    '0 3 * * *',
    $$select public.purge_expired_goal_projection_sources();$$
);

do $$
begin
    perform cron.unschedule('purge_challenge_photos_daily');
exception when others then null;
end $$;

select cron.schedule(
    'purge_challenge_photos_daily',
    '0 3 * * *',
    $$select public.purge_expired_challenge_photos();$$
);

-- ──────────────────────────────────────────────────────────────────
-- Sanity-check helpers — call from psql or SQL editor manually.
-- These are idempotent reads; safe to leave deployed.
-- ──────────────────────────────────────────────────────────────────

create or replace view public.photo_retention_status as
select
    bucket_id,
    count(*) as total_objects,
    sum((metadata->>'size')::bigint) as total_bytes,
    min(created_at) as oldest_object,
    max(created_at) as newest_object,
    count(*) filter (where created_at < now() - interval '30 days') as overdue_30d
from storage.objects
where bucket_id in ('goal_projections', 'challenge_photos')
group by bucket_id;

comment on view public.photo_retention_status is
    'Operational view: counts and ages of stored photos. If overdue_30d > 0, the TTL cron is not running.';
