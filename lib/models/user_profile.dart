import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  final String id;
  final String? email;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final String tier;
  final int credits;
  final double storageUsedGb;
  final double maxStorageGb;
  final int maxProjects;
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;
  final bool isTrialActive;
  final Map<String, dynamic> metadata;

  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.tier,
    required this.credits,
    required this.storageUsedGb,
    required this.maxStorageGb,
    required this.maxProjects,
    required this.trialStartedAt,
    required this.trialEndsAt,
    required this.isTrialActive,
    required this.metadata,
  });

  UserProfile copyWith({
    String? id,
    String? email,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? tier,
    int? credits,
    double? storageUsedGb,
    double? maxStorageGb,
    int? maxProjects,
    DateTime? trialStartedAt,
    DateTime? trialEndsAt,
    bool? isTrialActive,
    Map<String, dynamic>? metadata,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      tier: tier ?? this.tier,
      credits: credits ?? this.credits,
      storageUsedGb: storageUsedGb ?? this.storageUsedGb,
      maxStorageGb: maxStorageGb ?? this.maxStorageGb,
      maxProjects: maxProjects ?? this.maxProjects,
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      isTrialActive: isTrialActive ?? this.isTrialActive,
      metadata: metadata ?? this.metadata,
    );
  }

  static UserProfile fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String?,
      username: map['username'] as String?,
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      tier: (map['tier'] as String?) ?? 'free_trial',
      credits: (map['credits'] as int?) ?? 0,
      storageUsedGb: (map['storage_used_gb'] is num)
          ? (map['storage_used_gb'] as num).toDouble()
          : 0,
      maxStorageGb: (map['max_storage_gb'] is num)
          ? (map['max_storage_gb'] as num).toDouble()
          : 0,
      maxProjects: (map['max_projects'] as int?) ?? 0,
      trialStartedAt: map['trial_started_at'] != null
          ? DateTime.tryParse(map['trial_started_at'] as String)
          : null,
      trialEndsAt: map['trial_ends_at'] != null
          ? DateTime.tryParse(map['trial_ends_at'] as String)
          : null,
      isTrialActive: (map['is_trial_active'] as bool?) ?? false,
      metadata: map['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'tier': tier,
      'credits': credits,
      'storage_used_gb': storageUsedGb,
      'max_storage_gb': maxStorageGb,
      'max_projects': maxProjects,
      'trial_started_at': trialStartedAt?.toIso8601String(),
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'is_trial_active': isTrialActive,
      'metadata': metadata,
    };
  }
}


