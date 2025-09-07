import 'package:flutter/foundation.dart';

@immutable
class MediaItem {
  final String id;
  final String ownerId;
  final String storagePath;
  final String url;
  final String? thumbnailUrl;
  final String mimeType;
  final int sizeBytes;
  final String checksumSha256;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const MediaItem({
    required this.id,
    required this.ownerId,
    required this.storagePath,
    required this.url,
    required this.thumbnailUrl,
    required this.mimeType,
    required this.sizeBytes,
    required this.checksumSha256,
    required this.createdAt,
    required this.metadata,
  });

  static MediaItem fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      storagePath: map['storage_path'] as String,
      url: map['url'] as String,
      thumbnailUrl: map['thumbnail_url'] as String?,
      mimeType: map['mime_type'] as String,
      sizeBytes: map['size_bytes'] as int,
      checksumSha256: map['checksum'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      metadata: map['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'owner_id': ownerId,
      'storage_path': storagePath,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'checksum': checksumSha256,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}


