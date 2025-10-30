-- Add the 2 missing AI tools
INSERT INTO public.tools (name, display_name, type, credit_cost, tier_minimum)
VALUES
  ('style_transfer', 'Style Transfer', 'ai', 0, 'free_trial'),
  ('seedvr_upscale', 'SeedVR2 Upscale', 'ai', 0, 'free_trial')
ON CONFLICT (name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  type = EXCLUDED.type,
  credit_cost = EXCLUDED.credit_cost,
  tier_minimum = EXCLUDED.tier_minimum;

