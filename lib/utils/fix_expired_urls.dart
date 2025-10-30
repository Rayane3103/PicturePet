import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger.dart';

/// Utility to fix expired signed URLs by regenerating them as public URLs
/// Run this once after deploying the public bucket changes
class UrlMigrationUtility {
  static Future<void> fixExpiredUrls() async {
    final client = Supabase.instance.client;
    
    try {
      Logger.info('Starting URL migration...');
      
      // Get all media records
      final mediaRows = await client
          .from('media')
          .select('id, storage_path')
          .not('storage_path', 'is', null);
      
      Logger.info('Found ${mediaRows.length} media records to update');
      
      // Update each media record with new public URL
      for (final row in mediaRows) {
        final id = row['id'] as String;
        final storagePath = row['storage_path'] as String;
        
        // Generate public URLs
        final url = client.storage.from('media').getPublicUrl(storagePath);
        
        // Generate thumbnail URL if it follows the pattern
        String? thumbnailUrl;
        final pathParts = storagePath.split('/');
        if (pathParts.isNotEmpty) {
          final filename = pathParts.last;
          final dir = pathParts.sublist(0, pathParts.length - 1).join('/');
          final thumbPath = '$dir/thumb_$filename.jpg';
          thumbnailUrl = client.storage.from('media').getPublicUrl(thumbPath);
        }
        
        // Update the record
        await client
            .from('media')
            .update({
              'url': url,
              if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
            })
            .eq('id', id);
        
        Logger.debug('Updated media record $id');
      }
      
      Logger.info('Media URLs updated successfully');
      
      // Update projects table by copying from media
      // This is a bit tricky since we don't have direct storage_path in projects
      // We'll need to reconstruct URLs based on the pattern
      
      Logger.info('Updating project URLs...');
      
      // Get all projects
      final projectRows = await client
          .from('projects')
          .select('id, original_image_url, output_image_url, thumbnail_url');
      
      Logger.info('Found ${projectRows.length} project records to check');
      
      for (final row in projectRows) {
        final id = row['id'] as String;
        final updates = <String, dynamic>{};
        bool needsUpdate = false;
        
        // Check if URLs contain expired tokens
        final origUrl = row['original_image_url'] as String?;
        final outUrl = row['output_image_url'] as String?;
        final thumbUrl = row['thumbnail_url'] as String?;
        
        if (origUrl != null && (origUrl.contains('token=') || origUrl.contains('Expires='))) {
          // Try to extract storage path from the URL
          final path = _extractStoragePath(origUrl);
          if (path != null) {
            updates['original_image_url'] = client.storage.from('media').getPublicUrl(path);
            needsUpdate = true;
          }
        }
        
        if (outUrl != null && (outUrl.contains('token=') || outUrl.contains('Expires='))) {
          final path = _extractStoragePath(outUrl);
          if (path != null) {
            updates['output_image_url'] = client.storage.from('media').getPublicUrl(path);
            needsUpdate = true;
          }
        }
        
        if (thumbUrl != null && (thumbUrl.contains('token=') || thumbUrl.contains('Expires='))) {
          final path = _extractStoragePath(thumbUrl);
          if (path != null) {
            updates['thumbnail_url'] = client.storage.from('media').getPublicUrl(path);
            needsUpdate = true;
          }
        }
        
        if (needsUpdate) {
          await client
              .from('projects')
              .update(updates)
              .eq('id', id);
          Logger.debug('Updated project record $id');
        }
      }
      
      Logger.info('URL migration completed successfully');
    } catch (e, stack) {
      Logger.error('URL migration failed', context: {'error': e.toString(), 'stack': stack.toString()});
      rethrow;
    }
  }
  
  /// Extract storage path from a Supabase storage URL
  static String? _extractStoragePath(String url) {
    // URL format: https://{project}.supabase.co/storage/v1/object/{type}/media/{path}?token=...
    // or: https://{project}.supabase.co/storage/v1/object/{type}/media/{path}
    
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    
    // Try to extract path after '/media/'
    final pathSegments = uri.path.split('/');
    final mediaIndex = pathSegments.indexOf('media');
    
    if (mediaIndex >= 0 && mediaIndex < pathSegments.length - 1) {
      // Join all segments after 'media'
      final storagePath = pathSegments.sublist(mediaIndex + 1).join('/');
      return storagePath;
    }
    
    return null;
  }
}

