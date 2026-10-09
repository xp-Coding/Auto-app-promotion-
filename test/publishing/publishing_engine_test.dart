import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/features/apps/models/app_model.dart';
import 'package:appgrowth_studio/features/content_studio/models/content_post_model.dart';
import 'package:appgrowth_studio/features/content_studio/repositories/content_post_repository.dart';
import 'package:appgrowth_studio/features/media_library/models/media_item_model.dart';
import 'package:appgrowth_studio/features/media_library/repositories/media_repository.dart';
import 'package:appgrowth_studio/features/publishing/domain/platform_adapter.dart';
import 'package:appgrowth_studio/features/publishing/domain/publishing_engine.dart';
import 'package:appgrowth_studio/features/publishing/models/post_job_model.dart';
import 'package:appgrowth_studio/features/publishing/repositories/publishing_queue_repository.dart';

class MockPlatformAdapter implements PublishingPlatformAdapter {
  @override
  final String platformId;
  @override
  final String platformDisplayName;

  bool authenticated = true;
  PublishResult? nextPublishResult;
  int publishCallCount = 0;

  MockPlatformAdapter({
    required this.platformId,
    required this.platformDisplayName,
    this.authenticated = true,
    this.nextPublishResult,
  });

  @override
  Future<bool> isAuthenticated() async => authenticated;

  @override
  Future<PublishResult> publish({
    required ContentPostModel post,
    required PostJobModel job,
    List<MediaItemModel> media = const [],
  }) async {
    publishCallCount++;
    return nextPublishResult ??
        PublishResult.success(
          remoteId: 'mock_remote_${post.id}',
          remoteUrl: 'https://example.com/post/${post.id}',
          publishedAt: DateTime.now().toUtc(),
        );
  }

  @override
  Future<VerificationResult> verifyPublication({required String remoteId}) async {
    return VerificationResult(
      exists: true,
      status: 'processed',
      remoteUrl: 'https://example.com/post/$remoteId',
    );
  }

  @override
  Future<QuotaStatus> checkQuota() async {
    return QuotaStatus(
      dailyLimit: 10000,
      usedToday: 100,
      remaining: 9900,
      isExceeded: false,
      resetsAt: DateTime.now().toUtc().add(const Duration(hours: 12)),
    );
  }

  @override
  Future<void> revokeAuth() async {
    authenticated = false;
  }
}

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('Publishing Engine, Queue & Idempotency Integration Tests', () {
    late Database db;
    late PublishingQueueRepository queueRepo;
    late ContentPostRepository postRepo;
    late MediaRepository mediaRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onCreate: DatabaseMigrations.onCreate,
        ),
      );

      queueRepo = PublishingQueueRepository(db);
      postRepo = ContentPostRepository(db: db);
      mediaRepo = MediaRepository(db: db);

      // Seed test app directly in SQLite
      await db.insert(
        'apps',
        AppModel(
          id: 'app_test_1',
          name: 'Super Habit Tracker',
          packageName: 'com.super.habits',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=com.super.habits',
          category: 'Productivity',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ).toMap(),
      );

      // Seed test content post
      await db.insert(
        'content_posts',
        ContentPostModel(
          id: 'post_test_1',
          appId: 'app_test_1',
          targetPlatform: 'youtube',
          title: 'How to build habits in 21 days',
          bodyText: 'Start small and track your consistency daily!',
          format: 'video_script',
          status: 'ready',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ).toMap(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('End-to-end execution: publishes job, records attempt, stores publication, and updates post', () async {
      final mockAdapter = MockPlatformAdapter(platformId: 'youtube', platformDisplayName: 'YouTube');
      final engine = PublishingEngine(
        queueRepo: queueRepo,
        postRepo: postRepo,
        mediaRepo: mediaRepo,
        adapters: [mockAdapter],
      );

      // 1. Enqueue job
      final job = await queueRepo.enqueueJob(
        contentId: 'post_test_1',
        targetPlatform: 'youtube',
        scheduledAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      expect(job.status, equals('pending'));

      // 2. Process queue
      final summary = await engine.processPendingJobs();
      expect(summary.totalProcessed, equals(1));
      expect(summary.succeeded, equals(1));
      expect(mockAdapter.publishCallCount, equals(1));

      // 3. Verify SQLite job updated to succeeded
      final updatedJob = await queueRepo.getJobById(job.id);
      expect(updatedJob?.status, equals('succeeded'));

      // 4. Verify post_attempts record
      final attempts = await queueRepo.getAttemptsForJob(job.id);
      expect(attempts.length, equals(1));
      expect(attempts.first.status, equals('success'));
      expect(attempts.first.remoteId, equals('mock_remote_post_test_1'));

      // 5. Verify published_posts record created
      final published = await queueRepo.findPublishedPost('post_test_1', 'youtube');
      expect(published, isNotNull);
      expect(published?.remoteId, equals('mock_remote_post_test_1'));
      expect(published?.remoteUrl, equals('https://example.com/post/post_test_1'));

      // 6. Verify content_posts table updated status to 'published'
      final updatedPost = await postRepo.getPostById('post_test_1');
      expect(updatedPost?.status, equals('published'));
    });

    test('Idempotency protection: skips duplicate publication if post was already published', () async {
      final mockAdapter = MockPlatformAdapter(platformId: 'youtube', platformDisplayName: 'YouTube');
      final engine = PublishingEngine(
        queueRepo: queueRepo,
        postRepo: postRepo,
        mediaRepo: mediaRepo,
        adapters: [mockAdapter],
      );

      // 1. Manually insert published_posts record for post_test_1
      await db.insert('published_posts', {
        'id': 'pub_1',
        'post_id': 'post_test_1',
        'platform': 'youtube',
        'remote_id': 'existing_youtube_video_id',
        'remote_url': 'https://youtube.com/watch?v=existing_youtube_video_id',
        'published_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'active',
      });

      // 2. Enqueue duplicate job
      final job = await queueRepo.enqueueJob(
        contentId: 'post_test_1',
        targetPlatform: 'youtube',
        scheduledAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );

      // 3. Process queue
      final summary = await engine.processPendingJobs();
      expect(summary.totalProcessed, equals(1));
      expect(summary.skippedAlreadyPublished, equals(1));

      // Crucial: Adapter publish was NEVER called!
      expect(mockAdapter.publishCallCount, equals(0));

      // Attempt recorded as skipped_idempotent
      final attempts = await queueRepo.getAttemptsForJob(job.id);
      expect(attempts.first.status, equals('skipped_idempotent'));

      // Job marked succeeded
      final updatedJob = await queueRepo.getJobById(job.id);
      expect(updatedJob?.status, equals('succeeded'));
    });

    test('Bounded exponential retry on transient errors and bounds after max retries', () async {
      final mockAdapter = MockPlatformAdapter(
        platformId: 'youtube',
        platformDisplayName: 'YouTube',
        nextPublishResult: const PublishResult.failure(
          error: PublishError(
            code: 'NETWORK_TIMEOUT',
            message: 'Server timeout connecting to API',
            isTransient: true,
          ),
        ),
      );

      final engine = PublishingEngine(
        queueRepo: queueRepo,
        postRepo: postRepo,
        mediaRepo: mediaRepo,
        adapters: [mockAdapter],
      );

      // Enqueue job with maxRetries: 2
      final job = await queueRepo.enqueueJob(
        contentId: 'post_test_1',
        targetPlatform: 'youtube',
        maxRetries: 2,
        scheduledAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );

      // First run: transient failure -> retry 1 scheduled
      final summary1 = await engine.processPendingJobs();
      expect(summary1.retried, equals(1));

      final jobAfterAttempt1 = await queueRepo.getJobById(job.id);
      expect(jobAfterAttempt1?.status, equals('pending'));
      expect(jobAfterAttempt1?.retryCount, equals(1));
      expect(jobAfterAttempt1?.nextRetryAt, isNotNull);
      expect(jobAfterAttempt1?.nextRetryAt!.isAfter(DateTime.now().toUtc()), isTrue);

      // Simulate passage of time by setting nextRetryAt to past
      await db.update('post_jobs', {
        'next_retry_at': DateTime.now().toUtc().subtract(const Duration(seconds: 1)).toIso8601String(),
      }, where: 'id = ?', whereArgs: [job.id]);

      // Second run: transient failure -> retry 2 reached maxRetries -> permanent failure
      final summary2 = await engine.processPendingJobs();
      expect(summary2.failed, equals(1));

      final jobAfterAttempt2 = await queueRepo.getJobById(job.id);
      expect(jobAfterAttempt2?.status, equals('failed'));
      expect(jobAfterAttempt2?.retryCount, equals(2));
      expect(jobAfterAttempt2?.lastErrorCode, equals('NETWORK_TIMEOUT'));

      // Verify attempts logged
      final attempts = await queueRepo.getAttemptsForJob(job.id);
      expect(attempts.length, equals(2));
    });

    test('Unauthenticated adapter transitions job to manual_required', () async {
      final mockAdapter = MockPlatformAdapter(
        platformId: 'youtube',
        platformDisplayName: 'YouTube',
        authenticated: false, // Not authenticated
      );

      final engine = PublishingEngine(
        queueRepo: queueRepo,
        postRepo: postRepo,
        mediaRepo: mediaRepo,
        adapters: [mockAdapter],
      );

      final job = await queueRepo.enqueueJob(
        contentId: 'post_test_1',
        targetPlatform: 'youtube',
        scheduledAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );

      final summary = await engine.processPendingJobs();
      expect(summary.failed, equals(1));

      final updatedJob = await queueRepo.getJobById(job.id);
      expect(updatedJob?.status, equals('manual_required'));
      expect(updatedJob?.lastErrorCode, equals('AUTH_REQUIRED'));
    });
  });
}
