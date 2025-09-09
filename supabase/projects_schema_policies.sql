-- Projects table and RLS policies

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  original_image_url text,
  output_image_url text,
  thumbnail_url text,
  file_size_bytes bigint,
  created_at timestamptz not null default now()
);

create index if not exists idx_projects_user_created on public.projects (user_id, created_at desc);

alter table public.projects enable row level security;

drop policy if exists "Select own projects" on public.projects;
create policy "Select own projects" on public.projects for select using (auth.uid() = user_id);

drop policy if exists "Insert own projects" on public.projects;
create policy "Insert own projects" on public.projects for insert with check (auth.uid() = user_id);

drop policy if exists "Delete own projects" on public.projects;
create policy "Delete own projects" on public.projects for delete using (auth.uid() = user_id);


