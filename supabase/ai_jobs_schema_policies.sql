-- AI jobs queue and RLS policies

create table if not exists public.ai_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  project_id uuid not null references public.projects (id) on delete cascade,
  tool_name text not null,
  status text not null check (status in ('queued','running','completed','failed','cancelled')) default 'queued',
  payload jsonb not null default '{}',
  input_image_url text,
  result_url text,
  error text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_ai_jobs_user_created on public.ai_jobs (user_id, created_at desc);
create index if not exists idx_ai_jobs_project_status on public.ai_jobs (project_id, status, created_at desc);

alter table public.ai_jobs enable row level security;

-- Select: only own jobs or jobs for own projects
drop policy if exists "Select own ai jobs" on public.ai_jobs;
create policy "Select own ai jobs" on public.ai_jobs for select using (
  user_id = auth.uid()
);

-- Insert: user can enqueue jobs for own projects
drop policy if exists "Insert ai jobs for own projects" on public.ai_jobs;
create policy "Insert ai jobs for own projects" on public.ai_jobs for insert with check (
  user_id = auth.uid() and exists (
    select 1 from public.projects p where p.id = project_id and p.user_id = auth.uid()
  )
);

-- Update: allow user to cancel only their queued jobs
drop policy if exists "Cancel own queued ai jobs" on public.ai_jobs;
create policy "Cancel own queued ai jobs" on public.ai_jobs for update using (
  user_id = auth.uid() and status = 'queued'
) with check (
  user_id = auth.uid()
);

-- Maintain updated_at
create or replace function public.set_ai_job_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_ai_jobs_set_updated_at on public.ai_jobs;
create trigger trg_ai_jobs_set_updated_at
before update on public.ai_jobs
for each row execute function public.set_ai_job_updated_at();


