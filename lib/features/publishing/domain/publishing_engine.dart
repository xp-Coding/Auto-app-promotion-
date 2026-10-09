import '../../content_studio/repositories/content_post_repository.dart';
import '../../media_library/repositories/media_repository.dart';
import '../models/post_job_model.dart';
import '../repositories/publishing_queue_repository.dart';
import 'platform_adapter.dart';

class ExecutionSummary {
  final int totalProcessed;
  final int succeeded;
  final int failed;
  final int retried;
  final int skippedAlreadyPublished;

  const ExecutionSummary({
    required this.totalProcessed,
    required this.succeeded,
    required this.failed,
    required this.retried,
    required this.skippedAlreadyPublished,
  });
}

class PublishingEngine {
  final PublishingQueueRepository _queueRepo;
  final ContentPostRepository _postRepo;
  final MediaRepository _mediaRepo;
  final Map<String, PublishingPlatformAdapter> _adapters = {};

  PublishingEngine({
    PublishingQueueRepository? queueRepo,
    ContentPostRepository? postRepo,
    MediaRepository? mediaRepo,
    List<PublishingPlatformAdapter> adapters = const [],
  })  : _queueRepo = queueRepo ?? PublishingQueueRepository(),
        _postRepo = postRepo ?? ContentPostRepository(),
        _mediaRepo = mediaRepo ?? MediaRepository() {
    for (final adapter in adapters) {
      registerAdapter(adapter);
    }
  }

  void registerAdapter(PublishingPlatformAdapter adapter) {
    _adapters[adapter.platformId.toLowerCase()] = adapter;
  }

  PublishingPlatformAdapter? getAdapter(String platform) {
    return _adapters[platform.toLowerCase()];
  }

  /// Process all pending jobs that are currently due
  Future<ExecutionSummary> processPendingJobs() async {
    final jobs = await _queueRepo.getDuePendingJobs();
    int succeeded = 0;
    int failed = 0;
    int retried = 0;
    int skipped = 0;

    for (final job in jobs) {
      final result = await executeJob(job);
      if (result == JobExecutionStatus.succeeded) {
        succeeded++;
      } else if (result == JobExecutionStatus.retried) {
        retried++;
      } else if (result == JobExecutionStatus.skippedAlreadyPublished) {
        skipped++;
      } else {
        failed++;
      }
    }

    return ExecutionSummary(
      totalProcessed: jobs.length,
      succeeded: succeeded,
      failed: failed,
      retried: retried,
      skippedAlreadyPublished: skipped,
    );
  }

  /// Execute an individual job with strict idempotency and bounded retry protection
  Future<JobExecutionStatus> executeJob(PostJobModel job) async {
    final platformKey = job.targetPlatform.toLowerCase();

    // IDEMPOTENCY CHECK 1: Has this post already been published to this platform?
    final existingPublication = await _queueRepo.findPublishedPost(job.contentId, platformKey);
    if (existingPublication != null && existingPublication.remoteId != null) {
      // Mark job as succeeded without re-publishing
      await _queueRepo.recordAttempt(
        jobId: job.id,
        attemptNumber: job.retryCount + 1,
        status: 'skipped_idempotent',
        remoteId: existingPublication.remoteId,
        errorMessage: 'Skipped publication: post already published on $platformKey with remote ID ${existingPublication.remoteId}',
      );
      await _queueRepo.markJobSucceeded(
        jobId: job.id,
        contentId: job.contentId,
        platform: platformKey,
        remoteId: existingPublication.remoteId!,
        remoteUrl: existingPublication.remoteUrl,
      );
      return JobExecutionStatus.skippedAlreadyPublished;
    }

    // Retrieve post content
    final post = await _postRepo.getPostById(job.contentId);
    if (post == null) {
      await _queueRepo.markJobFailed(
        job: job,
        errorCode: 'POST_NOT_FOUND',
        errorMessage: 'Content post with ID ${job.contentId} was not found in local database.',
        isTransient: false,
      );
      return JobExecutionStatus.failed;
    }

    // Check adapter availability
    final adapter = _adapters[platformKey];
    if (adapter == null) {
      await _queueRepo.markJobFailed(
        job: job,
        errorCode: 'ADAPTER_UNAVAILABLE',
        errorMessage: 'Platform adapter for "$platformKey" is not configured or pending milestone implementation.',
        isTransient: false,
      );
      return JobExecutionStatus.failed;
    }

    // Check authorization
    final isAuth = await adapter.isAuthenticated();
    if (!isAuth) {
      await _queueRepo.markJobFailed(
        job: job,
        errorCode: 'AUTH_REQUIRED',
        errorMessage: 'Account for "$platformKey" is not connected or authorization token expired.',
        isTransient: false,
      );
      return JobExecutionStatus.failed;
    }

    // Retrieve media items associated with the app
    final allMedia = await _mediaRepo.getMediaForApp(post.appId);
    final postMediaIds = await _postRepo.getPostMediaPaths(post.id);
    final attachedMedia = allMedia.where((m) => postMediaIds.contains(m.filePath)).toList();

    // Transition job to running
    await _queueRepo.markJobRunning(job.id);
    final attemptNumber = job.retryCount + 1;

    try {
      final publishResult = await adapter.publish(
        post: post,
        job: job,
        media: attachedMedia.isNotEmpty ? attachedMedia : allMedia,
      );

      if (publishResult.success && publishResult.remoteId != null) {
        // Record successful attempt
        await _queueRepo.recordAttempt(
          jobId: job.id,
          attemptNumber: attemptNumber,
          status: 'success',
          remoteId: publishResult.remoteId,
        );

        // Mark succeeded in queue & update post status to published
        await _queueRepo.markJobSucceeded(
          jobId: job.id,
          contentId: post.id,
          platform: platformKey,
          remoteId: publishResult.remoteId!,
          remoteUrl: publishResult.remoteUrl,
        );

        return JobExecutionStatus.succeeded;
      } else {
        // Handle publishing failure
        final err = publishResult.error;
        final errorCode = err?.code ?? 'UNKNOWN_ERROR';
        final errorMessage = err?.message ?? 'Publishing attempt failed without specific error message';
        final isTransient = err?.isTransient ?? false;

        await _queueRepo.recordAttempt(
          jobId: job.id,
          attemptNumber: attemptNumber,
          status: 'failed',
          errorCode: errorCode,
          errorMessage: errorMessage,
        );

        final updatedJob = await _queueRepo.markJobFailed(
          job: job,
          errorCode: errorCode,
          errorMessage: errorMessage,
          isTransient: isTransient,
        );

        if (updatedJob.status == 'pending') {
          return JobExecutionStatus.retried;
        } else {
          return JobExecutionStatus.failed;
        }
      }
    } catch (e) {
      await _queueRepo.recordAttempt(
        jobId: job.id,
        attemptNumber: attemptNumber,
        status: 'failed',
        errorCode: 'EXCEPTION',
        errorMessage: e.toString(),
      );

      final updatedJob = await _queueRepo.markJobFailed(
        job: job,
        errorCode: 'EXCEPTION',
        errorMessage: e.toString(),
        isTransient: true,
      );

      if (updatedJob.status == 'pending') {
        return JobExecutionStatus.retried;
      } else {
        return JobExecutionStatus.failed;
      }
    }
  }
}

enum JobExecutionStatus {
  succeeded,
  retried,
  failed,
  skippedAlreadyPublished,
}
