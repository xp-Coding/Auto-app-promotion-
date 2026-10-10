import 'package:uuid/uuid.dart';
import '../../apps/models/app_model.dart';
import '../../autopilot/domain/play_store_scraper.dart';
import '../../autopilot/models/video_project_model.dart';

class StoryboardPlanInput {
  final String? appUrl;
  final List<String> screenshotPaths;
  final List<String> videoClipPaths;
  final String? textPrompt;
  final AppModel? selectedApp;
  final String templateType;
  final String aspectRatio;
  final String resolution;
  final double targetDurationSeconds;
  final String captionStyle;
  final String transitionStyle;
  final String? backgroundMusicPath;
  final double backgroundMusicVolume;
  final bool enableVoiceNarration;

  const StoryboardPlanInput({
    this.appUrl,
    this.screenshotPaths = const [],
    this.videoClipPaths = const [],
    this.textPrompt,
    this.selectedApp,
    this.templateType = 'feature_showcase',
    this.aspectRatio = '9:16',
    this.resolution = '1080p',
    this.targetDurationSeconds = 15.0,
    this.captionStyle = 'modern',
    this.transitionStyle = 'fade',
    this.backgroundMusicPath,
    this.backgroundMusicVolume = 0.2,
    this.enableVoiceNarration = false,
  });

  bool get hasAnyInput =>
      (appUrl != null && appUrl!.trim().isNotEmpty) ||
      screenshotPaths.isNotEmpty ||
      videoClipPaths.isNotEmpty ||
      (textPrompt != null && textPrompt!.trim().isNotEmpty) ||
      selectedApp != null;

  String get detectedSourceType {
    final types = <String>[];
    if (appUrl != null && appUrl!.trim().isNotEmpty) types.add('url');
    if (screenshotPaths.isNotEmpty) types.add('screenshots');
    if (videoClipPaths.isNotEmpty) types.add('video_clips');
    if (textPrompt != null && textPrompt!.trim().isNotEmpty) types.add('text');

    if (types.isEmpty && selectedApp != null) return 'app';
    if (types.length == 1) return types.first;
    return 'mixed';
  }
}

class StoryboardPlannerService {
  final PlayStoreScraperService _scraper;

  StoryboardPlannerService([PlayStoreScraperService? scraper])
      : _scraper = scraper ?? PlayStoreScraperService();

  /// Plans a complete scene-by-scene storyboard from any combination of inputs.
  /// Preserves the user's original input text as an immutable source.
  Future<VideoProjectModel> planStoryboard(StoryboardPlanInput input) async {
    if (!input.hasAnyInput) {
      throw ArgumentError('At least one input (URL, screenshots, video clips, or text prompt) is required.');
    }

    String appName = 'My App';
    String category = 'Productivity';
    List<String> features = [];
    List<String> usps = [];
    String audience = 'Mobile users';
    String? resolvedAppUrl = input.appUrl;
    List<String> allImages = List<String>.from(input.screenshotPaths);
    List<String> allClips = List<String>.from(input.videoClipPaths);
    final originalText = input.textPrompt?.trim() ?? '';

    // 1. Process App URL if supplied
    if (input.appUrl != null && input.appUrl!.trim().isNotEmpty) {
      try {
        final scraped = await _scraper.scrapeAndExtractApp(urlOrPackage: input.appUrl!.trim());
        appName = scraped.app.name;
        category = scraped.app.category;
        features = scraped.extractedFeatures;
        usps = scraped.extractedUsps;
        audience = scraped.targetAudience;
        resolvedAppUrl = scraped.app.playStoreUrl;

        // Incorporate downloaded listing screenshots if none provided by user
        if (allImages.isEmpty && scraped.localScreenshotPaths.isNotEmpty) {
          allImages.addAll(scraped.localScreenshotPaths);
        }
      } catch (_) {
        final pkg = _scraper.normalizePackageName(input.appUrl!.trim());
        appName = pkg.split('.').lastOrNull ?? 'My App';
      }
    } else if (input.selectedApp != null) {
      final app = input.selectedApp!;
      appName = app.name;
      category = app.category;
      features = app.mainFeatures;
      usps = app.uniqueSellingPoints;
      audience = app.targetAudience ?? 'Mobile users';
      resolvedAppUrl = app.playStoreUrl;
      if (allImages.isEmpty && app.iconPath != null && app.iconPath!.isNotEmpty) {
        allImages.add(app.iconPath!);
      }
    }

    // 2. Process Text Prompt if supplied
    if (originalText.isNotEmpty) {
      final extractedLines = originalText
          .split(RegExp(r'[\r\n]+'))
          .map((s) => s.trim().replaceAll(RegExp(r'^[•\-\*0-9\.\s]+'), ''))
          .where((s) => s.length >= 3)
          .toList();

      if (extractedLines.isNotEmpty) {
        if (appName == 'My App' && extractedLines.first.length <= 40) {
          appName = extractedLines.first;
        }
        for (final line in extractedLines) {
          if (line.length >= 8 && line.length <= 80 && !features.contains(line)) {
            features.add(line);
          }
        }
      }
    }

    // Fallbacks if list is sparse
    if (features.isEmpty) {
      features = [
        'Clean, intuitive mobile user interface',
        'Built for smooth and rapid performance',
        'Customizable settings and preferences',
      ];
    }
    if (usps.isEmpty) {
      usps = [
        'Streamlined daily workflow on Android',
        'Zero distraction and battery efficient',
      ];
    }

    // 3. Formulate scenes according to template type and inputs
    final List<VideoSceneModel> scenes;
    if (input.templateType == 'text_to_video' || (input.detectedSourceType == 'text' && originalText.isNotEmpty)) {
      // Build scenes directly from the user's supplied text, preserving wording
      scenes = _buildTextDrivenScenes(
        rawText: originalText,
        appName: appName,
        category: category,
        images: allImages,
        clips: allClips,
        targetDuration: input.targetDurationSeconds,
        transitionStyle: input.transitionStyle,
      );
    } else {
      scenes = _buildTemplateScenes(
        templateType: input.templateType,
        appName: appName,
        category: category,
        features: features,
        usps: usps,
        audience: audience,
        images: allImages,
        clips: allClips,
        targetDuration: input.targetDurationSeconds,
        transitionStyle: input.transitionStyle,
      );
    }

    final totalDuration = scenes.fold<double>(0.0, (acc, s) => acc + s.durationSeconds);
    final narrationScript = scenes.map((s) => '${s.sceneTitle}: "${s.voiceOverNarration}"').join('\n\n');

    final allMedia = <String>[...allImages, ...allClips];
    final projectId = 'proj_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';
    final now = DateTime.now().toUtc();

    return VideoProjectModel(
      id: projectId,
      appId: input.selectedApp?.id,
      templateType: input.templateType,
      sourceType: input.detectedSourceType,
      title: '$appName - ${_templateTitle(input.templateType)}',
      aspectRatio: input.aspectRatio,
      resolution: input.resolution,
      totalDurationSeconds: totalDuration,
      scenes: scenes,
      audioNarrationScript: narrationScript,
      originalInputText: originalText,
      generatedMarketingScript: narrationScript,
      renderingPhaseStatus: 'storyboardReady',
      inputAppUrl: resolvedAppUrl,
      inputTextPrompt: input.textPrompt,
      inputMediaPaths: allMedia,
      captionStyle: input.captionStyle,
      transitionStyle: input.transitionStyle,
      backgroundMusicPath: input.backgroundMusicPath,
      backgroundMusicVolume: input.backgroundMusicVolume,
      enableVoiceNarration: input.enableVoiceNarration,
      exportStatus: 'draft',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Regenerates an individual scene while keeping the rest of the project intact.
  VideoSceneModel regenerateScene({
    required VideoProjectModel project,
    required int sceneIndex,
  }) {
    if (sceneIndex < 0 || sceneIndex >= project.scenes.length) {
      throw RangeError.index(sceneIndex, project.scenes);
    }

    final old = project.scenes[sceneIndex];
    final isFirst = sceneIndex == 0;
    final isLast = sceneIndex == project.scenes.length - 1;

    if (isFirst) {
      return old.copyWith(
        sceneTitle: 'Stop Struggling With Routine Tasks',
        onScreenText: 'Tired of complicated apps? Meet the modern solution.',
        voiceOverNarration: 'Tired of complicated apps? Meet the modern solution designed for instant clarity.',
        subtitleText: 'Meet the modern solution designed for instant clarity.',
        visualDescription: 'High contrast hook card with bold action headline',
        badgeText: 'Hook',
      );
    } else if (isLast) {
      return old.copyWith(
        sceneTitle: 'Download Free on Google Play',
        onScreenText: 'Get it on Google Play today',
        voiceOverNarration: 'Get started in seconds. Tap the link to install on Google Play today.',
        subtitleText: 'Get it on Google Play today',
        visualDescription: 'Call-to-action screen with store badges',
        badgeText: 'Call to Action',
        callToAction: 'Download on Google Play',
      );
    } else {
      return old.copyWith(
        sceneTitle: 'Smart Automation in Action',
        onScreenText: 'Effortless speed & clarity',
        voiceOverNarration: 'Experience effortless speed and streamlined design crafted for real daily productivity.',
        subtitleText: 'Experience effortless speed and streamlined design.',
        visualDescription: 'Dynamic feature showcase slide',
        badgeText: 'Feature',
      );
    }
  }

  /// Regenerates only the visual description and assets, leaving all text fields intact.
  VideoSceneModel regenerateVisualOnly({
    required VideoProjectModel project,
    required int sceneIndex,
  }) {
    if (sceneIndex < 0 || sceneIndex >= project.scenes.length) {
      throw RangeError.index(sceneIndex, project.scenes);
    }

    final old = project.scenes[sceneIndex];
    final visualOptions = [
      'High-contrast minimalist typography card with modern animated gradient',
      'Dynamic feature showcase slide with glassmorphism container and icons',
      'Clean geometric background with soft ambient lighting and drop shadow cards',
      'Vibrant cybernetic grid background with glowing accent highlights',
      'Isometric device mockup frame highlighting user interface',
      'Abstract gradient blur composition with prominent floating headline badge',
    ];

    final nextDesc = visualOptions[(sceneIndex + DateTime.now().millisecond) % visualOptions.length];
    return old.copyWith(visualDescription: nextDesc);
  }

  /// Regenerates only the narration text, leaving on-screen text, titles, subtitles, and visuals intact.
  VideoSceneModel regenerateNarrationOnly({
    required VideoProjectModel project,
    required int sceneIndex,
  }) {
    if (sceneIndex < 0 || sceneIndex >= project.scenes.length) {
      throw RangeError.index(sceneIndex, project.scenes);
    }

    final old = project.scenes[sceneIndex];
    final isFirst = sceneIndex == 0;
    final isLast = sceneIndex == project.scenes.length - 1;

    final newNarration = isFirst
        ? 'Looking for a cleaner, faster experience? Here is the smart way to get things done.'
        : (isLast
            ? 'Install today to experience the speed firsthand. Available on Google Play.'
            : 'Engineered for smooth responsiveness and zero friction in your daily workflow.');

    return old.copyWith(voiceOverNarration: newNarration);
  }

  /// Regenerates only captions / on-screen text and subtitle, leaving narration and visuals intact.
  VideoSceneModel regenerateCaptionsOnly({
    required VideoProjectModel project,
    required int sceneIndex,
  }) {
    if (sceneIndex < 0 || sceneIndex >= project.scenes.length) {
      throw RangeError.index(sceneIndex, project.scenes);
    }

    final old = project.scenes[sceneIndex];
    final isFirst = sceneIndex == 0;
    final isLast = sceneIndex == project.scenes.length - 1;

    final newCaption = isFirst
        ? 'Effortless & Instant'
        : (isLast
            ? 'Install Free on Google Play'
            : 'Speed That Matters');

    return old.copyWith(
      onScreenText: newCaption,
      subtitleText: newCaption,
    );
  }

  /// Regenerates the entire storyboard after explicit user confirmation.
  Future<VideoProjectModel> regenerateStoryboard({
    required StoryboardPlanInput input,
  }) async {
    return planStoryboard(input);
  }

  /// Builds scenes specifically from user-supplied text while preserving their words.
  List<VideoSceneModel> _buildTextDrivenScenes({
    required String rawText,
    required String appName,
    required String category,
    required List<String> images,
    required List<String> clips,
    required double targetDuration,
    required String transitionStyle,
  }) {
    final scenes = <VideoSceneModel>[];

    // Split user text into sentences or bullet points
    final rawSentences = rawText
        .split(RegExp(r'(?<=[.!?])\s+|\r?\n+'))
        .map((s) => s.trim().replaceAll(RegExp(r'^[•\-\*0-9\.\s]+'), ''))
        .where((s) => s.isNotEmpty)
        .toList();

    final sentences = rawSentences.isNotEmpty
        ? rawSentences
        : [
            'Boost your daily routine with $appName.',
            'Experience smart features and modern simplicity.',
            'Download free today on Google Play.',
          ];

    final sceneCount = sentences.length.clamp(3, 6);
    final perSceneDuration = (targetDuration / sceneCount).clamp(3.0, 6.0);

    String? getImage(int idx) => (images.isNotEmpty && idx < images.length) ? images[idx] : (images.isNotEmpty ? images.first : null);
    String? getClip(int idx) => (clips.isNotEmpty && idx < clips.length) ? clips[idx] : null;

    for (int i = 0; i < sceneCount; i++) {
      final sentence = i < sentences.length ? sentences[i] : sentences.last;
      final isFirst = i == 0;
      final isLast = i == sceneCount - 1;

      final title = isFirst
          ? 'Discover $appName'
          : (isLast ? 'Try It Today' : _extractKeyPhrase(sentence));

      final badge = isFirst
          ? 'Overview'
          : (isLast ? 'Get Started' : 'Feature $i');

      scenes.add(VideoSceneModel(
        id: 'scene_${i + 1}_${const Uuid().v4().substring(0, 8)}',
        sceneNumber: i + 1,
        sceneTitle: title,
        onScreenText: sentence.length > 50 ? _extractKeyPhrase(sentence) : sentence,
        voiceOverNarration: sentence,
        subtitleText: sentence,
        visualDescription: isFirst
            ? 'Bold typography presentation with vibrant app branding'
            : (isLast
                ? 'Conversion call-to-action screen with store badge'
                : 'Clean showcase presentation highlighting core feature'),
        badgeText: badge,
        durationSeconds: perSceneDuration,
        imageAssetPath: getImage(i),
        videoClipPath: getClip(i),
        transition: transitionStyle,
        callToAction: isLast ? 'Download free on Google Play' : null,
      ));
    }

    return scenes;
  }

  String _extractKeyPhrase(String sentence) {
    final cleaned = sentence.replaceAll(RegExp(r'[.!?]+$'), '').trim();
    if (cleaned.length <= 40) return cleaned;
    final parts = cleaned.split(RegExp(r'[,;]'));
    if (parts.isNotEmpty && parts.first.length >= 10 && parts.first.length <= 40) {
      return parts.first.trim();
    }
    final words = cleaned.split(' ');
    if (words.length > 5) {
      return '${words.take(5).join(' ')}...';
    }
    return cleaned;
  }

  List<VideoSceneModel> _buildTemplateScenes({
    required String templateType,
    required String appName,
    required String category,
    required List<String> features,
    required List<String> usps,
    required String audience,
    required List<String> images,
    required List<String> clips,
    required double targetDuration,
    required String transitionStyle,
  }) {
    final scenes = <VideoSceneModel>[];
    final f1 = features.isNotEmpty ? features[0] : 'Intuitive modern controls';
    final f2 = features.length > 1 ? features[1] : 'Fast performance and clean design';
    final usp = usps.isNotEmpty ? usps[0] : 'Built for maximum efficiency';

    String? getImage(int idx) => (images.isNotEmpty && idx < images.length) ? images[idx] : (images.isNotEmpty ? images.first : null);
    String? getClip(int idx) => (clips.isNotEmpty && idx < clips.length) ? clips[idx] : null;

    switch (templateType) {
      case 'problem_solution':
        scenes.add(VideoSceneModel(
          id: 'scene_1_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 1,
          sceneTitle: 'The Daily Problem',
          onScreenText: 'Tired of tedious $category routines?',
          voiceOverNarration: 'Managing $category tasks shouldn’t take hours out of your busy schedule.',
          subtitleText: 'Managing $category tasks shouldn’t take hours out of your busy schedule.',
          visualDescription: 'Problem overview slide with bold text',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          videoClipPath: getClip(0),
          badgeText: 'Problem',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_2_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 2,
          sceneTitle: 'Introducing $appName',
          onScreenText: '$appName changes everything',
          voiceOverNarration: 'That’s why we created $appName: the smart solution built for $audience.',
          subtitleText: 'That’s why we created $appName: the smart solution built for $audience.',
          visualDescription: 'App presentation slide with logo & hero graphic',
          durationSeconds: 3.5,
          imageAssetPath: getImage(1),
          videoClipPath: getClip(1),
          badgeText: 'Solution',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_3_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 3,
          sceneTitle: 'Key Benefit: $f1',
          onScreenText: f1,
          voiceOverNarration: 'With $f1, you get seamless control and immediate results.',
          subtitleText: 'With $f1, you get seamless control and immediate results.',
          visualDescription: 'Core capability slide with authentic app interface',
          durationSeconds: 4.0,
          imageAssetPath: getImage(2),
          videoClipPath: getClip(2),
          badgeText: 'Feature',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_4_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 4,
          sceneTitle: 'Get Started Today',
          onScreenText: 'Download free on Google Play',
          voiceOverNarration: 'Download $appName on Google Play and upgrade your daily routine.',
          subtitleText: 'Download $appName on Google Play and upgrade your daily routine.',
          visualDescription: 'Final CTA banner with store download badges',
          durationSeconds: 3.5,
          imageAssetPath: getImage(3),
          badgeText: 'Call to Action',
          callToAction: 'Download free on Google Play',
          transition: transitionStyle,
        ));
        break;

      case 'quick_tutorial':
        scenes.add(VideoSceneModel(
          id: 'scene_1_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 1,
          sceneTitle: 'Step 1: Open $appName',
          onScreenText: '1. Launch & setup in seconds',
          voiceOverNarration: 'Launch $appName to access all your $category tools in one unified dashboard.',
          subtitleText: 'Launch $appName to access all your $category tools.',
          visualDescription: 'App startup & home view',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          videoClipPath: getClip(0),
          badgeText: 'Step 1',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_2_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 2,
          sceneTitle: 'Step 2: $f1',
          onScreenText: '2. $f1',
          voiceOverNarration: 'Select $f1 to customize and execute tasks effortlessly.',
          subtitleText: 'Select $f1 to customize and execute tasks effortlessly.',
          visualDescription: 'Detailed tutorial action walkthrough',
          durationSeconds: 4.0,
          imageAssetPath: getImage(1),
          videoClipPath: getClip(1),
          badgeText: 'Step 2',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_3_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 3,
          sceneTitle: 'Step 3: $f2',
          onScreenText: '3. $f2',
          voiceOverNarration: 'Enjoy $f2 with instantaneous synchronization and zero hassle.',
          subtitleText: 'Enjoy $f2 with instantaneous synchronization.',
          visualDescription: 'Feature result walkthrough',
          durationSeconds: 4.0,
          imageAssetPath: getImage(2),
          videoClipPath: getClip(2),
          badgeText: 'Step 3',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_4_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 4,
          sceneTitle: 'Try It Yourself',
          onScreenText: 'Available now on Google Play',
          voiceOverNarration: 'Ready to try? Install $appName now on Google Play.',
          subtitleText: 'Ready to try? Install $appName now on Google Play.',
          visualDescription: 'End card with download prompt',
          durationSeconds: 3.5,
          imageAssetPath: getImage(3),
          badgeText: 'Get App',
          callToAction: 'Install now on Google Play',
          transition: transitionStyle,
        ));
        break;

      case 'launch_announcement':
        scenes.add(VideoSceneModel(
          id: 'scene_1_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 1,
          sceneTitle: 'Now Available!',
          onScreenText: '🚀 $appName is now live!',
          voiceOverNarration: 'Big announcement: $appName is officially live and ready for download!',
          subtitleText: 'Big announcement: $appName is officially live!',
          visualDescription: 'Exciting announcement badge and app identity card',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          videoClipPath: getClip(0),
          badgeText: 'Launch',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_2_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 2,
          sceneTitle: 'What Makes It Special',
          onScreenText: usp,
          voiceOverNarration: '$appName delivers $usp directly on your Android phone.',
          subtitleText: '$appName delivers $usp directly on your Android phone.',
          visualDescription: 'Hero feature preview screen',
          durationSeconds: 4.0,
          imageAssetPath: getImage(1),
          videoClipPath: getClip(1),
          badgeText: 'Highlight',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_3_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 3,
          sceneTitle: 'Core Powers: $f1',
          onScreenText: f1,
          voiceOverNarration: 'Experience $f1 and $f2 designed specifically for $audience.',
          subtitleText: 'Experience $f1 and $f2 designed specifically for $audience.',
          visualDescription: 'App UI showcase slide',
          durationSeconds: 4.0,
          imageAssetPath: getImage(2),
          videoClipPath: getClip(2),
          badgeText: 'Features',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_4_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 4,
          sceneTitle: 'Install From Google Play',
          onScreenText: 'Download free today on Google Play',
          voiceOverNarration: 'Be among the first to try it. Get $appName free today.',
          subtitleText: 'Be among the first to try it. Get $appName free today.',
          visualDescription: 'Store CTA with app badge',
          durationSeconds: 3.5,
          imageAssetPath: getImage(3),
          badgeText: 'Install',
          callToAction: 'Download free on Google Play',
          transition: transitionStyle,
        ));
        break;

      case 'existing_video_enhancement':
        scenes.add(VideoSceneModel(
          id: 'scene_1_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 1,
          sceneTitle: 'Spotlight on $appName',
          onScreenText: 'Welcome to $appName',
          voiceOverNarration: 'Watch $appName in real action and see how simple $category can be.',
          subtitleText: 'Watch $appName in real action.',
          visualDescription: 'Video intro with overlay title and branding',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          videoClipPath: getClip(0),
          clipStartTimeSeconds: 0.0,
          clipEndTimeSeconds: 4.0,
          badgeText: 'Intro',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_2_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 2,
          sceneTitle: 'Live Gameplay & Workflow',
          onScreenText: f1,
          voiceOverNarration: '$f1 makes every interaction smooth and responsive.',
          subtitleText: '$f1 makes every interaction smooth and responsive.',
          visualDescription: 'Existing footage highlight reel with smart captions',
          durationSeconds: 5.0,
          imageAssetPath: getImage(1),
          videoClipPath: getClip(1) ?? getClip(0),
          clipStartTimeSeconds: 4.0,
          clipEndTimeSeconds: 9.0,
          badgeText: 'Action',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_3_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 3,
          sceneTitle: 'Experience The Difference',
          onScreenText: 'Download on Google Play',
          voiceOverNarration: 'Available now for download on Android. Tap to install $appName.',
          subtitleText: 'Available now for download on Android.',
          visualDescription: 'Ending overlay with store links',
          durationSeconds: 3.5,
          imageAssetPath: getImage(2),
          videoClipPath: getClip(2),
          badgeText: 'CTA',
          callToAction: 'Download on Google Play',
          transition: transitionStyle,
        ));
        break;

      case 'feature_showcase':
      default:
        scenes.add(VideoSceneModel(
          id: 'scene_1_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 1,
          sceneTitle: 'Welcome to $appName',
          onScreenText: 'Discover $appName',
          voiceOverNarration: 'Meet $appName: the smart and modern way to master $category.',
          subtitleText: 'Meet $appName: the smart and modern way to master $category.',
          visualDescription: 'Opening hero shot with app icon and brand headline',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          videoClipPath: getClip(0),
          badgeText: 'Hook',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_2_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 2,
          sceneTitle: f1,
          onScreenText: f1,
          voiceOverNarration: 'Enjoy $f1 built directly into a clean, easy-to-use interface.',
          subtitleText: 'Enjoy $f1 built directly into a clean, easy-to-use interface.',
          visualDescription: 'Feature demonstration with authentic screenshot',
          durationSeconds: 4.0,
          imageAssetPath: getImage(1),
          videoClipPath: getClip(1),
          badgeText: 'Feature 1',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_3_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 3,
          sceneTitle: f2,
          onScreenText: f2,
          voiceOverNarration: 'Save time every day with $f2 and smooth offline capability.',
          subtitleText: 'Save time every day with $f2 and smooth offline capability.',
          visualDescription: 'Second feature highlight card',
          durationSeconds: 4.0,
          imageAssetPath: getImage(2),
          videoClipPath: getClip(2),
          badgeText: 'Feature 2',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          id: 'scene_4_${const Uuid().v4().substring(0, 8)}',
          sceneNumber: 4,
          sceneTitle: 'Download on Google Play',
          onScreenText: 'Download on Google Play',
          voiceOverNarration: 'Install $appName today on Google Play and get started for free.',
          subtitleText: 'Install $appName today on Google Play and get started for free.',
          visualDescription: 'Call to action card with Google Play download badge',
          durationSeconds: 3.5,
          imageAssetPath: getImage(3),
          badgeText: 'Get App',
          callToAction: 'Download on Google Play',
          transition: transitionStyle,
        ));
        break;
    }

    return scenes;
  }

  String _templateTitle(String type) {
    switch (type) {
      case 'problem_solution':
        return 'Problem & Solution';
      case 'quick_tutorial':
        return 'Quick Tutorial';
      case 'launch_announcement':
        return 'Launch Announcement';
      case 'before_after':
        return 'Before & After';
      case 'installation_guide':
        return 'Installation Guide';
      case 'promotional_slideshow':
        return 'Promotional Slideshow';
      case 'existing_video_enhancement':
        return 'Video Enhancement';
      case 'text_to_video':
        return 'Text-to-Video Promo';
      case 'feature_showcase':
      default:
        return 'Feature Showcase';
    }
  }
}
