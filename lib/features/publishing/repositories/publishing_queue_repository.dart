import 'dart:math' as math;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../models/post_attempt_model.dart';
import '../models/post_job_model.dart';
import '../models/published_post_model.dart';

class PublishingQueueRepository {
  final Database? _db;
  final Uuid _uuid = const Uuid();

  PublishingQueueRepository([this._db]);

  Future<Database> get _database async => _db ?? await AppDatabase.instance.database;

  /// Enqueue a content post for publishing
  Future<PostJobModel> enqueueJob({
    required String contentId,
    required String targetPlatform,
    DateTime? scheduledAt,
    String? campaignId,
    int maxRetries = 3,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc();
    final effectiveScheduled = (scheduledAt ?? now).toUtc();

    final job = PostJobModel(
      id: _uuid.v4(),
      campaignId: campaignId,
      contentId: contentId,
      targetPlatform: targetPlatform,
      scheduledAt: effectiveScheduled,
      status: 'pending',
      retryCount: 0,
      maxRetries: maxRetries,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('post_jobs', job.toMap());

    // Update content post status to scheduled if currently draft or ready
    await db.update(
      'content_posts',
      {'status': 'scheduled', 'updated_at': now.toIso8601String()},
      where: 'id = ? AND status != ?',
      whereArgs: [contentId, 'published'],
    );

    return job;
  }

  /// Fetch all queued jobs optionally filtered by status
  Future<List<PostJobModel>> getJobs({String? status, String? platform}) async {
    final db = await _database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (status != null && status.isNotEmpty && status != 'all') {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }
    if (platform != null && platform.isNotEmpty && platform != 'all') {
      whereClauses.add('target_platform = ?');
      whereArgs.add(platform);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final maps = await db.query(
      'post_jobs',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'scheduled_at DESC, created_at DESC',
    );

    return maps.map(PostJobModel.fromMap).toList();
  }

  /// Get pending jobs that are due for execution
  Future<List<PostJobModel>> getDuePendingJobs({DateTime? currentUtc}) async {
    final db = await _database;
    final nowStr = (currentUtc ?? DateTime.now().toUtc()).toIso8601String();

    final maps = await db.query(
      'post_jobs',
      where: "status = 'pending' AND scheduled_at <= ? AND (next_retry_at IS NULL OR next_retry_at <= ?)",
      whereArgs: [nowStr, nowStr],
      orderBy: 'scheduled_at ASC',
    );

    return maps.map(PostJobModel.fromMap).toList();
  }

  /// Retrieve a specific job by ID
  Future<PostJobModel?> getJobById(String jobId) async {
    final db = await _database;
    final maps = await db.query(
      'post_jobs',
      where: 'id = ?',
      whereArgs: [jobId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PostJobModel.fromMap(maps.first);
  }

  /// Mark a job as running
  Future<void> markJobRunning(String jobId) async {
    final db = await _database;
    final now = DateTime.now().toUtc();
    await db.update(
      'post_jobs',
      {
        'status': 'running',
        'last_attempt_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  /// Mark job as succeeded and record publication
  Future<PublishedPostModel> markJobSucceeded({
    required String jobId,
    required String contentId,
    required String platform,
    required String remoteId,
    String? remoteUrl,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc();

    final publishedPost = PublishedPostModel(
      id: _uuid.v4(),
      postId: contentId,
      platform: platform,
      remoteId: remoteId,
      remoteUrl: remoteUrl,
      publishedAt: now,
      status: 'active',
    );

    await db.transaction((txn) async {
      // 1. Insert published post record
      await txn.insert('published_posts', publishedPost.toMap());

      // 2. Mark post job as succeeded
      await txn.update(
        'post_jobs',
        {
          'status': 'succeeded',
          'last_error_code': null,
          'last_error_message': null,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [jobId],
      );

      // 3. Mark content_post as published
      await txn.update(
        'content_posts',
        {
          'status': 'published',
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [contentId],
      );
    });

    return publishedPost;
  }

  /// Record a failure with bounded exponential retry or permanent failure
  Future<PostJobModel> markJobFailed({
    required PostJobModel job,
    required String errorCode,
    required String errorMessage,
    required bool isTransient,
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc();
    final newRetryCount = job.retryCount + 1;

    String nextStatus;
    DateTime? nextRetry;

    if (isTransient && newRetryCount < job.maxRetries) {
      nextStatus = 'pending';
      // Exponential backoff: 30s * 2^(retryCount), e.g. 30s, 60s, 120s...
      final backoffSeconds = 30 * math.pow(2, job.retryCount).toInt();
      nextRetry = now.add(Duration(seconds: backoffSeconds));
    } else if (errorCode == 'AUTH_REQUIRED' || errorCode == 'AUTH_EXPIRED' || errorCode == 'MANUAL_REQUIRED') {
      nextStatus = 'manual_required';
    } else {
      nextStatus = 'failed';
    }

    final updated = job.copyWith(
      status: nextStatus,
      retryCount: newRetryCount,
      nextRetryAt: nextRetry,
      lastErrorCode: errorCode,
      lastErrorMessage: errorMessage,
      updatedAt: now,
    );

    await db.update(
      'post_jobs',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [job.id],
    );

    return updated;
  }

  /// Record an attempt in post_attempts table
  Future<void> recordAttempt({
    required String jobId,
    required int attemptNumber,
    required String status,
    String? errorCode,
    String? errorMessage,
    String? remoteId,
  }) async {
    final db = await _database;
    final attempt = PostAttemptModel(
      id: _uuid.v4(),
      jobId: jobId,
      attemptNumber: attemptNumber,
      attemptedAt: DateTime.now().toUtc(),
      status: status,
      errorCode: errorCode,
      errorMessage: errorMessage,
      remoteId: remoteId,
    );
    await db.insert('post_attempts', attempt.toMap());
  }

  /// Fetch execution attempts for a given job
  Future<List<PostAttemptModel>> getAttemptsForJob(String jobId) async {
    final db = await _database;
    final maps = await db.query(
      'post_attempts',
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'attempt_number ASC',
    );
    return maps.map(PostAttemptModel.fromMap).toList();
  }

  /// Idempotency check: Find if a post is already published on the given platform
  Future<PublishedPostModel?> findPublishedPost(String postId, String platform) async {
    final db = await _database;
    final maps = await db.query(
      'published_posts',
      where: 'post_id = ? AND platform = ?',
      whereArgs: [postId, platform],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PublishedPostModel.fromMap(maps.first);
  }

  /// Manually retry a failed or manual_required job immediately
  Future<void> retryJobImmediately(String jobId) async {
    final db = await _database;
    final now = DateTime.now().toUtc();
    await db.update(
      'post_jobs',
      {
        'status': 'pending',
        'next_retry_at': null,
        'scheduled_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  /// Cancel a pending or manual_required job
  Future<void> cancelJob(String jobId) async {
    final db = await _database;
    final now = DateTime.now().toUtc();
    await db.update(
      'post_jobs',
      {
        'status': 'cancelled',
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  /// Delete a job and its attempts cleanly
  Future<void> deleteJob(String jobId) async {
    final db = await _database;
    await db.delete(
      'post_jobs',
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }
}
