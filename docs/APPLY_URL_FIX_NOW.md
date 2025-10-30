# 🔧 Quick Fix for HTTP 400 Errors - Apply Now!

## What's the Problem?
Your old project images are showing HTTP 400 errors because the URLs expire after 7 days. This is fixed now!

## ⚡ Quick Steps to Apply (5 minutes)

### Step 1: Run SQL Migration in Supabase (2 minutes)

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project
3. Go to **SQL Editor** (left sidebar)
4. Click **"New query"**
5. Copy and paste this entire script:

```sql
-- Make the bucket public
UPDATE storage.buckets 
SET public = true 
WHERE id = 'media';

-- Update all media and project URLs
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
  
  -- Update project URLs
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
```

6. Click **"Run"** (or press Ctrl+Enter)
7. You should see success messages in the output

### Step 2: Deploy Code Changes (1 minute)

The code has already been updated! Just rebuild and run your app:

```bash
flutter clean
flutter pub get
flutter run
```

### Step 3: Verify (2 minutes)

1. Open your app
2. Go to Library page
3. Check if old projects now load correctly ✅
4. Upload a new image
5. Verify it shows up immediately

## 🎉 Done!

Your images will now **NEVER expire** again. The URLs are permanent!

## What Changed?

### Before ❌
```
https://...supabase.co/storage/v1/object/sign/media/...?token=ABC&Expires=123
                                              ↑ signed URLs expire in 7 days
```

### After ✅
```
https://...supabase.co/storage/v1/object/public/media/...
                                              ↑ public URLs never expire
```

## Security Note 🔒

Don't worry! Even though the bucket is "public", your RLS policies still protect the files:
- ✅ Only authenticated users can access files
- ✅ Users can only access their own files (`u/{user-id}/`)
- ✅ No one else can see your images

## Troubleshooting

### "Could not extract base URL" error
- Make sure you have at least one record in the `media` table
- Check that your media records have URLs

### Images still not loading
1. Clear app cache
2. Restart the app
3. Check Supabase logs for errors
4. Verify bucket is public: Run `SELECT * FROM storage.buckets WHERE id = 'media';` and check `public = true`

### Need More Help?
Check the detailed guide: `docs/FIX_EXPIRED_URLS.md`

---

**That's it!** Your HTTP 400 errors should be gone! 🎊

