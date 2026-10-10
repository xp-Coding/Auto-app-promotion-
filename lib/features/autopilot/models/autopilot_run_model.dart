class AutopilotRunModel {
  final String id;
  final String appId;
  final String status; // running, paused, completed, failed
  final String currentStep;
  final double progress; // 0.0 to 1.0
  final int totalPostsCreated;
  final int totalJobsQueued;
  final int totalAssetsCreated;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AutopilotRunModel({
    required this.id,
    required this.appId,
    required this.status,
    required this.currentStep,
    this.progress = 0.0,
    this.totalPostsCreated = 0,
    this.totalJobsQueued = 0,
    this.totalAssetsCreated = 0,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  AutopilotRunModel copyWith({
    String? id,
    String? appId,
    String? status,
    String? currentStep,
    double? progress,
    int? totalPostsCreated,
    int? totalJobsQueued,
    int? totalAssetsCreated,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AutopilotRunModel(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      progress: progress ?? this.progress,
      totalPostsCreated: totalPostsCreated ?? this.totalPostsCreated,
      totalJobsQueued: totalJobsQueued ?? this.totalJobsQueued,
      totalAssetsCreated: totalAssetsCreated ?? this.totalAssetsCreated,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'app_id': appId,
      'status': status,
      'current_step': currentStep,
      'progress': progress,
      'total_posts_created': totalPostsCreated,
      'total_jobs_queued': totalJobsQueued,
      'total_assets_created': totalAssetsCreated,
      'error_message': errorMessage,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory AutopilotRunModel.fromMap(Map<String, dynamic> map) {
    return AutopilotRunModel(
      id: map['id'] as String,
      appId: map['app_id'] as String,
      status: map['status'] as String? ?? 'running',
      currentStep: map['current_step'] as String? ?? 'Starting Autopilot...',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      totalPostsCreated: (map['total_posts_created'] as num?)?.toInt() ?? 0,
      totalJobsQueued: (map['total_jobs_queued'] as num?)?.toInt() ?? 0,
      totalAssetsCreated: (map['total_assets_created'] as num?)?.toInt() ?? 0,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
