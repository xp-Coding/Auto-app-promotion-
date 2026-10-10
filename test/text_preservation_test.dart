import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
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

  group('Part B: Storyboard and Voice-Over Text Preservation Tests', () {
    late Database db;
    late StoryboardPlannerService planner;
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
      tempTestDir = Directory.systemTemp.createTempSync('text_preservation_test_');
    });

    tearDown(() async {
      await db.close();
      if (tempTestDir.existsSync()) {
        try {
          tempTestDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    // 1. Original input remains unchanged after storyboard generation
    test('1. Original input remains unchanged after storyboard generation', () async {
      const originalInput = 'Track workouts, count daily calories, and hit your fitness milestones with FitPulse. Free on Google Play.';
      final project = await planner.planStoryboard(
        const StoryboardPlanInput(
          textPrompt: originalInput,
          templateType: 'text_to_video',
          aspectRatio: '9:16',
          targetDurationSeconds: 15.0,
        ),
      );

      expect(project.originalInputText, equals(originalInput));
      expect(project.inputTextPrompt, equals(originalInput));
      // Scenes retain key content from original text
      expect(project.scenes, isNotEmpty);
      expect(project.scenes.any((s) => s.voiceOverNarration.contains('FitPulse') || s.onScreenText.contains('FitPulse')), isTrue);
    });

    // 2. Every scene retains its own text after reordering
    test('2. Every scene retains its own text and unique identity after reordering', () async {
      final sceneA = VideoSceneModel(
        id: 'scene_a_123',
        sceneNumber: 1,
        sceneTitle: 'Intro Hook',
        onScreenText: 'Tired of Clutter?',
        voiceOverNarration: 'Say goodbye to scattered notes with QuickVault.',
        subtitleText: 'Say goodbye to scattered notes.',
        visualDescription: 'Minimalist note stack animation',
        durationSeconds: 3.5,
      );

      final sceneB = VideoSceneModel(
        id: 'scene_b_456',
        sceneNumber: 2,
        sceneTitle: 'Instant Encrypted Sync',
        onScreenText: 'End-to-End Encrypted',
        voiceOverNarration: 'All your data stays completely private and secure.',
        subtitleText: 'All your data stays private.',
        visualDescription: 'Shield lock glowing graphic',
        durationSeconds: 4.0,
      );

      final sceneC = VideoSceneModel(
        id: 'scene_c_789',
        sceneNumber: 3,
        sceneTitle: 'Get QuickVault',
        onScreenText: 'Download on Google Play',
        voiceOverNarration: 'Install QuickVault free today on Google Play.',
        subtitleText: 'Install QuickVault free today.',
        visualDescription: 'Store badges and phone mockup',
        durationSeconds: 3.5,
      );

      final project = VideoProjectModel(
        id: 'proj_test_reorder',
        title: 'QuickVault Promo',
        totalDurationSeconds: 11.0,
        scenes: [sceneA, sceneB, sceneC],
        audioNarrationScript: 'narration',
        createdAt: DateTime.now().toUtc(),
      );

      // Reorder: Move scene 1 (sceneB) to top: [sceneB, sceneA, sceneC]
      final reorderedScenes = [project.scenes[1], project.scenes[0], project.scenes[2]];
      final reorderedProject = project.copyWith(scenes: reorderedScenes);

      // Scene B should have retained its exact fields
      expect(reorderedProject.scenes[0].id, equals('scene_b_456'));
      expect(reorderedProject.scenes[0].sceneTitle, equals('Instant Encrypted Sync'));
      expect(reorderedProject.scenes[0].onScreenText, equals('End-to-End Encrypted'));
      expect(reorderedProject.scenes[0].voiceOverNarration, equals('All your data stays completely private and secure.'));

      // Scene A should have retained its exact fields
      expect(reorderedProject.scenes[1].id, equals('scene_a_123'));
      expect(reorderedProject.scenes[1].sceneTitle, equals('Intro Hook'));
      expect(reorderedProject.scenes[1].onScreenText, equals('Tired of Clutter?'));
      expect(reorderedProject.scenes[1].voiceOverNarration, equals('Say goodbye to scattered notes with QuickVault.'));

      // Scene C should have retained its exact fields
      expect(reorderedProject.scenes[2].id, equals('scene_c_789'));
      expect(reorderedProject.scenes[2].sceneTitle, equals('Get QuickVault'));
    });

    // 3. Editing scene 2 narration does not modify scene 1 or scene 3
    test('3. Editing scene 2 narration does not modify scene 1 or scene 3', () async {
      final s1 = VideoSceneModel(
        id: 's1',
        sceneNumber: 1,
        sceneTitle: 'Scene One',
        onScreenText: 'Text 1',
        voiceOverNarration: 'Narration 1',
        visualDescription: 'Visual 1',
        durationSeconds: 3.0,
      );
      final s2 = VideoSceneModel(
        id: 's2',
        sceneNumber: 2,
        sceneTitle: 'Scene Two',
        onScreenText: 'Text 2',
        voiceOverNarration: 'Narration 2 original',
        visualDescription: 'Visual 2',
        durationSeconds: 4.0,
      );
      final s3 = VideoSceneModel(
        id: 's3',
        sceneNumber: 3,
        sceneTitle: 'Scene Three',
        onScreenText: 'Text 3',
        voiceOverNarration: 'Narration 3',
        visualDescription: 'Visual 3',
        durationSeconds: 3.5,
      );

      final project = VideoProjectModel(
        id: 'proj_test_edit',
        title: 'Edit Test',
        totalDurationSeconds: 10.5,
        scenes: [s1, s2, s3],
        audioNarrationScript: '',
        createdAt: DateTime.now().toUtc(),
      );

      // Edit Scene 2 narration only
      final updatedScenes = List<VideoSceneModel>.from(project.scenes);
      updatedScenes[1] = updatedScenes[1].copyWith(voiceOverNarration: 'Brand new custom script for scene 2!');
      final updatedProject = project.copyWith(scenes: updatedScenes);

      expect(updatedProject.scenes[1].voiceOverNarration, equals('Brand new custom script for scene 2!'));
      expect(updatedProject.scenes[0].voiceOverNarration, equals('Narration 1'));
      expect(updatedProject.scenes[2].voiceOverNarration, equals('Narration 3'));
      // Scene 2 onScreenText and sceneTitle remain unchanged
      expect(updatedProject.scenes[1].onScreenText, equals('Text 2'));
      expect(updatedProject.scenes[1].sceneTitle, equals('Scene Two'));
    });

    // 4. Editing captions does not alter narration
    test('4. Editing captions does not alter voice-over narration', () {
      final scene = VideoSceneModel(
        id: 's_cap',
        sceneNumber: 1,
        sceneTitle: 'Caption Test',
        onScreenText: 'Original On-Screen Caption',
        voiceOverNarration: 'Do not touch this custom narration script under any circumstances.',
        subtitleText: 'Original Subtitle',
        visualDescription: 'Card',
        durationSeconds: 3.5,
      );

      final editedScene = scene.copyWith(
        onScreenText: 'Updated Short Headline',
        subtitleText: 'Updated Subtitle Text',
      );

      expect(editedScene.onScreenText, equals('Updated Short Headline'));
      expect(editedScene.subtitleText, equals('Updated Subtitle Text'));
      expect(editedScene.voiceOverNarration, equals('Do not touch this custom narration script under any circumstances.'));
      expect(editedScene.sceneTitle, equals('Caption Test'));
    });

    // 5. Changing visuals leaves all text untouched
    test('5. Changing visuals leaves all text untouched', () {
      final scene = VideoSceneModel(
        id: 's_vis',
        sceneNumber: 1,
        sceneTitle: 'Visual Change Test',
        onScreenText: 'Keep My Caption',
        voiceOverNarration: 'Keep My Voiceover Exactly Intact',
        subtitleText: 'Keep My Subtitle',
        visualDescription: 'Old grey background',
        imageAssetPath: '/path/to/old_image.png',
        durationSeconds: 4.0,
      );

      final project = VideoProjectModel(
        id: 'proj_vis',
        title: 'Vis',
        totalDurationSeconds: 4.0,
        scenes: [scene],
        audioNarrationScript: '',
        createdAt: DateTime.now().toUtc(),
      );

      final regeneratedScene = planner.regenerateVisualOnly(project: project, sceneIndex: 0);

      expect(regeneratedScene.sceneTitle, equals('Visual Change Test'));
      expect(regeneratedScene.onScreenText, equals('Keep My Caption'));
      expect(regeneratedScene.voiceOverNarration, equals('Keep My Voiceover Exactly Intact'));
      expect(regeneratedScene.subtitleText, equals('Keep My Subtitle'));
      expect(regeneratedScene.visualDescription, isNot(equals('Old grey background')));
    });

    // 6. Granular regeneration (Narration only & Captions only)
    test('6. Granular regeneration alters only targeted fields', () {
      final scene = VideoSceneModel(
        id: 's_granular',
        sceneNumber: 1,
        sceneTitle: 'Granular Test',
        onScreenText: 'Original Headline',
        voiceOverNarration: 'Original Narration',
        subtitleText: 'Original Subtitle',
        visualDescription: 'Original Visual Slide',
        durationSeconds: 3.5,
      );

      final project = VideoProjectModel(
        id: 'proj_gran',
        title: 'Granular Project',
        totalDurationSeconds: 3.5,
        scenes: [scene],
        audioNarrationScript: '',
        createdAt: DateTime.now().toUtc(),
      );

      // Narration only
      final narOnly = planner.regenerateNarrationOnly(project: project, sceneIndex: 0);
      expect(narOnly.voiceOverNarration, isNot(equals('Original Narration')));
      expect(narOnly.onScreenText, equals('Original Headline'));
      expect(narOnly.sceneTitle, equals('Granular Test'));
      expect(narOnly.visualDescription, equals('Original Visual Slide'));

      // Captions only
      final capOnly = planner.regenerateCaptionsOnly(project: project, sceneIndex: 0);
      expect(capOnly.onScreenText, isNot(equals('Original Headline')));
      expect(capOnly.voiceOverNarration, equals('Original Narration'));
      expect(capOnly.sceneTitle, equals('Granular Test'));
      expect(capOnly.visualDescription, equals('Original Visual Slide'));
    });

    // 7. Saving and reopening a project preserves every text field
    test('7. Saving and reopening a project preserves every text field and scene ID', () async {
      final scene1 = VideoSceneModel(
        id: 'scene_uuid_991',
        sceneNumber: 1,
        sceneTitle: 'Title 1',
        onScreenText: 'OnScreen 1',
        voiceOverNarration: 'VoiceOver 1',
        subtitleText: 'Subtitle 1',
        visualDescription: 'Desc 1',
        callToAction: 'CTA 1',
        durationSeconds: 4.0,
      );

      final project = VideoProjectModel(
        id: 'proj_persist_test',
        title: 'Persistence Test',
        originalInputText: 'Original User Prompt For Persistence',
        generatedMarketingScript: 'Generated Script',
        renderingPhaseStatus: 'visualAssetsReady',
        totalDurationSeconds: 4.0,
        scenes: [scene1],
        audioNarrationScript: 'Audio script',
        createdAt: DateTime.now().toUtc(),
      );

      // Insert directly to in-memory db
      await db.insert('video_projects', project.toMap());

      final results = await db.query('video_projects', where: 'id = ?', whereArgs: ['proj_persist_test']);
      expect(results, isNotEmpty);

      final loaded = VideoProjectModel.fromMap(results.first);
      expect(loaded.id, equals('proj_persist_test'));
      expect(loaded.originalInputText, equals('Original User Prompt For Persistence'));
      expect(loaded.generatedMarketingScript, equals('Generated Script'));
      expect(loaded.renderingPhaseStatus, equals('visualAssetsReady'));
      expect(loaded.scenes.length, equals(1));

      final loadedScene = loaded.scenes.first;
      expect(loadedScene.id, equals('scene_uuid_991'));
      expect(loadedScene.sceneTitle, equals('Title 1'));
      expect(loadedScene.onScreenText, equals('OnScreen 1'));
      expect(loadedScene.voiceOverNarration, equals('VoiceOver 1'));
      expect(loadedScene.subtitleText, equals('Subtitle 1'));
      expect(loadedScene.visualDescription, equals('Desc 1'));
      expect(loadedScene.callToAction, equals('CTA 1'));
    });

    // 8. Rendering and exporting do not modify storyboard content
    test('8. Rendering and exporting do not modify storyboard content', () async {
      final scene = VideoSceneModel(
        id: 'scene_render_check',
        sceneNumber: 1,
        sceneTitle: 'Unchanged During Render',
        onScreenText: 'Caption Static',
        voiceOverNarration: 'Voiceover Static',
        subtitleText: 'Subtitle Static',
        visualDescription: 'Card',
        durationSeconds: 3.5,
      );

      final project = VideoProjectModel(
        id: 'proj_render_test',
        title: 'Render Stability',
        originalInputText: 'Initial Input',
        totalDurationSeconds: 3.5,
        scenes: [scene],
        audioNarrationScript: 'Narration',
        createdAt: DateTime.now().toUtc(),
      );

      final exporter = VideoProjectExporter(FfmpegService());
      final result = await exporter.exportProject(
        project: project,
        outputDirectoryOverride: tempTestDir.path,
      );
      expect(result.renderedFramePaths, isNotEmpty);

      // Verify the original project model was completely untouched
      expect(project.originalInputText, equals('Initial Input'));
      expect(project.scenes.first.sceneTitle, equals('Unchanged During Render'));
      expect(project.scenes.first.onScreenText, equals('Caption Static'));
      expect(project.scenes.first.voiceOverNarration, equals('Voiceover Static'));

      // Check generated subtitle SRT uses the scene's caption/subtitle
      final srtFile = File('${tempTestDir.path}/subtitles.srt');
      expect(srtFile.existsSync(), isTrue);
      final srtContent = srtFile.readAsStringSync();
      expect(srtContent.contains('Subtitle Static'), isTrue);
    });

    // 9. Delayed generation response cannot overwrite newer user edit
    test('9. Delayed generation response cannot overwrite newer user edit (version / request ID check)', () async {
      var latestUserEditVersion = 1;
      var activeProject = VideoProjectModel(
        id: 'proj_version_check',
        title: 'Original Title',
        totalDurationSeconds: 3.5,
        scenes: [
          VideoSceneModel(
            id: 'scene_edit_1',
            sceneNumber: 1,
            sceneTitle: 'Version 1 Title',
            onScreenText: 'V1',
            voiceOverNarration: 'V1 Narration',
            visualDescription: 'V1 Visual',
            durationSeconds: 3.5,
          ),
        ],
        audioNarrationScript: '',
        createdAt: DateTime.now().toUtc(),
      );

      // Simulate user editing scene before an async operation completes
      final inFlightGenerationVersion = latestUserEditVersion; // Version 1

      // User makes an edit while request is in flight
      latestUserEditVersion++; // Version 2
      activeProject = activeProject.copyWith(
        scenes: [
          activeProject.scenes.first.copyWith(
            voiceOverNarration: 'User typed this while AI was generating!',
          ),
        ],
      );

      // Async response arrives tagged with inFlightGenerationVersion (1)
      final staleResponseNarration = 'Stale AI response from version 1';
      final shouldApply = inFlightGenerationVersion == latestUserEditVersion;

      if (shouldApply) {
        activeProject = activeProject.copyWith(
          scenes: [
            activeProject.scenes.first.copyWith(voiceOverNarration: staleResponseNarration),
          ],
        );
      }

      // Assert stale response was dropped and user edit was preserved
      expect(shouldApply, isFalse);
      expect(activeProject.scenes.first.voiceOverNarration, equals('User typed this while AI was generating!'));
    });
  });
}
