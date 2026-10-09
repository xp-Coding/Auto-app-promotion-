class ContentPostModel {
  final String id;
  final String appId;
  final String? campaignId;
  final String targetPlatform; // YouTube, Facebook, Instagram, TikTok
  final String? title;
  final String bodyText;
  final String? hashtags;
  final String? scriptHook;
  final String? ctaLink;
  final String format; // caption, video_script, reel, story, carousel
  final String status; // draft, ready, scheduled, published
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContentPostModel({
    required this.id,
    required this.appId,
    this.campaignId,
    required this.targetPlatform,
    this.title,
    required this.bodyText,
    this.hashtags,
    this.scriptHook,
    this.ctaLink,
    required this.format,
    this.status = 'draft',
    required this.createdAt,
    required this.updatedAt,
  });

  ContentPostModel copyWith({
    String? id,
    String? appId,
    String? campaignId,
    String? targetPlatform,
    String? title,
    String? bodyText,
    String? hashtags,
    String? scriptHook,
    String? ctaLink,
    String? format,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContentPostModel(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      campaignId: campaignId ?? this.campaignId,
      targetPlatform: targetPlatform ?? this.targetPlatform,
      title: title ?? this.title,
      bodyText: bodyText ?? this.bodyText,
      hashtags: hashtags ?? this.hashtags,
      scriptHook: scriptHook ?? this.scriptHook,
      ctaLink: ctaLink ?? this.ctaLink,
      format: format ?? this.format,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'app_id': appId,
      'campaign_id': campaignId,
      'target_platform': targetPlatform,
      'title': title,
      'body_text': bodyText,
      'hashtags': hashtags,
      'script_hook': scriptHook,
      'cta_link': ctaLink,
      'format': format,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ContentPostModel.fromMap(Map<String, dynamic> map) {
    return ContentPostModel(
      id: map['id'] as String,
      appId: map['app_id'] as String,
      campaignId: map['campaign_id'] as String?,
      targetPlatform: map['target_platform'] as String,
      title: map['title'] as String?,
      bodyText: map['body_text'] as String,
      hashtags: map['hashtags'] as String?,
      scriptHook: map['script_hook'] as String?,
      ctaLink: map['cta_link'] as String?,
      format: map['format'] as String,
      status: map['status'] as String? ?? 'draft',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
