import '../../content_studio/models/content_post_model.dart';
import '../../media_library/models/media_item_model.dart';
import '../models/post_job_model.dart';

/// Structured error describing failure reasons, retryability, and guidance
class PublishError {
  final String code;
  final String message;
  final bool isTransient; // If true, can be retried with exponential backoff
  final String? resolutionGuide;

  const PublishError({
    required this.code,
    required this.message,
    required this.isTransient,
    this.resolutionGuide,
  });

  @override
  String toString() => 'PublishError(code: $code, isTransient: $isTransient, message: $message)';
}

/// Result returned from publishing attempt
class PublishResult {
  final bool success;
  final String? remoteId;
  final String? remoteUrl;
  final PublishError? error;
  final DateTime? publishedAt;
  final Map<String, dynamic> metadata;

  const PublishResult.success({
    required this.remoteId,
    this.remoteUrl,
    this.publishedAt,
    this.metadata = const {},
  })  : success = true,
        error = null;

  const PublishResult.failure({
    required this.error,
    this.metadata = const {},
  })  : success = false,
        remoteId = null,
        remoteUrl = null,
        publishedAt = null;
}

/// Result returned from remote verification
class VerificationResult {
  final bool exists;
  final String status; // uploaded, processing, processed, failed, rejected, not_found
  final String? title;
  final String? remoteUrl;
  final String? details;

  const VerificationResult({
    required this.exists,
    required this.status,
    this.title,
    this.remoteUrl,
    this.details,
  });

  bool get isReady => exists && (status == 'processed' || status == 'active' || status == 'uploaded');
}

/// Current API quota tracking status
class QuotaStatus {
  final int dailyLimit;
  final int usedToday;
  final int remaining;
  final bool isExceeded;
  final DateTime resetsAt;

  const QuotaStatus({
    required this.dailyLimit,
    required this.usedToday,
    required this.remaining,
    required this.isExceeded,
    required this.resetsAt,
  });
}

/// Abstract contract implemented independently by each social platform
abstract class PublishingPlatformAdapter {
  String get platformId; // 'youtube', 'facebook', 'instagram', 'tiktok'
  String get platformDisplayName;

  /// Check whether valid credentials / tokens exist
  Future<bool> isAuthenticated();

  /// Execute official API publish operation
  Future<PublishResult> publish({
    required ContentPostModel post,
    required PostJobModel job,
    List<MediaItemModel> media = const [],
  });

  /// Remote verification of publication status via official API query
  Future<VerificationResult> verifyPublication({required String remoteId});

  /// Query quota tracking and rate limit status
  Future<QuotaStatus> checkQuota();

  /// Disconnect / Revoke authorization tokens
  Future<void> revokeAuth();
}
