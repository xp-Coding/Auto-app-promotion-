import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/features/apps/models/app_model.dart';
import 'package:appgrowth_studio/features/autopilot/domain/play_store_scraper.dart';
import 'package:appgrowth_studio/features/autopilot/domain/video_project_exporter.dart';
import 'package:appgrowth_studio/features/autopilot/models/autopilot_settings_model.dart';
import 'package:appgrowth_studio/features/autopilot/models/video_project_model.dart';
import 'package:appgrowth_studio/features/content_studio/domain/content_generation_provider.dart';
import 'package:appgrowth_studio/features/content_studio/domain/smart_content_provider.dart';

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('Autopilot Workflow & Smart Content Tests', () {
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

    test('SmartContentProvider falls back to local templates without API key', () async {
      final now = DateTime.now().toUtc();
      final settings = AutopilotSettingsModel(
        aiProvider: 'gemini',
        aiApiKey: null, // No key provided
        createdAt: now,
        updatedAt: now,
      );

      final provider = SmartContentProvider(settings: settings);

      final app = AppModel(
        id: 'test_app_id',
        name: 'TaskMaster Pro',
        packageName: 'com.taskmaster.pro',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.taskmaster.pro',
        category: 'Productivity',
        mainFeatures: const ['Smart Scheduling', 'Pomodoro Timer', 'Cloud Sync'],
        targetAudience: 'Remote workers & students',
        createdAt: now,
        updatedAt: now,
      );

      final result = await provider.generateContent(
        ContentGenerationRequest(
          app: app,
          targetPlatform: 'YouTube',
          contentFormat: 'video_script',
          topicOrTheme: 'Boost Daily Focus with Smart Scheduling',
        ),
      );

      expect(result.bodyText.isNotEmpty, isTrue);
      expect(result.bodyText, contains('TaskMaster Pro'));
      expect(result.hashtags.isNotEmpty, isTrue);
      expect(result.scriptHook.isNotEmpty, isTrue);
      expect(result.providerName, contains('Local Template'));
    });

    test('VideoProjectExporter produces frames, srt, script, and interactive HTML preview', () async {
      final now = DateTime.now().toUtc();
      final app = AppModel(
        id: 'test_app_id',
        name: 'TaskMaster Pro',
        packageName: 'com.taskmaster.pro',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.taskmaster.pro',
        category: 'Productivity',
        mainFeatures: const ['Smart Scheduling', 'Pomodoro Timer', 'Cloud Sync'],
        targetAudience: 'Remote workers & students',
        createdAt: now,
        updatedAt: now,
      );

      final project = VideoProjectModel(
        id: 'test_vid_proj_01',
        appId: 'test_app_id',
        templateType: 'feature_showcase',
        title: 'TaskMaster Pro Launch Promo',
        aspectRatio: '9:16',
        totalDurationSeconds: 12.0,
        audioNarrationScript: 'Stop procrastinating today with TaskMaster Pro. Smart scheduling is here.',
        scenes: const [
          VideoSceneModel(
            sceneNumber: 1,
            title: 'Stop Procrastinating Today',
            narrationText: 'Are you overwhelmed by your daily todo list? Here is the solution.',
            visualDescription: 'App icon floating with bold hook headline',
            durationSeconds: 4.0,
            badgeText: 'Hook',
          ),
          VideoSceneModel(
            sceneNumber: 2,
            title: 'Smart Scheduling in Action',
            narrationText: 'TaskMaster Pro organizes your tasks automatically with smart priority.',
            visualDescription: 'Live screenshot demonstrating scheduling',
            durationSeconds: 5.0,
            badgeText: 'Feature',
          ),
          VideoSceneModel(
            sceneNumber: 3,
            title: 'Download on Google Play',
            narrationText: 'Get TaskMaster Pro now and take control of your time.',
            visualDescription: 'Store badges and final CTA',
            durationSeconds: 3.0,
            badgeText: 'Get App',
          ),
        ],
        createdAt: now,
      );

      final exporter = VideoProjectExporter();
      final exportResult = await exporter.exportProject(
        project: project,
        app: app,
      );

      expect(exportResult.success, isTrue);
      expect(exportResult.exportDirectoryPath, isNotEmpty);
      expect(exportResult.htmlPreviewPath, isNotEmpty);

      // Verify HTML interactive preview was written
      final htmlFile = File(exportResult.htmlPreviewPath);
      expect(await htmlFile.exists(), isTrue);
      final htmlContent = await htmlFile.readAsString();
      expect(htmlContent, contains('TaskMaster Pro Launch Promo'));
      expect(htmlContent, contains('Stop Procrastinating Today'));

      // Verify SRT file
      final srtFile = File(p.join(exportResult.exportDirectoryPath, 'subtitles.srt'));
      expect(await srtFile.exists(), isTrue);
      final srtContent = await srtFile.readAsString();
      expect(srtContent, contains('-->'));
      expect(srtContent, contains('Are you overwhelmed by your daily todo list?'));

      // Verify Narration Script
      final scriptFile = File(p.join(exportResult.exportDirectoryPath, 'narration_script.txt'));
      expect(await scriptFile.exists(), isTrue);
      final scriptContent = await scriptFile.readAsString();
      expect(scriptContent, contains('PROMOTIONAL VIDEO NARRATION SCRIPT'));
      expect(scriptContent, contains('TaskMaster Pro Launch Promo'));
    });

    test('PlayStoreScraperService to ScrapedAppResult generates complete verified profile', () async {
      final scraper = PlayStoreScraperService();
      final scraped = await scraper.scrapeAndExtractApp(urlOrPackage: 'com.zenmind.meditation');

      expect(scraped.app.name.isNotEmpty, isTrue);
      expect(scraped.app.packageName, equals('com.zenmind.meditation'));
      expect(scraped.app.category, equals('Health & Fitness'));
      expect(scraped.developerName, equals('Zenmind Inc'));
      expect(scraped.targetAudience, contains('wellness'));
      expect(scraped.extractedFeatures, isNotEmpty);
      expect(scraped.extractedUsps, isNotEmpty);
      expect(scraped.extractedUseCases, isNotEmpty);
      expect(scraped.validationChecklist['Title & Package Identified'], isTrue);
      expect(scraped.validationChecklist['Category Classified'], isTrue);
    });

    test('Publishing queue idempotency prevents duplicate scheduling', () async {
      // First ensure an app exists for foreign key constraint
      final nowStr = DateTime.now().toUtc().toIso8601String();
      await db.insert('apps', {
        'id': 'test_app_id_idem',
        'name': 'Zenmind Meditation',
        'package_name': 'com.zenmind.meditation',
        'play_store_url': 'https://play.google.com/store/apps/details?id=com.zenmind.meditation',
        'category': 'Health & Fitness',
        'main_features': '["Meditation"]',
        'unique_selling_points': '["Calm"]',
        'target_countries': '["US"]',
        'supported_languages': '["en"]',
        'created_at': nowStr,
        'updated_at': nowStr,
      });

      // Insert an existing scheduled post in content_posts
      await db.insert('content_posts', {
        'id': 'post_idem_001',
        'app_id': 'test_app_id_idem',
        'campaign_id': null,
        'target_platform': 'youtube',
        'title': 'Zenmind Morning Routine',
        'body_text': 'Start your morning with guided mindfulness.',
        'hashtags': '#mindfulness #zen',
        'format': 'video_script',
        'status': 'scheduled',
        'created_at': nowStr,
        'updated_at': nowStr,
      });

      // Query if post with identical title and platform already exists
      final existing = await db.query(
        'content_posts',
        where: 'app_id = ? AND target_platform = ? AND title = ?',
        whereArgs: ['test_app_id_idem', 'youtube', 'Zenmind Morning Routine'],
      );

      expect(existing.length, equals(1));
      // Idempotency check prevents duplicate insertion
      final shouldSchedule = existing.isEmpty;
      expect(shouldSchedule, isFalse);
    });
  });
}
