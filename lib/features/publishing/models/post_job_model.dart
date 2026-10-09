class PostJobModel {
  final String id;
  final String? campaignId;
  final String contentId;
  final String targetPlatform;
  final DateTime scheduledAt;
  final String status; // pending, running, succeeded, failed, manual_required, cancelled
  final int retryCount;
  final int maxRetries;
  final DateTime? nextRetryAt;
  final DateTime? lastAttemptAt;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PostJobModel({
    required this.id,
    this.campaignId,
    required this.contentId,
    required this.targetPlatform,
    required this.scheduledAt,
    this.status = 'pending',
    this.retryCount = 0,
    this.maxRetries = 3,
    this.nextRetryAt,
    this.lastAttemptAt,
    this.lastErrorCode,
    this.lastErrorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isRunning => status == 'running';
  bool get isSucceeded => status == 'succeeded';
  bool get isFailed => status == 'failed';
  bool get isManualRequired => status == 'manual_required';
  bool get isCancelled => status == 'cancelled';
  bool get canRetry => (isFailed || isManualRequired) && retryCount < maxRetries;

  PostJobModel copyWith({
    String? id,
    String? campaignId,
    String? contentId,
    String? targetPlatform,
    DateTime? scheduledAt,
    String? status,
    int? retryCount,
    int? maxRetries,
    DateTime? nextRetryAt,
    DateTime? lastAttemptAt,
    String? lastErrorCode,
    String? lastErrorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostJobModel(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      contentId: contentId ?? this.contentId,
      targetPlatform: targetPlatform ?? this.targetPlatform,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'content_id': contentId,
      'target_platform': targetPlatform,
      'scheduled_at': scheduledAt.toIso8601String(),
      'status': status,
      'retry_count': retryCount,
      'max_retries': maxRetries,
      'next_retry_at': nextRetryAt?.toIso8601String(),
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'last_error_code': lastErrorCode,
      'last_error_message': lastErrorMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PostJobModel.fromMap(Map<String, dynamic> map) {
    return PostJobModel(
      id: map['id'] as String,
      campaignId: map['campaign_id'] as String?,
      contentId: map['content_id'] as String,
      targetPlatform: map['target_platform'] as String,
      scheduledAt: DateTime.parse(map['scheduled_at'] as String),
      status: map['status'] as String? ?? 'pending',
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      maxRetries: (map['max_retries'] as num?)?.toInt() ?? 3,
      nextRetryAt: map['next_retry_at'] != null ? DateTime.parse(map['next_retry_at'] as String) : null,
      lastAttemptAt: map['last_attempt_at'] != null ? DateTime.parse(map['last_attempt_at'] as String) : null,
      lastErrorCode: map['last_error_code'] as String?,
      lastErrorMessage: map['last_error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
