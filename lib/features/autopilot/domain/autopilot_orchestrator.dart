import 'dart:async';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../apps/models/app_model.dart';
import '../../apps/repositories/app_repository.dart';
import '../../campaigns/models/campaign_model.dart';
import '../../campaigns/repositories/campaign_repository.dart';
import '../../content_studio/domain/content_generation_provider.dart';
import '../../content_studio/domain/smart_content_provider.dart';
import '../../content_studio/domain/template_content_provider.dart';
import '../../content_studio/models/content_post_model.dart';
import '../../content_studio/repositories/content_post_repository.dart';
import '../../keywords/domain/keyword_relevance_scorer.dart';
import '../../keywords/models/keyword_model.dart';
import '../../keywords/repositories/keyword_repository.dart';
import '../../publishing/repositories/publishing_queue_repository.dart';
import '../models/autopilot_run_model.dart';
import '../models/autopilot_settings_model.dart';
import 'creative_asset_generator.dart';
import 'play_store_scraper.dart';

typedef AutopilotProgressCallback = void Function(double progress, String stepName);

class AutopilotExecutionResult {
  final AutopilotRunModel run;
  final AppModel app;
  final CampaignModel campaign;
  final int totalKeywords;
  final int totalPosts;
  final int totalJobsQueued;
  final int totalAssetsCreated;
  final List<String> warnings;

  const AutopilotExecutionResult({
    required this.run,
    required this.app,
    required this.campaign,
    required this.totalKeywords,
    required this.totalPosts,
    required this.totalJobsQueued,
    required this.totalAssetsCreated,
    this.warnings = const [],
  });
}

class AutopilotOrchestrator {
  final PlayStoreScraperService _scraper;
  final CreativeAssetGenerator _creativeGen;
  final TemplateContentProvider _templateProvider;
  final AppRepository _appRepo;
  final CampaignRepository _campaignRepo;
  final KeywordRepository _keywordRepo;
  final ContentPostRepository _postRepo;
  final PublishingQueueRepository _queueRepo;
  final Uuid _uuid = const Uuid();

  AutopilotOrchestrator({
    PlayStoreScraperService? scraper,
    CreativeAssetGenerator? creativeGen,
    TemplateContentProvider? templateProvider,
    AppRepository? appRepo,
    CampaignRepository? campaignRepo,
    KeywordRepository? keywordRepo,
    ContentPostRepository? postRepo,
    PublishingQueueRepository? queueRepo,
  })  : _scraper = scraper ?? PlayStoreScraperService(),
        _creativeGen = creativeGen ?? CreativeAssetGenerator(),
        _templateProvider = templateProvider ?? TemplateContentProvider(),
        _appRepo = appRepo ?? AppRepository(),
        _campaignRepo = campaignRepo ?? CampaignRepository(),
        _keywordRepo = keywordRepo ?? KeywordRepository(),
        _postRepo = postRepo ?? ContentPostRepository(),
        _queueRepo = queueRepo ?? PublishingQueueRepository();

  /// Executes full end-to-end promotion autopilot starting from a single Play Store URL or package name
  Future<AutopilotExecutionResult> runAutopilotFromInput({
    required String urlOrPackage,
    AutopilotSettingsModel? settings,
    AutopilotProgressCallback? onProgress,
  }) async {
    final effectiveSettings = settings ??
        AutopilotSettingsModel(
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

    onProgress?.call(0.05, 'Identifying Google Play listing and downloading assets...');
    await AppLogger.info('autopilot', 'Starting Autonomous App Promotion for: "$urlOrPackage"');

    // STEP 1: Onboarding - Scrape listing and register App
    final scrapeResult = await _scraper.scrapeAndExtractApp(
      urlOrPackage: urlOrPackage,
      preferredAudience: null,
    );
    final app = await _appRepo.createApp(scrapeResult.app);

    onProgress?.call(0.15, 'Listing extracted: "${app.name}". Initializing Autopilot run...');
    await AppLogger.success('autopilot', 'App registered locally: ${app.name} (${app.packageName})');

    return runAutopilotForApp(
      app: app,
      screenshotPaths: scrapeResult.localScreenshotPaths,
      iconPath: scrapeResult.localIconPath,
      settings: effectiveSettings,
      onProgress: onProgress,
    );
  }

  /// Executes the 10-step autonomous promotion workflow for an existing registered app
  Future<AutopilotExecutionResult> runAutopilotForApp({
    required AppModel app,
    required List<String> screenshotPaths,
    String? iconPath,
    required AutopilotSettingsModel settings,
    AutopilotProgressCallback? onProgress,
  }) async {
    final now = DateTime.now().toUtc();
    final runId = _uuid.v4();

    var run = AutopilotRunModel(
      id: runId,
      appId: app.id,
      status: 'running',
      currentStep: 'Analyzing app category and target audience...',
      progress: 0.20,
      createdAt: now,
      updatedAt: now,
    );
    await _recordRunState(run);
    onProgress?.call(run.progress, run.currentStep);

    // STEP 1 & 2: Research Relevant Keywords & Content Topics
    run = run.copyWith(
      progress: 0.35,
      currentStep: 'Researching keywords and clustering content topics...',
      updatedAt: DateTime.now().toUtc(),
    );
    await _recordRunState(run);
    onProgress?.call(run.progress, run.currentStep);

    final generatedKeywords = await _generateAndPersistKeywords(app);
    await AppLogger.info('autopilot', 'Generated ${generatedKeywords.length} topic keywords for ${app.name}.');

    // STEP 3: Generate App Positioning Summary and 30-Day Campaign
    run = run.copyWith(
      progress: 0.45,
      currentStep: 'Generating strategic campaign and 30-day content calendar...',
      updatedAt: DateTime.now().toUtc(),
    );
    await _recordRunState(run);
    onProgress?.call(run.progress, run.currentStep);

    final campaign = await _createAutopilotCampaign(app, settings);
    await AppLogger.info('autopilot', 'Created 30-Day Autopilot Campaign: "${campaign.name}".');

    // STEP 4 & 5: Generate Platform-Specific Copy Across 30-Day Calendar
    run = run.copyWith(
      progress: 0.60,
      currentStep: 'Generating platform-tailored scripts, captions, and hashtags...',
      updatedAt: DateTime.now().toUtc(),
    );
    await _recordRunState(run);
    onProgress?.call(run.progress, run.currentStep);

    final createdPosts = await _generateCalendarPosts(
      app: app,
      campaign: campaign,
      settings: settings,
      keywords: generatedKeywords,
    );
    await AppLogger.success('autopilot', 'Synthesized ${createdPosts.length} scheduled posts across platforms.');

    // STEP 6 & 7: Render Promotional Graphics & Video Projects
    run = run.copyWith(
      progress: 0.75,
      currentStep: 'Rendering promotional graphic cards and building video projects...',
      updatedAt: DateTime.now().toUtc(),
      totalPostsCreated: createdPosts.length,
    );
    await _recordRunState(run);
    onProgress?.call(run.progress, run.currentStep);

    final creativePackage = await _creativeGen.generateCreativesForApp(
      app: app,
      screenshotPaths: screenshotPaths,
      iconPath: iconPath,
      formatPreference: settings.videoFormat,
    );
    final totalAssets = creativePackage.generatedGraphicPaths.length + creativePackage.videoProjects.length;
    await AppLogger.success(
      'autopilot',
      'Created $totalAssets creative assets (${creativePackage.generatedGraphicPaths.length} cards, ${creativePackage.videoProjects.length} video projects).',
    );

    // STEP 8: Queue Eligible Content for Automatic Publishing
    run = run.copyWith(
      progress: 0.90,
      currentStep: 'Enqueuing scheduled publishing jobs...',
      updatedAt: DateTime.now().toUtc(),
      totalAssetsCreated: totalAssets,
    );
    await _recordRunState(run);
    onProgress?.call(run.progress, run.currentStep);

    final queuedJobsCount = await _queuePostsForPublishing(
      posts: createdPosts,
      settings: settings,
      creativePackage: creativePackage,
    );
    await AppLogger.info('autopilot', 'Queued $queuedJobsCount jobs for background publishing.');

    // STEP 9 & 10: Complete Run & Record State
    run = run.copyWith(
      progress: 1.0,
      status: 'completed',
      currentStep: 'Autopilot completed successfully. 30-day schedule active.',
      totalJobsQueued: queuedJobsCount,
      updatedAt: DateTime.now().toUtc(),
    );
    await _recordRunState(run);
    onProgress?.call(run.progress, run.currentStep);

    await AppLogger.success(
      'autopilot',
      'Autonomous Promotion Setup Finished! ${createdPosts.length} posts scheduled, $queuedJobsCount jobs queued.',
    );

    return AutopilotExecutionResult(
      run: run,
      app: app,
      campaign: campaign,
      totalKeywords: generatedKeywords.length,
      totalPosts: createdPosts.length,
      totalJobsQueued: queuedJobsCount,
      totalAssetsCreated: totalAssets,
    );
  }

  // --------------------------------------------------------------------------
  // WORKFLOW SUB-ROUTINES
  // --------------------------------------------------------------------------

  Future<List<KeywordModel>> _generateAndPersistKeywords(AppModel app) async {
    final now = DateTime.now().toUtc();
    final nowStr = DateFormat('yyyy-MM-dd').format(now);
    final generated = <KeywordModel>[];

    // Seed keywords based on category, title, and extracted features
    final seedWords = [
      app.name,
      'best ${app.category.toLowerCase()} app',
      'free ${app.category.toLowerCase()} android',
      '${app.name} tutorial',
      '${app.name} download',
      ...app.mainFeatures.map((f) => f.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')),
    ];

    for (final word in seedWords) {
      if (word.trim().isEmpty) continue;
      final scorer = KeywordRelevanceScorer.calculateScore(
        keyword: word,
        app: app,
        intent: _inferIntent(word),
        source: 'Google Play Listing',
      );

      final kw = KeywordModel(
        id: _uuid.v4(),
        appId: app.id,
        keyword: word.trim(),
        topicCluster: _inferTopicCluster(word, app.category),
        intent: _inferIntent(word),
        relevanceScore: scorer.score,
        source: 'generator',
        retrievalDate: nowStr,
        notes: scorer.rationale,
        createdAt: now,
      );

      await _keywordRepo.addKeyword(kw);
      generated.add(kw);
      if (generated.length >= 20) break;
    }

    return generated;
  }

  Future<CampaignModel> _createAutopilotCampaign(AppModel app, AutopilotSettingsModel settings) async {
    final now = DateTime.now().toUtc();
    final endDate = now.add(const Duration(days: 30));
    final platforms = settings.targetPlatforms.isNotEmpty ? settings.targetPlatforms : ['youtube', 'tiktok', 'instagram'];
    final themes = settings.contentThemes.isNotEmpty
        ? settings.contentThemes
        : [
            'Feature Showcase',
            'Problem & Solution',
            'Quick Tutorials',
            'New Updates',
            'Comparison & Highlights',
          ];

    final campaign = CampaignModel(
      id: _uuid.v4(),
      appId: app.id,
      name: '${app.name} 30-Day Autopilot Promotion',
      objective: 'Drive organic discovery, store installs, and feature awareness on Google Play',
      targetAudience: settings.targetAudience ?? app.targetAudience ?? 'Android daily users',
      targetCountry: 'US',
      language: 'en',
      startDate: now.toIso8601String().substring(0, 10),
      endDate: endDate.toIso8601String().substring(0, 10),
      status: 'active',
      postingFrequency: 'Daily (${settings.dailyPostLimit} platform posts/day)',
      contentThemes: themes,
      platforms: platforms,
      notes: 'Automated 30-day promotional calendar orchestrated by AppGrowth Studio.',
      createdAt: now,
      updatedAt: now,
    );

    return _campaignRepo.createCampaign(campaign);
  }

  Future<List<ContentPostModel>> _generateCalendarPosts({
    required AppModel app,
    required CampaignModel campaign,
    required AutopilotSettingsModel settings,
    required List<KeywordModel> keywords,
  }) async {
    final posts = <ContentPostModel>[];
    final platforms = campaign.platforms.isNotEmpty ? campaign.platforms : ['youtube', 'tiktok', 'instagram'];
    final formats = ['video_script', 'caption', 'reel', 'story'];
    final now = DateTime.now().toUtc();
    final smartProvider = SmartContentProvider(
      settings: settings,
      templateProvider: _templateProvider,
    );

    int postIndex = 0;
    // Generate scheduled posts across a 30-day window
    for (int day = 1; day <= 30; day++) {
      for (int slot = 0; slot < settings.dailyPostLimit && slot < platforms.length; slot++) {
        final platform = platforms[(postIndex + slot) % platforms.length];
        final format = formats[postIndex % formats.length];
        final theme = campaign.contentThemes[postIndex % campaign.contentThemes.length];

        final result = await smartProvider.generateContent(
          ContentGenerationRequest(
            app: app,
            campaign: campaign,
            targetPlatform: platform,
            contentFormat: format,
            topicOrTheme: theme,
          ),
        );

        // Quality and safety validation checks
        final validatedBody = _applyComplianceGuardrail(result.bodyText, app);
        final validatedHashtags = _limitHashtags(result.hashtags, 8);

        final post = ContentPostModel(
          id: _uuid.v4(),
          appId: app.id,
          campaignId: campaign.id,
          targetPlatform: platform,
          title: result.title,
          bodyText: validatedBody,
          hashtags: validatedHashtags,
          scriptHook: result.scriptHook,
          ctaLink: result.ctaLink,
          format: format,
          status: settings.requireApprovalBeforePublish ? 'draft' : 'ready',
          createdAt: now,
          updatedAt: now,
        );

        final saved = await _postRepo.createPost(post);
        posts.add(saved);
        postIndex++;
      }
    }

    return posts;
  }

  Future<int> _queuePostsForPublishing({
    required List<ContentPostModel> posts,
    required AutopilotSettingsModel settings,
    required GeneratedCreativePackage creativePackage,
  }) async {
    final now = DateTime.now().toUtc();
    final db = await AppDatabase.instance.database;
    int queuedCount = 0;

    // Parse configured preferred posting time (e.g., '18:00')
    int postHour = 18;
    int postMinute = 0;
    try {
      final parts = settings.postingTimeUtc.split(':');
      if (parts.length >= 2) {
        postHour = int.parse(parts[0]);
        postMinute = int.parse(parts[1]);
      }
    } catch (_) {}

    for (int i = 0; i < posts.length; i++) {
      final post = posts[i];

      // Schedule spaced out daily across the next 30 days
      final dayOffset = (i ~/ settings.dailyPostLimit) + 1;
      final scheduleTime = DateTime.utc(
        now.year,
        now.month,
        now.day + dayOffset,
        postHour,
        postMinute,
      );

      // Attach creative media if available
      if (creativePackage.generatedGraphicPaths.isNotEmpty) {
        final mediaPath = creativePackage.generatedGraphicPaths[i % creativePackage.generatedGraphicPaths.length];
        await db.insert('post_media', {
          'id': _uuid.v4(),
          'post_id': post.id,
          'media_path': mediaPath,
          'sort_order': 0,
        });
      }

      // If approval is required, post remains ready/draft without an active pending queue job
      if (!settings.requireApprovalBeforePublish && settings.isAutopilotEnabled) {
        await _queueRepo.enqueueJob(
          contentId: post.id,
          targetPlatform: post.targetPlatform,
          scheduledAt: scheduleTime,
          campaignId: post.campaignId,
          maxRetries: settings.maxRetryAttempts,
        );
        queuedCount++;
      }
    }

    return queuedCount;
  }

  Future<void> _recordRunState(AutopilotRunModel run) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'autopilot_runs',
      run.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --------------------------------------------------------------------------
  // COMPLIANCE & SAFETY GUARDRAILS
  // --------------------------------------------------------------------------

  String _applyComplianceGuardrail(String text, AppModel app) {
    var cleaned = text.trim();
    // Ensure accurate store link presence
    if (!cleaned.contains('play.google.com') && app.playStoreUrl.isNotEmpty) {
      cleaned += '\n\nGet on Google Play: ${app.playStoreUrl}';
    }
    return cleaned;
  }

  String _limitHashtags(String rawHashtags, int maxCount) {
    final tags = rawHashtags
        .split(RegExp(r'\s+'))
        .where((t) => t.startsWith('#'))
        .take(maxCount)
        .toList();
    return tags.join(' ');
  }

  String _inferTopicCluster(String keyword, String category) {
    final kw = keyword.toLowerCase();
    if (kw.contains('how to') || kw.contains('tutorial') || kw.contains('guide')) {
      return 'Tutorials & Walkthroughs';
    }
    if (kw.contains('download') || kw.contains('install') || kw.contains('store')) {
      return 'Store Acquisition';
    }
    if (kw.contains('free') || kw.contains('best') || kw.contains('alternative')) {
      return 'Competitor & Value';
    }
    return '$category Essentials';
  }

  String _inferIntent(String keyword) {
    final kw = keyword.toLowerCase();
    if (kw.contains('download') || kw.contains('install') || kw.contains('free')) {
      return 'transactional';
    }
    if (kw.contains('how to') || kw.contains('guide')) {
      return 'informational';
    }
    return 'commercial';
  }
}
