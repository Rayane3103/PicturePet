import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/media_item.dart';
import '../utils/retry.dart';
import '../utils/logger.dart';

class MediaRepository {
  MediaRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> _putBytesToStorage({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await retry(() async {
      Logger.info('Uploading to storage', context: {'bucket': bucket, 'path': path});
      await _client.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: false));
    });
    // Prefer signed URLs for private buckets
    final signed = await _client.storage.from(bucket).createSignedUrl(path, 60 * 60 * 24 * 7); // 7 days
    return signed;
  }

  String _generateChecksum(Uint8List bytes) {
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  Future<MediaItem> createMediaRecord({
    required String ownerId,
    required String storagePath,
    required String url,
    required String? thumbnailUrl,
    required String mimeType,
    required int sizeBytes,
    required String checksum,
    Map<String, dynamic> metadata = const {},
  }) async {
    final row = await retry<Map<String, dynamic>>(() async {
      final data = await _client.from('media').insert({
        'owner_id': ownerId,
        'storage_path': storagePath,
        'url': url,
        'thumbnail_url': thumbnailUrl,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'checksum': checksum,
        'metadata': metadata,
      }).select().single();
      return Map<String, dynamic>.from(data);
    });
    return MediaItem.fromMap(row);
  }

  Future<MediaItem> uploadBytes({
    required Uint8List bytes,
    required String filename,
    required String contentType,
    Uint8List? thumbnailBytes,
    String thumbnailContentType = 'image/jpeg',
    Map<String, dynamic> metadata = const {},
    String? projectName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    final checksum = _generateChecksum(bytes);
    final ownerId = user.id;
    final basePath = 'u/$ownerId/${DateTime.now().toUtc().millisecondsSinceEpoch}';
    final objectPath = '$basePath/$filename';
    final bucket = 'media';

    final url = await _putBytesToStorage(
      bucket: bucket,
      path: objectPath,
      bytes: bytes,
      contentType: contentType,
    );

    String? thumbUrl;
    String? thumbPath;
    if (thumbnailBytes != null) {
      thumbPath = '$basePath/thumb_$filename.jpg';
      thumbUrl = await _putBytesToStorage(
        bucket: bucket,
        path: thumbPath,
        bytes: thumbnailBytes,
        contentType: thumbnailContentType,
      );
    }

    final media = await createMediaRecord(
      ownerId: ownerId,
      storagePath: objectPath,
      url: url,
      thumbnailUrl: thumbUrl,
      mimeType: contentType,
      sizeBytes: bytes.length,
      checksum: checksum,
      metadata: metadata,
    );
    // Optionally create a project on first upload if a name is provided
    if (projectName != null && projectName.isNotEmpty) {
      try {
        await retry(() async {
          await _client.from('projects').insert({
            'user_id': ownerId,
            'name': projectName,
            'original_image_url': url,
            'thumbnail_url': thumbUrl,
            'file_size_bytes': bytes.length,
          });
        });
      } catch (e) {
        Logger.warn('Project creation failed', context: {'error': e.toString()});
      }
    }
    return media;
  }

  Future<List<MediaItem>> listMedia({int limit = 20, int offset = 0, String? filterMime}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    var query = _client
        .from('media')
        .select()
        .eq('owner_id', user.id);
    if (filterMime != null) {
      query = query.ilike('mime_type', '$filterMime%');
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows).map(MediaItem.fromMap).toList();
  }
}


