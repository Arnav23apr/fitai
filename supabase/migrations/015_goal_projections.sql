-- ============================================================================
-- 015_goal_projections.sql
--
-- "Future you" — an AI-generated projection of the user's goal physique.
--   - Two new columns on user_profiles: the public URL + the regen timestamp.
--   - A `goal_projections` Storage bucket (public read, authenticated write,
--     uploads namespaced by user_id).
--   - Edge function `generate_goal_projection` does the actual Gemini call
--     and writes here using the service role.
--
-- Surfaces:
--   - PlanPreview ("here's where you're headed")
--   - Profile (permanent reminder + regen button)
--   - Pre-cancel confirmation ("this is who you walk away from")
--
-- Safe to re-run.
-- ============================================================================

alter table user_profiles
    add column if not exists goal_projection_url text,
    add column if not exists goal_projection_generated_at timestamptz;

-- Storage bucket — public read so AsyncImage in the iOS app can load
-- without needing a signed URL on every render. Image content is
-- non-sensitive (it's an AI rendering of the user's goal physique).
insert into storage.buckets (id, name, public)
values ('goal_projections', 'goal_projections', true)
on conflict (id) do nothing;

-- Public read — anyone with the URL can fetch the image.
drop policy if exists "goal_projections: public read" on storage.objects;
create policy "goal_projections: public read"
on storage.objects for select
to public
using (bucket_id = 'goal_projections');

-- Authenticated owner-only write. Files must live under <user_id>/...
-- Service-role uploads (from the edge function) bypass these policies,
-- which is what we want — clients shouldn't upload here directly.
drop policy if exists "goal_projections: owner insert" on storage.objects;
create policy "goal_projections: owner insert"
on storage.objects for insert
to authenticated
with check (
    bucket_id = 'goal_projections'
    and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "goal_projections: owner update" on storage.objects;
create policy "goal_projections: owner update"
on storage.objects for update
to authenticated
using (
    bucket_id = 'goal_projections'
    and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "goal_projections: owner delete" on storage.objects;
create policy "goal_projections: owner delete"
on storage.objects for delete
to authenticated
using (
    bucket_id = 'goal_projections'
    and (storage.foldername(name))[1] = auth.uid()::text
);
