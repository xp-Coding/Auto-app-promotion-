class PostAttemptModel {
  final String id;
  final String jobId;
  final int attemptNumber;
  final DateTime attemptedAt;
  final String status; // success, failed, retry_scheduled
  final String? errorCode;
  final String? errorMessage;
  final String? remoteId;

  const PostAttemptModel({
    required this.id,
    required this.jobId,
    required this.attemptNumber,
    required this.attemptedAt,
    required this.status,
    this.errorCode,
    this.errorMessage,
    this.remoteId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'job_id': jobId,
      'attempt_number': attemptNumber,
      'attempted_at': attemptedAt.toIso8601String(),
      'status': status,
      'error_code': errorCode,
      'error_message': errorMessage,
      'remote_id': remoteId,
    };
  }

  factory PostAttemptModel.fromMap(Map<String, dynamic> map) {
    return PostAttemptModel(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      attemptNumber: (map['attempt_number'] as num).toInt(),
      attemptedAt: DateTime.parse(map['attempted_at'] as String),
      status: map['status'] as String,
      errorCode: map['error_code'] as String?,
      errorMessage: map['error_message'] as String?,
      remoteId: map['remote_id'] as String?,
    );
  }
}
