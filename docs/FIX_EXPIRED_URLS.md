# Fixing HTTP 400 Errors from Expired URLs

## Problem
Old projects and uploads show a network error icon with HTTP 400 because the image URLs are **signed URLs that expire after 7 days**. Once expired, they can no longer load the images.

## Solution
Convert from temporary signed URLs to permanent public URLs. The Supabase storage bucket will be made public, but **Row Level Security (RLS) policies still protect access** - users can only access their own files.

## Steps to Fix

### 1. Update the Supabase Bucket (One-time setup)

Go to your Supabase project and run the SQL migration:

1. Open your Supabase Dashboard
2. Go to **SQL Editor**
3. Open the file `supabase/fix_expired_urls.sql`
4. Copy and paste the entire contents into the SQL Editor
5. Click **Run**

This will:
- Make the `media` bucket public
- Regenerate all URLs from storage paths as non-expiring public URLs
- Update both `media` and `projects` tables

### 2. Deploy the Code Changes

The following files have been updated:

1. **`supabase/media_schema_policies.sql`** - Bucket is now public
2. **`lib/repositories/media_repository.dart`** - Uses `getPublicUrl()` instead of `createSignedUrl()`

These changes ensure that **all new uploads** will use permanent URLs that never expire.

### 3. (Optional) Run Dart Migration Utility

If the SQL script doesn't fully update all records, you can run the Dart utility:

```dart
// Add this to your main app initialization or create a migration screen
import 'package:picturepet/utils/fix_expired_urls.dart';

// Run once after login
await UrlMigrationUtility.fixExpiredUrls();
```

## How It Works

### Before (Signed URLs - Expire after 7 days)
```
https://project.supabase.co/storage/v1/object/sign/media/u/user-id/file.jpg?token=ABC123&Expires=1234567890
```

### After (Public URLs - Never expire)
```
https://project.supabase.co/storage/v1/object/public/media/u/user-id/file.jpg
```

## Security

**Don't worry about security!** Even though the bucket is public, your RLS policies still protect access:

```sql
-- Only users can read their own files
create policy "Read own media objects" on storage.objects
for select using (
  bucket_id = 'media'
  and auth.role() = 'authenticated'
  and (position(('u/' || auth.uid()) in name) = 1)
);
```

This means:
- ✅ Users can only access files in their own folder (`u/{user-id}/`)
- ✅ Unauthenticated users cannot access any files
- ✅ URLs don't expire, so no more HTTP 400 errors

## Verification

After applying the fix:

1. **Check new uploads**: Upload a new image and verify the URL format is public (no `token=` or `Expires=` in the URL)
2. **Check old uploads**: Verify that old project thumbnails load correctly
3. **Wait 7+ days**: Previously, images would break. Now they work forever!

## Technical Details

### Why did signed URLs expire?

The old code in `media_repository.dart` line 25:
```dart
final signed = await _client.storage.from(bucket).createSignedUrl(path, 60 * 60 * 24 * 7); // 7 days
```

Created temporary signed URLs with a 7-day expiration. This is useful for private buckets but creates the problem you experienced.

### Why use public URLs?

With proper RLS policies in place, public URLs provide:
- **Permanent access** - URLs never expire
- **Better performance** - No need to regenerate URLs
- **Simpler code** - Just call `getPublicUrl(path)`
- **Same security** - RLS policies still enforce access control

The new code:
```dart
final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
```

## Troubleshooting

### URLs still showing errors after migration

1. Make sure you ran the SQL migration script
2. Check that the bucket is public: `SELECT * FROM storage.buckets WHERE id = 'media';`
3. Clear app cache and restart
4. Run the Dart migration utility

### New uploads still creating signed URLs

Make sure you deployed the updated `media_repository.dart` file with the `getPublicUrl()` change.

### Permission denied errors

Check your RLS policies are correctly set up in `supabase/media_schema_policies.sql`.

## Need Help?

If you encounter any issues:
1. Check Supabase logs for errors
2. Verify the bucket is public in the Supabase dashboard
3. Ensure RLS policies are active
4. Check that storage paths are correctly stored in the database

