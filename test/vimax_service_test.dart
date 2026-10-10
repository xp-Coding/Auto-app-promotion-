import 'package:flutter_test/flutter_test.dart';
import 'package:appgrowth_studio/features/content_studio/domain/vimax_service.dart';
import 'package:appgrowth_studio/features/autopilot/models/video_project_model.dart';

void main() {
  group('ViMaxStatus Tests', () {
    test('parses active json status correctly', () {
      final json = {
        'status': 'ready',
        'framework': 'ViMax Agentic Video Framework 1.2.0',
        'offline_mode_available': true,
        'ffmpeg_available': true,
        'speech_synthesis': 'Native Windows SAPI & Edge-TTS',
        'llm': {'available': true, 'provider': 'openai', 'model': 'gpt-4o'},
        'image_generation': {'available': false, 'provider': 'local_procedural'},
        'video_generation': {'available': false, 'provider': 'local_compositor'},
        'daily_target': '5 videos/day',
        'jobs_count': 4,
      };

      final status = ViMaxStatus.fromJson(json);

      expect(status.isAvailable, isTrue);
      expect(status.status, 'ready');
      expect(status.framework, 'ViMax Agentic Video Framework 1.2.0');
      expect(status.offlineModeAvailable, isTrue);
      expect(status.ffmpegAvailable, isTrue);
      expect(status.speechSynthesis, contains('Native Windows SAPI'));
      expect(status.jobsCount, 4);
    });

    test('creates offline status fallback', () {
      final status = ViMaxStatus.unavailable('Connection refused');
      expect(status.isAvailable, isFalse);
      expect(status.status, 'offline');
      expect(status.errorMessage, 'Connection refused');
    });
  });

  group('WebsiteExtractedMetadata Tests', () {
    test('parses website extracted metadata json properly', () {
      final json = {
        'url': 'https://example.com',
        'domain': 'example.com',
        'brand_name': 'CloudSync Pro',
        'title': 'Intelligent Cloud Collaboration',
        'description': 'Real-time synchronization for modern teams.',
        'features': [
          'End-to-end encrypted storage',
          'Instant cross-device file sync',
          'Automated version rollback',
        ],
        'call_to_action': 'Start 14-day trial',
        'logo_url': 'https://example.com/logo.png',
        'hero_image_url': 'https://example.com/hero.jpg',
        'brand_color': '#2563EB',
        'local_images': [
          'd:/cache/img1.png',
          'd:/cache/img2.png',
        ],
        'is_accessible': true,
      };

      final meta = WebsiteExtractedMetadata.fromJson(json);

      expect(meta.isAccessible, isTrue);
      expect(meta.brandName, 'CloudSync Pro');
      expect(meta.domain, 'example.com');
      expect(meta.features.length, 3);
      expect(meta.features.first, 'End-to-end encrypted storage');
      expect(meta.brandColor, '#2563EB');
      expect(meta.localImages.length, 2);
      expect(meta.callToAction, 'Start 14-day trial');
    });
  });

  group('ViMaxJobState Tests', () {
    test('handles running job state correctly', () {
      final json = {
        'job_id': 'job_123',
        'status': 'generating_video_clips',
        'stage': 'generating_video_clips',
        'stage_message': 'Compositing scene 2/4',
        'progress': 0.45,
        'elapsed_seconds': 5.2,
        'logs': ['[10:00:00] Job queued', '[10:00:02] Clip 1 done'],
      };

      final state = ViMaxJobState.fromJson(json);

      expect(state.jobId, 'job_123');
      expect(state.isRunning, isTrue);
      expect(state.isCompleted, isFalse);
      expect(state.isFailed, isFalse);
      expect(state.progress, 0.45);
      expect(state.elapsedSeconds, 5.2);
      expect(state.logs.length, 2);
    });

    test('handles completed job state correctly with mp4 and validation', () {
      final json = {
        'job_id': 'job_123',
        'status': 'completed',
        'stage': 'completed',
        'stage_message': 'Video verified',
        'progress': 1.0,
        'elapsed_seconds': 14.8,
        'mp4_path': 'd:/renders/video.mp4',
        'validation': {
          'is_valid': true,
          'duration_seconds': 15.2,
          'size_bytes': 1048576,
          'codec': 'h264',
          'width': 1080,
          'height': 1920,
        },
      };

      final state = ViMaxJobState.fromJson(json);

      expect(state.isCompleted, isTrue);
      expect(state.isRunning, isFalse);
      expect(state.mp4Path, 'd:/renders/video.mp4');
      expect(state.validation?['is_valid'], isTrue);
      expect(state.validation?['codec'], 'h264');
    });
  });

  group('Storyboard State Preservation Tests', () {
    test('editing narration never overwrites title, onScreenText, or visualDescription', () {
      final originalScene = VideoSceneModel(
        id: 'scene_custom_1',
        sceneNumber: 1,
        sceneTitle: 'High-Converting Hook',
        onScreenText: 'Stop Wasting Time on Manual Tasks',
        voiceOverNarration: 'Original voiceover script explaining the dilemma.',
        subtitleText: 'Original voiceover script explaining the dilemma.',
        visualDescription: 'Frustrated user working on late night spreadsheets',
        durationSeconds: 5.0,
        badgeText: 'Hook',
        imageAssetPath: 'd:/assets/screen_1.png',
      );

      // User modifies voiceover narration
      final updatedScene = originalScene.copyWith(
        voiceOverNarration: 'New rewritten voiceover: Tired of repetitive administrative work?',
      );

      // Verify that all unrelated fields are 100% preserved
      expect(updatedScene.id, 'scene_custom_1');
      expect(updatedScene.sceneTitle, 'High-Converting Hook');
      expect(updatedScene.onScreenText, 'Stop Wasting Time on Manual Tasks');
      expect(updatedScene.visualDescription, 'Frustrated user working on late night spreadsheets');
      expect(updatedScene.durationSeconds, 5.0);
      expect(updatedScene.badgeText, 'Hook');
      expect(updatedScene.imageAssetPath, 'd:/assets/screen_1.png');
      expect(updatedScene.voiceOverNarration, contains('New rewritten voiceover'));
    });

    test('regenerating visual only preserves narration, captions, and title', () {
      final scene = VideoSceneModel(
        id: 'scene_custom_2',
        sceneNumber: 2,
        sceneTitle: 'Feature Demonstration',
        onScreenText: 'Automate in One Click',
        voiceOverNarration: 'Our intelligent algorithms handle everything in seconds.',
        subtitleText: 'Our intelligent algorithms handle everything in seconds.',
        visualDescription: 'Old mockup diagram',
        durationSeconds: 4.5,
      );

      // ViMax granular visual regeneration
      final visualRegenerated = scene.copyWith(
        visualDescription: 'Next-gen isometric 3D glowing dashboard',
        imageAssetPath: 'd:/assets/new_procedural_render.png',
      );

      expect(visualRegenerated.sceneTitle, scene.sceneTitle);
      expect(visualRegenerated.onScreenText, scene.onScreenText);
      expect(visualRegenerated.voiceOverNarration, scene.voiceOverNarration);
      expect(visualRegenerated.subtitleText, scene.subtitleText);
      expect(visualRegenerated.durationSeconds, scene.durationSeconds);
      expect(visualRegenerated.imageAssetPath, 'd:/assets/new_procedural_render.png');
    });

    test('reordering scenes maintains stable IDs and asset references', () {
      final sceneA = VideoSceneModel(
        id: 'stable_id_A',
        sceneNumber: 1,
        sceneTitle: 'Hook',
        onScreenText: 'Text A',
        voiceOverNarration: 'Narration A',
        subtitleText: 'Subtitle A',
        visualDescription: 'Visual A',
        imageAssetPath: 'd:/images/a.png',
        durationSeconds: 4.0,
      );

      final sceneB = VideoSceneModel(
        id: 'stable_id_B',
        sceneNumber: 2,
        sceneTitle: 'Demo',
        onScreenText: 'Text B',
        voiceOverNarration: 'Narration B',
        subtitleText: 'Subtitle B',
        visualDescription: 'Visual B',
        imageAssetPath: 'd:/images/b.png',
        durationSeconds: 4.0,
      );

      final project = VideoProjectModel(
        id: 'proj_stable_1',
        title: 'Multi-Scene Project',
        templateType: 'saas_product_ad',
        aspectRatio: '9:16',
        resolution: '1080p',
        totalDurationSeconds: 8.0,
        scenes: [sceneA, sceneB],
        audioNarrationScript: 'Narration A Narration B',
        createdAt: DateTime.now(),
      );

      // Reorder scenes: swap A and B
      final reorderedScenes = [project.scenes[1], project.scenes[0]];
      final reorderedProject = project.copyWith(scenes: reorderedScenes);

      expect(reorderedProject.scenes[0].id, 'stable_id_B');
      expect(reorderedProject.scenes[0].imageAssetPath, 'd:/images/b.png');
      expect(reorderedProject.scenes[0].sceneTitle, 'Demo');

      expect(reorderedProject.scenes[1].id, 'stable_id_A');
      expect(reorderedProject.scenes[1].imageAssetPath, 'd:/images/a.png');
      expect(reorderedProject.scenes[1].sceneTitle, 'Hook');
    });
  });
}
