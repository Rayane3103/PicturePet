-- Make tool_id nullable to allow manual sessions without a specific tool
alter table public.project_edits
  alter column tool_id drop not null;


