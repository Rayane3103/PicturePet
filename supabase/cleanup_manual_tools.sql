-- Delete unused tools, keep only the 8 active AI tools + Manual Editor Session
DELETE FROM public.tools 
WHERE name IN (
  -- Unused manual tools
  'crop_rotate', 
  'adjust', 
  'add_text', 
  'filters',
  -- Unused AI tools
  'ai_editor',
  'magic_eraser',
  'ai_style',
  'ideogram_v3_edit',
  'ideogram_character_edit'
);

