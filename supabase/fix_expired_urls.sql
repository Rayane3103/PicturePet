-- ===================================================================
-- Migration script to fix expired URLs
-- ===================================================================
-- This script:
-- 1. Makes the media bucket public (RLS policies still protect access)
-- 2. Regenerates all URLs from storage paths as non-expiring public URLs
--
-- Run this in your Supabase SQL Editor
-- ===================================================================

-- Step 1: Make the bucket public
UPDATE storage.buckets 
SET public = true 
WHERE id = 'media';

-- Step 2: Update all media and project URLs
DO $$
DECLARE
  base_url text;
  media_rec record;
  updated_count int := 0;
BEGIN
  -- Extract base URL from an existing media record
  SELECT regexp_replace(url, '/storage/v1/.*$', '') INTO base_url
  FROM public.media
  WHERE url IS NOT NULL
  LIMIT 1;
  
  IF base_url IS NULL THEN
    RAISE NOTICE 'Could not extract base URL. Please check if media table has records.';
    RETURN;
  END IF;
  
  RAISE NOTICE 'Base URL: %', base_url;
  
  -- Update all media records
  FOR media_rec IN 
    SELECT id, storage_path
    FROM public.media
    WHERE storage_path IS NOT NULL
  LOOP
    DECLARE
      new_url text;
      new_thumb_url text;
      thumb_path text;
    BEGIN
      -- Generate new public URL
      new_url := concat(base_url, '/storage/v1/object/public/media/', media_rec.storage_path);
      
      -- Generate thumbnail URL (assumes thumb_ prefix pattern)
      thumb_path := regexp_replace(media_rec.storage_path, '/([^/]+)$', '/thumb_\1.jpg');
      new_thumb_url := concat(base_url, '/storage/v1/object/public/media/', thumb_path);
      
      -- Update the record
      UPDATE public.media
      SET 
        url = new_url,
        thumbnail_url = new_thumb_url
      WHERE id = media_rec.id;
      
      updated_count := updated_count + 1;
    END;
  END LOOP;
  
  RAISE NOTICE 'Updated % media records', updated_count;
  
  -- Step 3: Update project URLs that reference old media URLs
  -- Note: This is a best-effort update for projects
  -- Some projects may have URLs that don't match media records
  
  UPDATE public.projects p
  SET original_image_url = m.url
  FROM public.media m
  WHERE p.original_image_url IS NOT NULL
    AND m.storage_path IS NOT NULL
    AND p.original_image_url LIKE concat('%', regexp_replace(m.storage_path, '^.*/', ''), '%');
  
  UPDATE public.projects p
  SET output_image_url = m.url
  FROM public.media m
  WHERE p.output_image_url IS NOT NULL
    AND m.storage_path IS NOT NULL
    AND p.output_image_url LIKE concat('%', regexp_replace(m.storage_path, '^.*/', ''), '%');
  
  UPDATE public.projects p
  SET thumbnail_url = m.thumbnail_url
  FROM public.media m
  WHERE p.thumbnail_url IS NOT NULL
    AND m.thumbnail_url IS NOT NULL
    AND m.storage_path IS NOT NULL
    AND p.thumbnail_url LIKE concat('%', regexp_replace(m.storage_path, '^.*/', ''), '%');
  
  RAISE NOTICE 'Migration completed successfully!';
END $$;

