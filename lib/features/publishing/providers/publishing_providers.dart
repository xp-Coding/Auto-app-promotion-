import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../content_studio/providers/content_studio_providers.dart';
import '../../media_library/providers/media_providers.dart';
import '../adapters/youtube/youtube_adapter.dart';
import '../adapters/youtube/youtube_quota_tracker.dart';
import '../adapters/youtube/youtube_token_storage.dart';
import '../domain/platform_adapter.dart';
import '../domain/publishing_engine.dart';
import '../models/post_attempt_model.dart';
import '../models/post_job_model.dart';
import '../models/social_account_model.dart';
import '../repositories/publishing_queue_repository.dart';
import '../repositories/social_accounts_repository.dart';

final publishingQueueRepositoryProvider = Provider<PublishingQueueRepository>((ref) {
  return PublishingQueueRepository();
});

final socialAccountsRepositoryProvider = Provider<SocialAccountsRepository>((ref) {
  return SocialAccountsRepository();
});

final youtubeTokenStorageProvider = Provider<YouTubeTokenStorage>((ref) {
  return YouTubeTokenStorage();
});

final youtubeQuotaTrackerProvider = Provider<YouTubeQuotaTracker>((ref) {
  return YouTubeQuotaTracker();
});

final youtubeAdapterProvider = Provider<YouTubeAdapter>((ref) {
  final tokenStorage = ref.watch(youtubeTokenStorageProvider);
  final quotaTracker = ref.watch(youtubeQuotaTrackerProvider);
  final socialRepo = ref.watch(socialAccountsRepositoryProvider);
  return YouTubeAdapter(
    tokenStorage: tokenStorage,
    quotaTracker: quotaTracker,
    socialAccountsRepo: socialRepo,
  );
});

final publishingEngineProvider = Provider<PublishingEngine>((ref) {
  final queueRepo = ref.watch(publishingQueueRepositoryProvider);
  final postRepo = ref.watch(contentPostRepositoryProvider);
  final mediaRepo = ref.watch(mediaRepositoryProvider);
  final youtubeAdapter = ref.watch(youtubeAdapterProvider);

  return PublishingEngine(
    queueRepo: queueRepo,
    postRepo: postRepo,
    mediaRepo: mediaRepo,
    adapters: [youtubeAdapter],
  );
});

// Selected filter for queue screen
final queueStatusFilterProvider = StateProvider<String>((ref) => 'all');
final queuePlatformFilterProvider = StateProvider<String>((ref) => 'all');

// AsyncNotifier for post jobs
class PublishingJobsNotifier extends AsyncNotifier<List<PostJobModel>> {
  @override
  Future<List<PostJobModel>> build() async {
    final status = ref.watch(queueStatusFilterProvider);
    final platform = ref.watch(queuePlatformFilterProvider);
    return ref.watch(publishingQueueRepositoryProvider).getJobs(
          status: status,
          platform: platform,
        );
  }

  Future<void> refreshJobs() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final status = ref.read(queueStatusFilterProvider);
      final platform = ref.read(queuePlatformFilterProvider);
      return ref.read(publishingQueueRepositoryProvider).getJobs(
            status: status,
            platform: platform,
          );
    });
  }

  Future<PostJobModel> enqueueJob({
    required String contentId,
    required String targetPlatform,
    DateTime? scheduledAt,
    String? campaignId,
  }) async {
    final job = await ref.read(publishingQueueRepositoryProvider).enqueueJob(
          contentId: contentId,
          targetPlatform: targetPlatform,
          scheduledAt: scheduledAt,
          campaignId: campaignId,
        );
    await refreshJobs();
    return job;
  }

  Future<ExecutionSummary> processQueueNow() async {
    final engine = ref.read(publishingEngineProvider);
    final summary = await engine.processPendingJobs();
    await refreshJobs();
    // Also invalidate quota status and posts list
    ref.invalidate(youtubeQuotaStatusProvider);
    ref.invalidate(contentPostsListProvider);
    return summary;
  }

  Future<void> retryJob(String jobId) async {
    await ref.read(publishingQueueRepositoryProvider).retryJobImmediately(jobId);
    await refreshJobs();
  }

  Future<void> cancelJob(String jobId) async {
    await ref.read(publishingQueueRepositoryProvider).cancelJob(jobId);
    await refreshJobs();
  }

  Future<void> deleteJob(String jobId) async {
    await ref.read(publishingQueueRepositoryProvider).deleteJob(jobId);
    await refreshJobs();
  }
}

final publishingJobsListProvider =
    AsyncNotifierProvider<PublishingJobsNotifier, List<PostJobModel>>(
  PublishingJobsNotifier.new,
);

// Provider for attempts of a specific job
final jobAttemptsProvider =
    FutureProvider.family<List<PostAttemptModel>, String>((ref, jobId) async {
  return ref.watch(publishingQueueRepositoryProvider).getAttemptsForJob(jobId);
});

// Social accounts notifier
class SocialAccountsNotifier extends AsyncNotifier<List<SocialAccountModel>> {
  @override
  Future<List<SocialAccountModel>> build() async {
    return ref.watch(socialAccountsRepositoryProvider).getAccounts();
  }

  Future<void> refreshAccounts() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return ref.read(socialAccountsRepositoryProvider).getAccounts();
    });
  }

  Future<void> disconnect(String platform) async {
    if (platform == 'youtube') {
      await ref.read(youtubeAdapterProvider).revokeAuth();
    } else {
      await ref.read(socialAccountsRepositoryProvider).disconnectAccount(platform);
    }
    await refreshAccounts();
    ref.invalidate(youtubeQuotaStatusProvider);
  }

  Future<bool> connectYouTube({
    required String clientId,
    required String clientSecret,
    String? refreshToken,
    String? accessToken,
  }) async {
    final tokenStorage = ref.read(youtubeTokenStorageProvider);
    await tokenStorage.saveCredentials(
      YouTubeCredentials(
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken,
        accessToken: accessToken,
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );

    // Try fetching channel info to verify credentials
    final channel = await ref.read(youtubeAdapterProvider).fetchChannelInfo();
    await refreshAccounts();
    ref.invalidate(youtubeQuotaStatusProvider);
    return channel != null;
  }
}

final socialAccountsListProvider =
    AsyncNotifierProvider<SocialAccountsNotifier, List<SocialAccountModel>>(
  SocialAccountsNotifier.new,
);

// Quota provider
final youtubeQuotaStatusProvider = FutureProvider<QuotaStatus>((ref) async {
  final adapter = ref.watch(youtubeAdapterProvider);
  return adapter.checkQuota();
});
