import 'package:flutter/foundation.dart';

@immutable
class AiJob {
  final String id;
  final String userId;
  final String projectId;
  final String toolName;
  final String status; // queued | running | completed | failed | cancelled
  final Map<String, dynamic> payload;
  final String? inputImageUrl;
  final String? resultUrl;
  final String? error;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const AiJob({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.toolName,
    required this.status,
    required this.payload,
    this.inputImageUrl,
    this.resultUrl,
    this.error,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  static AiJob fromMap(Map<String, dynamic> map) {
    return AiJob(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      projectId: map['project_id'] as String,
      toolName: map['tool_name'] as String,
      status: map['status'] as String,
      payload: map['payload'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['payload'] as Map)
          : <String, dynamic>{},
      inputImageUrl: map['input_image_url'] as String?,
      resultUrl: map['result_url'] as String?,
      error: map['error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at'] as String) : null,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
    );
  }
}


