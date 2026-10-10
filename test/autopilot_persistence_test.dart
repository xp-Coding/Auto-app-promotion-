import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/features/autopilot/models/autopilot_run_model.dart';
import 'package:appgrowth_studio/features/autopilot/models/autopilot_settings_model.dart';

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('Autopilot SQLite Persistence Tests', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onCreate: DatabaseMigrations.onCreate,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('autopilot_settings table persists and retrieves correctly', () async {
      final now = DateTime.now().toUtc();
      final settings = AutopilotSettingsModel(
        id: 'default_autopilot_settings',
        isAutopilotEnabled: true,
        requireApprovalBeforePublish: false,
        dailyPostLimit: 3,
        weeklyPostLimit: 21,
        postingTimeUtc: '15:00',
        targetPlatforms: ['youtube', 'tiktok'],
        contentLanguages: ['en', 'es'],
        aiProvider: 'gemini',
        aiApiKey: 'test_key_123',
        videoFormat: '9:16',
        timeZone: 'EST',
        maxRetryAttempts: 5,
        retryDelaySeconds: 120,
        contentThemes: ['Feature Showcase', 'User Tips'],
        targetAudience: 'Software Developers & Tech Leads',
        createdAt: now,
        updatedAt: now,
      );

      await db.insert('autopilot_settings', settings.toMap());

      final results = await db.query('autopilot_settings', where: 'id = ?', whereArgs: ['default_autopilot_settings']);
      expect(results.length, equals(1));

      final retrieved = AutopilotSettingsModel.fromMap(results.first);
      expect(retrieved.id, equals('default_autopilot_settings'));
      expect(retrieved.isAutopilotEnabled, isTrue);
      expect(retrieved.requireApprovalBeforePublish, isFalse);
      expect(retrieved.dailyPostLimit, equals(3));
      expect(retrieved.weeklyPostLimit, equals(21));
      expect(retrieved.postingTimeUtc, equals('15:00'));
      expect(retrieved.targetPlatforms, equals(['youtube', 'tiktok']));
      expect(retrieved.contentLanguages, equals(['en', 'es']));
      expect(retrieved.aiProvider, equals('gemini'));
      expect(retrieved.aiApiKey, equals('test_key_123'));
      expect(retrieved.videoFormat, equals('9:16'));
      expect(retrieved.timeZone, equals('EST'));
      expect(retrieved.maxRetryAttempts, equals(5));
      expect(retrieved.retryDelaySeconds, equals(120));
      expect(retrieved.contentThemes, equals(['Feature Showcase', 'User Tips']));
      expect(retrieved.targetAudience, equals('Software Developers & Tech Leads'));
    });

    test('migration from v2 to v3 safely adds new columns', () async {
      final oldDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            // Simulate v2 schema for autopilot_settings without new columns
            await db.execute('''
              CREATE TABLE autopilot_settings (
                id TEXT PRIMARY KEY,
                is_autopilot_enabled INTEGER NOT NULL DEFAULT 1,
                require_approval_before_publish INTEGER NOT NULL DEFAULT 0,
                daily_post_limit INTEGER NOT NULL DEFAULT 2,
                weekly_post_limit INTEGER NOT NULL DEFAULT 14,
                posting_time_utc TEXT NOT NULL DEFAULT '18:00',
                target_platforms TEXT NOT NULL DEFAULT '["youtube"]',
                content_languages TEXT NOT NULL DEFAULT '["en"]',
                ai_provider TEXT NOT NULL DEFAULT 'template',
                ai_api_key TEXT,
                ai_model_name TEXT,
                video_format TEXT NOT NULL DEFAULT 'both',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
          },
        ),
      );

      // Perform upgrade
      await DatabaseMigrations.onUpgrade(oldDb, 2, 3);

      // Check columns by querying table
      final columns = await oldDb.rawQuery('PRAGMA table_info(autopilot_settings)');
      final columnNames = columns.map((c) => c['name'] as String).toList();
      expect(columnNames, contains('time_zone'));
      expect(columnNames, contains('max_retry_attempts'));
      expect(columnNames, contains('retry_delay_seconds'));
      expect(columnNames, contains('content_themes'));
      expect(columnNames, contains('target_audience'));

      await oldDb.close();
    });

    test('autopilot_runs table tracks lifecycle, progress and statistics', () async {
      final now = DateTime.now().toUtc();
      final run = AutopilotRunModel(
        id: 'run_test_001',
        appId: 'app_test_123',
        status: 'running',
        currentStep: 'Generating 30-day calendar posts...',
        progress: 0.60,
        totalPostsCreated: 30,
        totalJobsQueued: 30,
        totalAssetsCreated: 14,
        errorMessage: null,
        createdAt: now,
        updatedAt: now,
      );

      await db.insert('autopilot_runs', run.toMap());

      // Read back
      var results = await db.query('autopilot_runs', where: 'id = ?', whereArgs: ['run_test_001']);
      expect(results.length, equals(1));
      var loaded = AutopilotRunModel.fromMap(results.first);
      expect(loaded.status, equals('running'));
      expect(loaded.progress, equals(0.60));
      expect(loaded.totalPostsCreated, equals(30));

      // Update to completed
      final completed = loaded.copyWith(
        status: 'completed',
        currentStep: 'Autopilot promotion workflow complete!',
        progress: 1.0,
      );
      await db.update('autopilot_runs', completed.toMap(), where: 'id = ?', whereArgs: ['run_test_001']);

      results = await db.query('autopilot_runs', where: 'id = ?', whereArgs: ['run_test_001']);
      final finalRun = AutopilotRunModel.fromMap(results.first);
      expect(finalRun.status, equals('completed'));
      expect(finalRun.progress, equals(1.0));
      expect(finalRun.currentStep, contains('complete'));
    });
  });
}
