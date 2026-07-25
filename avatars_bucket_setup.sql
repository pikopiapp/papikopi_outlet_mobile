-- Supabase Storage setup for profile avatars
-- Run this in the SQL editor.
-- This version is intended for apps that use custom login and do not rely on Supabase Auth sessions.

-- 1) Create or ensure the bucket exists
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update
set public = true;

-- 2) Remove any existing policies that may block uploads for the avatars bucket
DROP POLICY IF EXISTS "Avatar files are publicly readable" ON storage.objects;
DROP POLICY IF EXISTS "Allow all access to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow all authenticated writes to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow all authenticated updates to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow all authenticated deletes to avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update their avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete their avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own avatars" ON storage.objects;
DROP POLICY IF EXISTS "Fallback avatars policy" ON storage.objects;

-- 3) Ensure the users table has a place to store the avatar URL
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'users'
  ) THEN
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'avatar_url'
    ) THEN
      ALTER TABLE public.users ADD COLUMN avatar_url text;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'profile_image_url'
    ) THEN
      ALTER TABLE public.users ADD COLUMN profile_image_url text;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'photo_url'
    ) THEN
      ALTER TABLE public.users ADD COLUMN photo_url text;
    END IF;
  END IF;
END $$;

-- 4) Allow public read and write access for the avatars bucket
create policy "Allow public read access to avatars"
on storage.objects
for select
to public
using (bucket_id = 'avatars');

create policy "Allow public insert to avatars"
on storage.objects
for insert
to public
with check (bucket_id = 'avatars');

create policy "Allow public update to avatars"
on storage.objects
for update
to public
using (bucket_id = 'avatars')
with check (bucket_id = 'avatars');

create policy "Allow public delete to avatars"
on storage.objects
for delete
to public
using (bucket_id = 'avatars');
