-- Create profiles table (if not exists)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  username text,
  full_name text,
  avatar_url text,
  tier text not null default 'free_trial',
  credits integer not null default 0,
  storage_used_gb double precision not null default 0,
  max_storage_gb double precision not null default 2,
  max_projects integer not null default 5,
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  is_trial_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trigger to keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- Enable RLS
alter table public.profiles enable row level security;

-- Policies: users can read their own profile; insert their profile; update their own profile
drop policy if exists "Read own profile" on public.profiles;
create policy "Read own profile" on public.profiles
for select using (auth.uid() = id);

drop policy if exists "Insert own profile" on public.profiles;
create policy "Insert own profile" on public.profiles
for insert with check (auth.uid() = id);

drop policy if exists "Update own profile" on public.profiles;
create policy "Update own profile" on public.profiles
for update using (auth.uid() = id) with check (auth.uid() = id);

-- Optional: allow service role to manage
-- No explicit policy needed for service role; it bypasses RLS via API key role


