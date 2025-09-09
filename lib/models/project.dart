import 'package:flutter/foundation.dart';

@immutable
class Project {
  final String id;
  final String userId;
  final String name;
  final String? originalImageUrl;
  final String? outputImageUrl;
  final String? thumbnailUrl;
  final int? fileSizeBytes;
  final DateTime createdAt;

  const Project({
    required this.id,
    required this.userId,
    required this.name,
    required this.originalImageUrl,
    required this.outputImageUrl,
    required this.thumbnailUrl,
    required this.fileSizeBytes,
    required this.createdAt,
  });

  static Project fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      originalImageUrl: map['original_image_url'] as String?,
      outputImageUrl: map['output_image_url'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      fileSizeBytes: map['file_size_bytes'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}


