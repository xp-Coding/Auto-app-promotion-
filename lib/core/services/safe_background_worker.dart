import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/app_database.dart';
import '../logging/app_logger.dart';
import '../../features/publishing/domain/publishing_engine.dart';
import '../../features/publishing/repositories/publishing_queue_repository.dart';

class SafeBackgroundWorker {
  static SafeBackgroundWorker? _instance;
  static SafeBackgroundWorker get instance => _instance ??= SafeBackgroundWorker._();

  Timer? _ticker;
  bool _isRunning = false;
  bool _isProcessing = false;
  PublishingEngine? _engine;

  SafeBackgroundWorker._();

  bool get isActive => _isRunning;

  /// Perform restart recovery on application startup
  Future<int> performStartupRecovery({Database? db}) async {
    final database = db ?? await AppDatabase.instance.database;
    final queue = PublishingQueueRepository(database);
    await AppLogger.info('system', 'Starting startup recovery checks...');

    try {
      // Find jobs stuck in 'running' state from previous abnormal termination/reboot
      final stuckJobs = await database.query(
        'post_jobs',
        where: "status = 'running'",
      );

      if (stuckJobs.isEmpty) {
        await AppLogger.info('system', 'Startup recovery clean: 0 interrupted jobs found.');
        return 0;
      }

      int recoveredCount = 0;
      final now = DateTime.now().toUtc();

      for (final map in stuckJobs) {
        final jobId = map['id'] as String;
        final contentId = map['content_id'] as String;
        final platform = map['target_platform'] as String;

        // Check if publication already occurred
        final existingPub = await database.query(
          'published_posts',
          where: 'post_id = ? AND platform = ?',
          whereArgs: [contentId, platform],
        );

        if (existingPub.isNotEmpty) {
          // Job actually completed before shutdown
          await database.update(
            'post_jobs',
            {'status': 'succeeded', 'updated_at': now.toIso8601String()},
            where: 'id = ?',
            whereArgs: [jobId],
          );
          await AppLogger.success('publishing', 'Recovered job $jobId: marked succeeded (remote publication verified).');
        } else {
          // Reset job to pending so it will be retried cleanly
          await database.update(
            'post_jobs',
            {
              'status': 'pending',
              'next_retry_at': null,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [jobId],
          );

          await queue.recordAttempt(
            jobId: jobId,
            attemptNumber: (map['retry_count'] as num).toInt() + 1,
            status: 'interrupted_recovered',
            errorMessage: 'Job was interrupted by unexpected app restart; automatically reset to pending.',
          );

          await AppLogger.warn('publishing', 'Recovered interrupted job $jobId: reset to pending.');
        }
        recoveredCount++;
      }

      return recoveredCount;
    } catch (e) {
      await AppLogger.error('system', 'Error during restart recovery: $e');
      return 0;
    }
  }

  /// Start background execution heartbeat (runs every 30 seconds)
  void start({required PublishingEngine engine, Duration interval = const Duration(seconds: 30)}) {
    if (_isRunning) return;
    _engine = engine;
    _isRunning = true;

    _ticker = Timer.periodic(interval, (_) => _onHeartbeat());
    AppLogger.info('system', 'Safe Windows background heartbeat worker started (interval: ${interval.inSeconds}s).');
  }

  /// Stop background execution
  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _isRunning = false;
    AppLogger.info('system', 'Safe background worker stopped.');
  }

  Future<void> _onHeartbeat() async {
    if (!_isRunning || _isProcessing || _engine == null) return;
    _isProcessing = true;

    try {
      final summary = await _engine!.processPendingJobs();
      if (summary.totalProcessed > 0) {
        await AppLogger.info(
          'publishing',
          'Background cycle processed ${summary.totalProcessed} due jobs (${summary.succeeded} succeeded, ${summary.failed} failed, ${summary.retried} retrying).',
        );
      }
    } catch (e) {
      await AppLogger.error('system', 'Background execution error: $e');
    } finally {
      _isProcessing = false;
    }
  }
}
