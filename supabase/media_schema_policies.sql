-- Buckets (create via dashboard if needed): media
-- Ensure the 'media' bucket exists (private). Safe to run multiple times.
insert into storage.buckets (id, name, public)
values ('media', 'media', false)
on conflict (id) do nothing;

-- Media table
create table if not exists public.media (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  storage_path text not null,
  url text not null,
  thumbnail_url text,
  mime_type text not null,
  size_bytes integer not null,
  checksum text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_media_owner_created on public.media (owner_id, created_at desc);
create index if not exists idx_media_checksum on public.media (checksum);

alter table public.media enable row level security;

drop policy if exists "Select own media" on public.media;
create policy "Select own media" on public.media for select using (auth.uid() = owner_id);

drop policy if exists "Insert own media" on public.media;
create policy "Insert own media" on public.media for insert with check (auth.uid() = owner_id);

drop policy if exists "Delete own media" on public.media;
create policy "Delete own media" on public.media for delete using (auth.uid() = owner_id);


-- Storage bucket policies for secure media ownership
-- Ensure a bucket named 'media' exists in Supabase Storage
-- Restrict access to objects under prefix u/{auth.uid()}/*

-- Read policy
drop policy if exists "Read own media objects" on storage.objects;
create policy "Read own media objects" on storage.objects
for select
using (
  bucket_id = 'media'
  and auth.role() = 'authenticated'
  and (position(('u/' || auth.uid()) in name) = 1)
);

-- Insert policy
drop policy if exists "Insert own media objects" on storage.objects;
create policy "Insert own media objects" on storage.objects
for insert
with check (
  bucket_id = 'media'
  and auth.role() = 'authenticated'
  and (position(('u/' || auth.uid()) in name) = 1)
);

-- Delete policy
drop policy if exists "Delete own media objects" on storage.objects;
create policy "Delete own media objects" on storage.objects
for delete
using (
  bucket_id = 'media'
  and auth.role() = 'authenticated'
  and (position(('u/' || auth.uid()) in name) = 1)
);

