-- Touch parent project's updated_at when a project_edit is inserted
create or replace function public.touch_project_updated_at()
returns trigger as $$
begin
  update public.projects set updated_at = now() where id = new.project_id;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_project_edits_touch on public.project_edits;
create trigger trg_project_edits_touch
after insert on public.project_edits
for each row execute function public.touch_project_updated_at();


