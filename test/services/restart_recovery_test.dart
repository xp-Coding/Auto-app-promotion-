import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/core/services/safe_background_worker.dart';
import 'package:appgrowth_studio/features/publishing/repositories/publishing_queue_repository.dart';

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('Restart Recovery and Background Worker Integration Tests', () {
    late Database db;
    late PublishingQueueRepository queueRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onCreate: DatabaseMigrations.onCreate,
        ),
      );

      queueRepo = PublishingQueueRepository(db);

      // Seed app & content posts
      await db.insert('apps', {
        'id': 'app_rec_1',
        'name': 'Habit Rocket',
        'package_name': 'com.habit.rocket',
        'play_store_url': 'https://play.google.com/store/apps/details?id=com.habit.rocket',
        'category': 'Productivity',
        'is_archived': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await db.insert('content_posts', {
        'id': 'post_rec_1',
        'app_id': 'app_rec_1',
        'target_platform': 'youtube',
        'title': 'Habit Building 101',
        'body_text': 'Track daily progress.',
        'format': 'video_script',
        'status': 'ready',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await db.insert('content_posts', {
        'id': 'post_rec_2',
        'app_id': 'app_rec_1',
        'target_platform': 'youtube',
        'title': 'Morning Routine Secrets',
        'body_text': 'Wake up with purpose.',
        'format': 'video_script',
        'status': 'ready',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Restart recovery detects stuck running jobs and safely resolves them', () async {
      final now = DateTime.now().toUtc();

      // Stuck Job 1: Was running, but was NOT published before app crashed
      await db.insert('post_jobs', {
        'id': 'job_stuck_1',
        'content_id': 'post_rec_1',
        'target_platform': 'youtube',
        'scheduled_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'status': 'running',
        'retry_count': 0,
        'max_retries': 3,
        'last_attempt_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'updated_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
      });

      // Stuck Job 2: Was running, and publication succeeded right before app crashed
      await db.insert('post_jobs', {
        'id': 'job_stuck_2',
        'content_id': 'post_rec_2',
        'target_platform': 'youtube',
        'scheduled_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'status': 'running',
        'retry_count': 0,
        'max_retries': 3,
        'last_attempt_at': now.subtract(const Duration(minutes: 2)).toIso8601String(),
        'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'updated_at': now.subtract(const Duration(minutes: 2)).toIso8601String(),
      });

      // Insert published_posts for post_rec_2
      await db.insert('published_posts', {
        'id': 'pub_rec_2',
        'post_id': 'post_rec_2',
        'platform': 'youtube',
        'remote_id': 'yt_confirmed_vid_999',
        'remote_url': 'https://youtube.com/watch?v=yt_confirmed_vid_999',
        'published_at': now.subtract(const Duration(minutes: 2)).toIso8601String(),
        'status': 'active',
      });

      // Execute Startup Recovery
      final recoveredCount = await SafeBackgroundWorker.instance.performStartupRecovery(db: db);
      expect(recoveredCount, equals(2));

      // Verify Job 1 reset to pending
      final job1 = await queueRepo.getJobById('job_stuck_1');
      expect(job1?.status, equals('pending'));

      final attemptsJob1 = await queueRepo.getAttemptsForJob('job_stuck_1');
      expect(attemptsJob1.length, equals(1));
      expect(attemptsJob1.first.status, equals('interrupted_recovered'));

      // Verify Job 2 marked succeeded
      final job2 = await queueRepo.getJobById('job_stuck_2');
      expect(job2?.status, equals('succeeded'));
    });
  });
}
