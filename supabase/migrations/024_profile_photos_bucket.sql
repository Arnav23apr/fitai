-- Storage bucket for user profile avatars (custom pfp).
--
-- The iOS `PhotoUploadService.uploadProfilePhoto` writes to
-- `profile_photos/{user_id}/avatar.jpg` and the resulting public URL is
-- stored on `user_profiles.profile_photo_url`. Friends see the photo via
-- the `get_social_profiles` / `get_social_profile_detail` RPCs which
-- return that URL, and `FriendAvatarView` renders it through AsyncImage.
--
-- Without this migration the upload 404s ("bucket not found"), the URL
-- column stays NULL, and friends only ever see the SF Symbol fallback —
-- so custom avatars never propagate.
--
-- Layout:
--   profile_photos/<user_id>/avatar.jpg     (one file per user, overwritten)
--
-- Policies:
--   - SELECT: public — needed so AsyncImage can render without auth
--   - INSERT/UPDATE/DELETE: only the owner can write under their own folder

-- 1. Create the bucket (public so AsyncImage works without auth tokens).
--    on conflict makes the migration safely re-runnable AND a no-op if
--    someone already created the bucket via the Supabase dashboard.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'profile_photos',
    'profile_photos',
    true,
    5 * 1024 * 1024,                                   -- 5 MB cap per upload
    array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
   set public             = excluded.public,
       file_size_limit    = excluded.file_size_limit,
       allowed_mime_types = excluded.allowed_mime_types;

-- 2. Drop any prior policies for this bucket so this migration is
--    rerunnable (matches the challenge_photos migration pattern).
do $$
declare
    pol record;
begin
    for pol in
        select policyname
          from pg_policies
         where schemaname = 'storage'
           and tablename  = 'objects'
           and policyname like 'profile_photos:%'
    loop
        execute format('drop policy %I on storage.objects', pol.policyname);
    end loop;
end $$;

-- 3. Public read (AsyncImage hits the public URL without an auth header).
create policy "profile_photos: public read"
on storage.objects
for select
to public
using (bucket_id = 'profile_photos');

-- 4. Authenticated users can write only under their own user_id folder.
--    Path is <user_id>/avatar.jpg, so the first path segment must
--    match the caller's auth.uid().
create policy "profile_photos: owner insert"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "profile_photos: owner update"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "profile_photos: owner delete"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
);
