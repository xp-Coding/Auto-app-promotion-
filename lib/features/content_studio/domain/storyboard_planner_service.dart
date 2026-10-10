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
        // Fallback to URL package extraction
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
    if (input.textPrompt != null && input.textPrompt!.trim().isNotEmpty) {
      final prompt = input.textPrompt!.trim();
      final extractedLines = prompt
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

    // 3. Formulate scenes according to template type
    final scenes = _buildTemplateScenes(
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

    final totalDuration = scenes.fold<double>(0.0, (acc, s) => acc + s.durationSeconds);
    final narrationScript = scenes.map((s) => '${s.title}: "${s.narrationText}"').join('\n\n');

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
        title: 'Stop Struggling With Routine Tasks',
        narrationText: 'Tired of complicated apps? Meet the modern solution designed for instant clarity.',
        visualDescription: 'High contrast hook card with bold action headline',
        badgeText: 'Hook',
        captionText: 'Meet ${project.title.split(' - ').firstOrNull ?? 'the app'}',
      );
    } else if (isLast) {
      return old.copyWith(
        title: 'Download Free on Google Play',
        narrationText: 'Get started in seconds. Tap the link to install on Google Play today.',
        visualDescription: 'Call-to-action screen with store badges',
        badgeText: 'Call to Action',
        captionText: 'Get it on Google Play today',
      );
    } else {
      return old.copyWith(
        title: 'Smart Automation in Action',
        narrationText: 'Experience effortless speed and streamlined design crafted for real daily productivity.',
        visualDescription: 'Dynamic feature showcase slide',
        badgeText: 'Feature',
        captionText: 'Effortless speed & clarity',
      );
    }
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
          sceneNumber: 1,
          title: 'The Daily Problem',
          narrationText: 'Managing $category tasks shouldn’t take hours out of your busy schedule.',
          visualDescription: 'Problem overview slide with bold text',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          videoClipPath: getClip(0),
          badgeText: 'Problem',
          captionText: 'Tired of tedious $category routines?',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 2,
          title: 'Introducing $appName',
          narrationText: 'That’s why we created $appName: the smart solution built for $audience.',
          visualDescription: 'App presentation slide with logo & hero graphic',
          durationSeconds: 3.5,
          imageAssetPath: getImage(1),
          videoClipPath: getClip(1),
          badgeText: 'Solution',
          captionText: '$appName changes everything',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 3,
          title: 'Key Benefit: $f1',
          narrationText: 'With $f1, you get seamless control and immediate results.',
          visualDescription: 'Core capability slide with authentic app interface',
          durationSeconds: 4.0,
          imageAssetPath: getImage(2),
          videoClipPath: getClip(2),
          badgeText: 'Feature',
          captionText: f1,
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 4,
          title: 'Get Started Today',
          narrationText: 'Download $appName on Google Play and upgrade your daily routine.',
          visualDescription: 'Final CTA banner with store download badges',
          durationSeconds: 3.5,
          imageAssetPath: getImage(3),
          badgeText: 'Call to Action',
          captionText: 'Download free on Google Play',
          transition: transitionStyle,
        ));
        break;

      case 'quick_tutorial':
        scenes.add(VideoSceneModel(
          sceneNumber: 1,
          title: 'Step 1: Open $appName',
          narrationText: 'Launch $appName to access all your $category tools in one unified dashboard.',
          visualDescription: 'App startup & home view',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          videoClipPath: getClip(0),
          badgeText: 'Step 1',
          captionText: '1. Launch & setup in seconds',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 2,
          title: 'Step 2: $f1',
          narrationText: 'Select $f1 to customize and execute tasks effortlessly.',
          visualDescription: 'Detailed tutorial action walkthrough',
          durationSeconds: 4.0,
          imageAssetPath: getImage(1),
          videoClipPath: getClip(1),
          badgeText: 'Step 2',
          captionText: '2. $f1',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 3,
          title: 'Step 3: $f2',
          narrationText: 'Enjoy $f2 with instantaneous synchronization and zero hassle.',
          visualDescription: 'Feature result walkthrough',
          durationSeconds: 4.0,
          imageAssetPath: getImage(2),
          videoClipPath: getClip(2),
          badgeText: 'Step 3',
          captionText: '3. $f2',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 4,
          title: 'Try It Yourself',
          narrationText: 'Ready to try? Install $appName now on Google Play.',
          visualDescription: 'End card with download prompt',
          durationSeconds: 3.5,
          imageAssetPath: getImage(3),
          badgeText: 'Get App',
          captionText: 'Available now on Google Play',
          transition: transitionStyle,
        ));
        break;

      case 'launch_announcement':
        scenes.add(VideoSceneModel(
          sceneNumber: 1,
          title: 'Now Available!',
          narrationText: 'Big announcement: $appName is officially live and ready for download!',
          visualDescription: 'Exciting announcement badge and app identity card',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          videoClipPath: getClip(0),
          badgeText: 'Launch',
          captionText: '🚀 $appName is now live!',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 2,
          title: 'What Makes It Special',
          narrationText: '$appName delivers $usp directly on your Android phone.',
          visualDescription: 'Hero feature preview screen',
          durationSeconds: 4.0,
          imageAssetPath: getImage(1),
          videoClipPath: getClip(1),
          badgeText: 'Highlight',
          captionText: usp,
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 3,
          title: 'Core Powers: $f1',
          narrationText: 'Experience $f1 and $f2 designed specifically for $audience.',
          visualDescription: 'App UI showcase slide',
          durationSeconds: 4.0,
          imageAssetPath: getImage(2),
          videoClipPath: getClip(2),
          badgeText: 'Features',
          captionText: f1,
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 4,
          title: 'Install From Google Play',
          narrationText: 'Be among the first to try it. Get $appName free today.',
          visualDescription: 'Store CTA with app badge',
          durationSeconds: 3.5,
          imageAssetPath: getImage(3),
          badgeText: 'Install',
          captionText: 'Download free today on Google Play',
          transition: transitionStyle,
        ));
        break;

      case 'existing_video_enhancement':
        // When user has imported existing video footage
        scenes.add(VideoSceneModel(
          sceneNumber: 1,
          title: 'Spotlight on $appName',
          narrationText: 'Watch $appName in real action and see how simple $category can be.',
          visualDescription: 'Video intro with overlay title and branding',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          videoClipPath: getClip(0),
          clipStartTimeSeconds: 0.0,
          clipEndTimeSeconds: 4.0,
          badgeText: 'Intro',
          captionText: 'Welcome to $appName',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 2,
          title: 'Live Gameplay & Workflow',
          narrationText: '$f1 makes every interaction smooth and responsive.',
          visualDescription: 'Existing footage highlight reel with smart captions',
          durationSeconds: 5.0,
          imageAssetPath: getImage(1),
          videoClipPath: getClip(1) ?? getClip(0),
          clipStartTimeSeconds: 4.0,
          clipEndTimeSeconds: 9.0,
          badgeText: 'Action',
          captionText: f1,
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 3,
          title: 'Experience The Difference',
          narrationText: 'Available now for download on Android. Tap to install $appName.',
          visualDescription: 'Ending overlay with store links',
          durationSeconds: 3.5,
          imageAssetPath: getImage(2),
          videoClipPath: getClip(2),
          badgeText: 'CTA',
          captionText: 'Download on Google Play',
          transition: transitionStyle,
        ));
        break;

      case 'text_to_video':
        scenes.add(VideoSceneModel(
          sceneNumber: 1,
          title: 'Discover $appName',
          narrationText: 'Looking for a better way to handle $category? Here is $appName.',
          visualDescription: 'Bold typography title presentation card',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          badgeText: 'Overview',
          captionText: 'Discover $appName',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 2,
          title: f1,
          narrationText: 'Designed for $audience, $appName offers $f1 for maximum productivity.',
          visualDescription: 'Feature breakdown card with clear icons & captions',
          durationSeconds: 4.0,
          imageAssetPath: getImage(1),
          badgeText: 'Feature 1',
          captionText: f1,
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 3,
          title: f2,
          narrationText: 'Plus $f2, ensuring a dependable and fluid user experience.',
          visualDescription: 'Benefit bullet presentation card',
          durationSeconds: 4.0,
          imageAssetPath: getImage(2),
          badgeText: 'Feature 2',
          captionText: f2,
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 4,
          title: 'Try It Today',
          narrationText: 'Download $appName free today on Google Play and transform your day.',
          visualDescription: 'Final conversion screen with download call to action',
          durationSeconds: 3.5,
          imageAssetPath: getImage(3),
          badgeText: 'Get Started',
          captionText: 'Download free on Google Play',
          transition: transitionStyle,
        ));
        break;

      case 'feature_showcase':
      default:
        scenes.add(VideoSceneModel(
          sceneNumber: 1,
          title: 'Welcome to $appName',
          narrationText: 'Meet $appName: the smart and modern way to master $category.',
          visualDescription: 'Opening hero shot with app icon and brand headline',
          durationSeconds: 3.5,
          imageAssetPath: getImage(0),
          videoClipPath: getClip(0),
          badgeText: 'Hook',
          captionText: 'Discover $appName',
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 2,
          title: f1,
          narrationText: 'Enjoy $f1 built directly into a clean, easy-to-use interface.',
          visualDescription: 'Feature demonstration with authentic screenshot',
          durationSeconds: 4.0,
          imageAssetPath: getImage(1),
          videoClipPath: getClip(1),
          badgeText: 'Feature 1',
          captionText: f1,
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 3,
          title: f2,
          narrationText: 'Save time every day with $f2 and smooth offline capability.',
          visualDescription: 'Second feature highlight card',
          durationSeconds: 4.0,
          imageAssetPath: getImage(2),
          videoClipPath: getClip(2),
          badgeText: 'Feature 2',
          captionText: f2,
          transition: transitionStyle,
        ));
        scenes.add(VideoSceneModel(
          sceneNumber: 4,
          title: 'Download on Google Play',
          narrationText: 'Install $appName today on Google Play and get started for free.',
          visualDescription: 'Call to action card with Google Play download badge',
          durationSeconds: 3.5,
          imageAssetPath: getImage(3),
          badgeText: 'Get App',
          captionText: 'Download on Google Play',
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
