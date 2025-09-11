-- Project edits table and RLS policies

create table if not exists public.project_edits (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  tool_id integer,
  edit_name text not null default '',
  parameters jsonb not null default '{}'::jsonb,
  input_image_url text,
  output_image_url text,
  credit_cost integer not null default 0,
  status text not null default 'completed', -- pending | completed | failed
  created_at timestamptz not null default now()
);

create index if not exists idx_project_edits_project_created on public.project_edits (project_id, created_at desc);

alter table public.project_edits enable row level security;

-- Select only edits for own projects
drop policy if exists "Select edits for own projects" on public.project_edits;
create policy "Select edits for own projects" on public.project_edits for select using (
  exists (
    select 1 from public.projects p where p.id = project_id and p.user_id = auth.uid()
  )
);

-- Insert only into own projects
drop policy if exists "Insert edits for own projects" on public.project_edits;
create policy "Insert edits for own projects" on public.project_edits for insert with check (
  exists (
    select 1 from public.projects p where p.id = project_id and p.user_id = auth.uid()
  )
);

-- Delete only own project edits
drop policy if exists "Delete edits for own projects" on public.project_edits;
create policy "Delete edits for own projects" on public.project_edits for delete using (
  exists (
    select 1 from public.projects p where p.id = project_id and p.user_id = auth.uid()
  )
);


