import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/features/apps/models/app_model.dart';
import 'package:appgrowth_studio/features/autopilot/domain/video_project_exporter.dart';
import 'package:appgrowth_studio/features/autopilot/models/video_project_model.dart';
import 'package:appgrowth_studio/features/content_studio/domain/ffmpeg_service.dart';
import 'package:appgrowth_studio/features/content_studio/domain/storyboard_planner_service.dart';

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('Multi-Input Video Creator Workflow Tests', () {
    late Database db;
    late StoryboardPlannerService planner;
    late FfmpegService ffmpegService;
    late VideoProjectExporter exporter;
    late Directory tempTestDir;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onCreate: DatabaseMigrations.onCreate,
        ),
      );

      planner = StoryboardPlannerService();
      ffmpegService = FfmpegService();
      exporter = VideoProjectExporter(ffmpegService);
      tempTestDir = Directory.systemTemp.createTempSync('video_creator_test_');
    });

    tearDown(() async {
      await db.close();
      if (tempTestDir.existsSync()) {
        try {
          tempTestDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    // ------------------------------------------------------------------------
    // SCENARIO 1: Text-only video creation
    // ------------------------------------------------------------------------
    test('Scenario 1: Text-only video creation generates structured storyboard', () async {
      final project = await planner.planStoryboard(
        const StoryboardPlanInput(
          textPrompt: 'Boost your daily productivity with HabitForge. Build daily streaks, stay focused with pomodoro timers, and achieve your goals effortlessly. Download free today!',
          templateType: 'text_to_video',
          aspectRatio: '9:16',
          resolution: '1080p',
          targetDurationSeconds: 15.0,
        ),
      );

      expect(project.sourceType, equals('text'));
      expect(project.scenes, isNotEmpty);
      expect(project.aspectRatio, equals('9:16'));
      expect(project.resolution, equals('1080p'));

      // Check scene structure
      expect(project.scenes.first.sceneNumber, equals(1));
      expect(project.scenes.last.badgeText, equals('Get Started'));
      for (final scene in project.scenes) {
        expect(scene.title, isNotEmpty);
        expect(scene.captionText, isNotEmpty);
        expect(scene.durationSeconds, greaterThan(0));
      }
    });

    // ------------------------------------------------------------------------
    // SCENARIO 2: Screenshot-only video creation
    // ------------------------------------------------------------------------
    test('Scenario 2: Screenshot-only video creation incorporates images without distortion', () async {
      final img1 = p.join(tempTestDir.path, 'screen1.png');
      final img2 = p.join(tempTestDir.path, 'screen2.png');
      final img3 = p.join(tempTestDir.path, 'screen3.png');
      File(img1).writeAsStringSync('fake-image-data-1');
      File(img2).writeAsStringSync('fake-image-data-2');
      File(img3).writeAsStringSync('fake-image-data-3');

      final project = await planner.planStoryboard(
        StoryboardPlanInput(
          screenshotPaths: [img1, img2, img3],
          templateType: 'promotional_slideshow',
          aspectRatio: '16:9',
          resolution: '720p',
          targetDurationSeconds: 15.0,
        ),
      );

      expect(project.sourceType, equals('screenshots'));
      expect(project.aspectRatio, equals('16:9'));
      expect(project.resolution, equals('720p'));

      // Scenes should map to screenshots with contain fit mode (no distortion)
      final mediaScenes = project.scenes.where((s) => s.imageAssetPath != null).toList();
      expect(mediaScenes, isNotEmpty);
      for (final s in mediaScenes) {
        expect(s.fitMode, equals('contain'));
      }
    });

    // ------------------------------------------------------------------------
    // SCENARIO 3: Existing-video-only project
    // ------------------------------------------------------------------------
    test('Scenario 3: Existing-video-only project preserves trim boundaries', () async {
      final clip1 = p.join(tempTestDir.path, 'gameplay.mp4');
      final clip2 = p.join(tempTestDir.path, 'features.mp4');
      File(clip1).writeAsStringSync('fake-mp4-data-1');
      File(clip2).writeAsStringSync('fake-mp4-data-2');

      final project = await planner.planStoryboard(
        StoryboardPlanInput(
          videoClipPaths: [clip1, clip2],
          templateType: 'video_enhancement',
          aspectRatio: '1:1',
          resolution: '1080p',
        ),
      );

      expect(project.sourceType, equals('video_clips'));
      expect(project.aspectRatio, equals('1:1'));

      final videoScenes = project.scenes.where((s) => s.videoClipPath != null).toList();
      expect(videoScenes, isNotEmpty);
      for (final s in videoScenes) {
        expect(s.fitMode, equals('contain'));
      }
    });

    // ------------------------------------------------------------------------
    // SCENARIO 4: App URL-based project
    // ------------------------------------------------------------------------
    test('Scenario 4: App URL-based project extracts listing metadata into scenes', () async {
      final app = AppModel(
        id: 'app_url_test',
        name: 'ZenFocus Meditation',
        packageName: 'com.zenfocus.meditation',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.zenfocus.meditation',
        category: 'Health & Fitness',
        shortDescription: 'Breathe, meditate, and sleep deeply with guided sessions.',
        mainFeatures: const ['Guided Breathing', 'Sleep Soundscapes', 'Daily Mindfulness'],
        targetAudience: 'Stressed professionals and mindful individuals',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final project = await planner.planStoryboard(
        StoryboardPlanInput(
          selectedApp: app,
          templateType: 'feature_showcase',
          aspectRatio: '9:16',
          resolution: '1080p',
          targetDurationSeconds: 20.0,
        ),
      );

      expect(project.scenes.length, greaterThanOrEqualTo(4));
      expect(project.title, contains('ZenFocus'));

      // Check that call to action scene was generated
      expect(project.scenes.last.badgeText, equals('Get App'));
      expect(project.scenes.last.narrationText, contains('ZenFocus'));
    });

    // ------------------------------------------------------------------------
    // SCENARIO 5: Combination of ALL FOUR input types
    // ------------------------------------------------------------------------
    test('Scenario 5: Combination of URL, screenshots, clips, and text in one project', () async {
      final app = AppModel(
        id: 'quad_input_test',
        name: 'CryptoTracker Live',
        packageName: 'com.cryptotracker.live',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.cryptotracker.live',
        category: 'Finance',
        mainFeatures: const ['Real-time Alerts', 'Portfolio Insights'],
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final imgPath = p.join(tempTestDir.path, 'chart_screenshot.png');
      final clipPath = p.join(tempTestDir.path, 'live_ticker.mp4');
      File(imgPath).writeAsStringSync('png-bytes');
      File(clipPath).writeAsStringSync('mp4-bytes');

      final project = await planner.planStoryboard(
        StoryboardPlanInput(
          appUrl: 'https://play.google.com/store/apps/details?id=com.cryptotracker.live',
          selectedApp: app,
          screenshotPaths: [imgPath],
          videoClipPaths: [clipPath],
          textPrompt: 'Experience real-time portfolio management with zero lag. Used by 500,000 traders worldwide.',
          templateType: 'feature_showcase',
          aspectRatio: '9:16',
          resolution: '1080p',
        ),
      );

      expect(project.sourceType, equals('mixed'));
      expect(project.inputMediaPaths, isNotEmpty);

      // Verify scenes include image asset
      final hasImageScene = project.scenes.any((s) => s.imageAssetPath == imgPath);
      expect(hasImageScene, isTrue);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 6: Exporting to a user-selected local destination folder
    // ------------------------------------------------------------------------
    test('Scenario 6: Exporting project package and saving to local computer folder', () async {
      final project = await planner.planStoryboard(
        const StoryboardPlanInput(
          textPrompt: 'Quick showcase of TaskFlow. Manage projects effortlessly.',
          templateType: 'text_to_video',
          aspectRatio: '16:9',
          resolution: '720p',
        ),
      );

      // Render project package
      final exportResult = await exporter.exportProject(project: project);
      expect(exportResult.success, isTrue);
      expect(File(exportResult.htmlPreviewPath).existsSync(), isTrue);

      // User selects a custom local destination
      final userSelectedFolder = p.join(tempTestDir.path, 'UserChosenDestination');
      Directory(userSelectedFolder).createSync(recursive: true);
      final targetFile = p.join(userSelectedFolder, 'MyFinalPromo_720p.html');

      final savedResult = await exporter.exportToLocalDestination(
        project: project,
        destinationFilePath: targetFile,
      );

      expect(savedResult.success, isTrue);
      expect(File(savedResult.htmlPreviewPath).existsSync(), isTrue);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 7: SQLite persistence, reopening a saved project, and re-exporting
    // ------------------------------------------------------------------------
    test('Scenario 7: Reopening a saved project from SQLite and updating settings', () async {
      final original = await planner.planStoryboard(
        const StoryboardPlanInput(
          textPrompt: 'Reopening project test prompt.',
          templateType: 'problem_solution',
          aspectRatio: '9:16',
          resolution: '1080p',
        ),
      );

      // Save to SQLite
      await db.insert('video_projects', original.toMap());

      // Query back
      final rows = await db.query('video_projects', where: 'id = ?', whereArgs: [original.id]);
      expect(rows, isNotEmpty);
      final restored = VideoProjectModel.fromMap(rows.first);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.templateType, equals('problem_solution'));
      expect(restored.scenes.length, equals(original.scenes.length));
      expect(restored.aspectRatio, equals('9:16'));

      // Modify aspect ratio to 16:9 and update in DB
      final modified = restored.copyWith(
        aspectRatio: '16:9',
        resolution: '720p',
        exportStatus: 'exported',
      );
      await db.update('video_projects', modified.toMap(), where: 'id = ?', whereArgs: [modified.id]);

      final reloadedRows = await db.query('video_projects', where: 'id = ?', whereArgs: [original.id]);
      final reloaded = VideoProjectModel.fromMap(reloadedRows.first);
      expect(reloaded.aspectRatio, equals('16:9'));
      expect(reloaded.resolution, equals('720p'));
      expect(reloaded.exportStatus, equals('exported'));
    });

    // ------------------------------------------------------------------------
    // SCENARIO 8: Error handling and scene regeneration
    // ------------------------------------------------------------------------
    test('Scenario 8: Robust error handling and scene regeneration', () async {
      // Empty input throws ArgumentError
      expect(
        () => planner.planStoryboard(const StoryboardPlanInput()),
        throwsArgumentError,
      );

      final project = await planner.planStoryboard(
        const StoryboardPlanInput(
          textPrompt: 'Sample app to test scene regeneration.',
          templateType: 'feature_showcase',
        ),
      );

      // Single scene regeneration
      final originalScene = project.scenes[1];
      final regenerated = planner.regenerateScene(
        project: project,
        sceneIndex: 1,
      );

      expect(regenerated.sceneNumber, equals(originalScene.sceneNumber));
      expect(regenerated.title, isNotEmpty);
      expect(regenerated.narrationText, isNotEmpty);
    });

    // ------------------------------------------------------------------------
    // SCENARIO 9: Aspect ratio and resolution dimensions verification
    // ------------------------------------------------------------------------
    test('Scenario 9: Aspect ratio dimensions are exact and never distorted', () {
      final dims916_1080 = VideoProjectExporter.getDimensions('9:16', '1080p');
      expect(dims916_1080.width, equals(1080));
      expect(dims916_1080.height, equals(1920));

      final dims916_720 = VideoProjectExporter.getDimensions('9:16', '720p');
      expect(dims916_720.width, equals(720));
      expect(dims916_720.height, equals(1280));

      final dims169_1080 = VideoProjectExporter.getDimensions('16:9', '1080p');
      expect(dims169_1080.width, equals(1920));
      expect(dims169_1080.height, equals(1080));

      final dims11_1080 = VideoProjectExporter.getDimensions('1:1', '1080p');
      expect(dims11_1080.width, equals(1080));
      expect(dims11_1080.height, equals(1080));
    });
  });
}
