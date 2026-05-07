-- Storage bucket for 1v1 photo battle submissions.
--
-- The iOS PhotoUploadService writes to challenge_photos/{user_id}/{challenge_id}.jpg
-- and reads back through the public URL. Without this migration the upload
-- request 404s ("bucket not found") and the photo battle silently fails.
--
-- Layout:
--   challenge_photos/<user_id>/<challenge_id>.jpg
--
-- Policies:
--   - INSERT/UPDATE/DELETE: only the owner can write under their own folder
--   - SELECT: public — needed so AsyncImage can render the URL without auth

-- 1. Create the bucket (public so AsyncImage works without auth tokens)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
    'challenge_photos',
    'challenge_photos',
    true,
    5 * 1024 * 1024,                                   -- 5 MB cap per upload
    array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
   set public             = excluded.public,
       file_size_limit    = excluded.file_size_limit,
       allowed_mime_types = excluded.allowed_mime_types;

-- 2. Drop any prior policies for this bucket so this migration is rerunnable
do $$
declare
    pol record;
begin
    for pol in
        select policyname
          from pg_policies
         where schemaname = 'storage'
           and tablename  = 'objects'
           and policyname like 'challenge_photos:%'
    loop
        execute format('drop policy %I on storage.objects', pol.policyname);
    end loop;
end $$;

-- 3. Public read (AsyncImage hits the public URL without an auth header)
create policy "challenge_photos: public read"
on storage.objects
for select
to public
using (bucket_id = 'challenge_photos');

-- 4. Authenticated users can write only under their own user_id folder.
--    Path is <user_id>/<challenge_id>.jpg, so the first path segment must
--    match the caller's auth.uid().
create policy "challenge_photos: owner insert"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'challenge_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "challenge_photos: owner update"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'challenge_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
    bucket_id = 'challenge_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "challenge_photos: owner delete"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'challenge_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
);
