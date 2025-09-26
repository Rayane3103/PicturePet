-- Allow users to update their own projects (RLS)
drop policy if exists "Update own projects" on public.projects;
create policy "Update own projects" on public.projects
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);


