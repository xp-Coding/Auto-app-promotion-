import 'dart:convert';

class AutopilotSettingsModel {
  final String id;
  final bool isAutopilotEnabled;
  final bool requireApprovalBeforePublish;
  final int dailyPostLimit;
  final int weeklyPostLimit;
  final String postingTimeUtc;
  final List<String> targetPlatforms;
  final List<String> contentLanguages;
  final String aiProvider; // template, gemini, openai, local
  final String? aiApiKey;
  final String? aiModelName;
  final String videoFormat; // 9:16, 16:9, both
  final String timeZone; // 'UTC', 'Local'
  final int maxRetryAttempts;
  final int retryDelaySeconds;
  final List<String> contentThemes;
  final String? targetAudience;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AutopilotSettingsModel({
    this.id = 'default_autopilot_settings',
    this.isAutopilotEnabled = true,
    this.requireApprovalBeforePublish = false,
    this.dailyPostLimit = 2,
    this.weeklyPostLimit = 14,
    this.postingTimeUtc = '18:00',
    this.targetPlatforms = const ['youtube', 'tiktok', 'instagram'],
    this.contentLanguages = const ['en'],
    this.aiProvider = 'template',
    this.aiApiKey,
    this.aiModelName,
    this.videoFormat = 'both',
    this.timeZone = 'UTC',
    this.maxRetryAttempts = 3,
    this.retryDelaySeconds = 60,
    this.contentThemes = const [
      'Feature Showcase',
      'Problem & Solution',
      'Quick Tutorials',
      'App Updates',
      'Tips & Tricks',
    ],
    this.targetAudience,
    required this.createdAt,
    required this.updatedAt,
  });

  AutopilotSettingsModel copyWith({
    String? id,
    bool? isAutopilotEnabled,
    bool? requireApprovalBeforePublish,
    int? dailyPostLimit,
    int? weeklyPostLimit,
    String? postingTimeUtc,
    List<String>? targetPlatforms,
    List<String>? contentLanguages,
    String? aiProvider,
    String? aiApiKey,
    String? aiModelName,
    String? videoFormat,
    String? timeZone,
    int? maxRetryAttempts,
    int? retryDelaySeconds,
    List<String>? contentThemes,
    String? targetAudience,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AutopilotSettingsModel(
      id: id ?? this.id,
      isAutopilotEnabled: isAutopilotEnabled ?? this.isAutopilotEnabled,
      requireApprovalBeforePublish: requireApprovalBeforePublish ?? this.requireApprovalBeforePublish,
      dailyPostLimit: dailyPostLimit ?? this.dailyPostLimit,
      weeklyPostLimit: weeklyPostLimit ?? this.weeklyPostLimit,
      postingTimeUtc: postingTimeUtc ?? this.postingTimeUtc,
      targetPlatforms: targetPlatforms ?? this.targetPlatforms,
      contentLanguages: contentLanguages ?? this.contentLanguages,
      aiProvider: aiProvider ?? this.aiProvider,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiModelName: aiModelName ?? this.aiModelName,
      videoFormat: videoFormat ?? this.videoFormat,
      timeZone: timeZone ?? this.timeZone,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      retryDelaySeconds: retryDelaySeconds ?? this.retryDelaySeconds,
      contentThemes: contentThemes ?? this.contentThemes,
      targetAudience: targetAudience ?? this.targetAudience,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'is_autopilot_enabled': isAutopilotEnabled ? 1 : 0,
      'require_approval_before_publish': requireApprovalBeforePublish ? 1 : 0,
      'daily_post_limit': dailyPostLimit,
      'weekly_post_limit': weeklyPostLimit,
      'posting_time_utc': postingTimeUtc,
      'target_platforms': jsonEncode(targetPlatforms),
      'content_languages': jsonEncode(contentLanguages),
      'ai_provider': aiProvider,
      'ai_api_key': aiApiKey,
      'ai_model_name': aiModelName,
      'video_format': videoFormat,
      'time_zone': timeZone,
      'max_retry_attempts': maxRetryAttempts,
      'retry_delay_seconds': retryDelaySeconds,
      'content_themes': jsonEncode(contentThemes),
      'target_audience': targetAudience,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory AutopilotSettingsModel.fromMap(Map<String, dynamic> map) {
    List<String> decodeList(dynamic val, List<String> fallback) {
      if (val is String && val.isNotEmpty) {
        try {
          return (jsonDecode(val) as List).map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return fallback;
    }

    return AutopilotSettingsModel(
      id: map['id'] as String? ?? 'default_autopilot_settings',
      isAutopilotEnabled: (map['is_autopilot_enabled'] as int?) == 1,
      requireApprovalBeforePublish: (map['require_approval_before_publish'] as int?) == 1,
      dailyPostLimit: (map['daily_post_limit'] as num?)?.toInt() ?? 2,
      weeklyPostLimit: (map['weekly_post_limit'] as num?)?.toInt() ?? 14,
      postingTimeUtc: map['posting_time_utc'] as String? ?? '18:00',
      targetPlatforms: decodeList(map['target_platforms'], ['youtube', 'tiktok', 'instagram']),
      contentLanguages: decodeList(map['content_languages'], ['en']),
      aiProvider: map['ai_provider'] as String? ?? 'template',
      aiApiKey: map['ai_api_key'] as String?,
      aiModelName: map['ai_model_name'] as String?,
      videoFormat: map['video_format'] as String? ?? 'both',
      timeZone: map['time_zone'] as String? ?? 'UTC',
      maxRetryAttempts: (map['max_retry_attempts'] as num?)?.toInt() ?? 3,
      retryDelaySeconds: (map['retry_delay_seconds'] as num?)?.toInt() ?? 60,
      contentThemes: decodeList(map['content_themes'], [
        'Feature Showcase',
        'Problem & Solution',
        'Quick Tutorials',
        'App Updates',
        'Tips & Tricks',
      ]),
      targetAudience: map['target_audience'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now().toUtc(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now().toUtc(),
    );
  }
}
