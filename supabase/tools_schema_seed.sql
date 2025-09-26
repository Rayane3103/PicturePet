-- Tools table (manual and AI tools catalog)
create table if not exists public.tools (
  id serial primary key,
  name text unique not null,
  display_name text not null,
  type text not null check (type in ('manual','ai')),
  credit_cost integer not null default 0,
  tier_minimum text not null default 'free_trial'
);

-- Seed minimal manual tools (idempotent)
insert into public.tools (name, display_name, type, credit_cost, tier_minimum)
values
  ('manual_editor', 'Manual Editor Session', 'manual', 0, 'free_trial'),
  ('crop_rotate', 'Crop & Rotate', 'manual', 0, 'free_trial'),
  ('adjust', 'Adjust (B/C/S)', 'manual', 0, 'free_trial'),
  ('add_text', 'Add Text', 'manual', 0, 'free_trial'),
  ('filters', 'Filters', 'manual', 0, 'free_trial')
on conflict (name) do update set
  display_name = excluded.display_name,
  type = excluded.type,
  credit_cost = excluded.credit_cost,
  tier_minimum = excluded.tier_minimum;


-- Seed AI tools (idempotent)
insert into public.tools (name, display_name, type, credit_cost, tier_minimum)
values
  ('ai_editor', 'AI Editor Session', 'ai', 0, 'free_trial'),
  ('nano_banana', 'nano_banana', 'ai', 0, 'free_trial'),
  ('elements', 'Elements Remix', 'ai', 0, 'free_trial'),
  ('remove_background', 'Remove Background', 'ai', 0, 'free_trial'),
  ('magic_eraser', 'Magic Eraser', 'ai', 0, 'free_trial'),
  ('ai_style', 'AI Style Transform', 'ai', 0, 'free_trial'),
  ('ideogram_v3_edit', 'ideogram/v3/edit', 'ai', 0, 'free_trial'),
  ('ideogram_character_edit', 'ideogram/character_edit', 'ai', 0, 'free_trial'),
  ('ideogram_v3_reframe', 'ideogram/v3/reframe', 'ai', 0, 'free_trial'),
  ('calligrapher', 'Calligrapher Text Edit', 'ai', 0, 'free_trial')
on conflict (name) do update set
  display_name = excluded.display_name,
  type = excluded.type,
  credit_cost = excluded.credit_cost,
  tier_minimum = excluded.tier_minimum;


