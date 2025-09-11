import 'package:flutter/foundation.dart';

@immutable
class ProjectEdit {
  final String id;
  final String projectId;
  final int? toolId;
  final String editName;
  final Map<String, dynamic> parameters;
  final String? inputImageUrl;
  final String? outputImageUrl;
  final int creditCost;
  final String status; // pending | completed | failed
  final DateTime createdAt;

  const ProjectEdit({
    required this.id,
    required this.projectId,
    required this.toolId,
    required this.editName,
    required this.parameters,
    required this.inputImageUrl,
    required this.outputImageUrl,
    required this.creditCost,
    required this.status,
    required this.createdAt,
  });

  static ProjectEdit fromMap(Map<String, dynamic> map) {
    return ProjectEdit(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      toolId: map['tool_id'] as int?,
      editName: map['edit_name'] as String? ?? '',
      parameters: map['parameters'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['parameters'] as Map)
          : <String, dynamic>{},
      inputImageUrl: map['input_image_url'] as String?,
      outputImageUrl: map['output_image_url'] as String?,
      creditCost: map['credit_cost'] is int ? map['credit_cost'] as int : 0,
      status: map['status'] as String? ?? 'completed',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}


