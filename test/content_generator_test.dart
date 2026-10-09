import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/features/apps/models/app_model.dart';
import 'package:appgrowth_studio/features/campaigns/models/campaign_model.dart';
import 'package:appgrowth_studio/features/content_studio/domain/content_generation_provider.dart';
import 'package:appgrowth_studio/features/content_studio/domain/template_content_provider.dart';
import 'package:appgrowth_studio/features/content_studio/models/content_post_model.dart';

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('Content Studio & Template Generator Tests', () {
    late AppModel testApp;
    late CampaignModel testCampaign;

    setUp(() {
      final now = DateTime.now().toUtc();
      testApp = AppModel(
        id: 'app-content-1',
        name: 'FocusFlow Habits',
        packageName: 'com.studio.focusflow',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.studio.focusflow',
        category: 'Productivity',
        shortDescription: 'Master your daily streak',
        fullDescription: 'Comprehensive habit tracker designed for remote developers.',
        mainFeatures: ['Streak Counter', 'Offline Sync', 'Smart Widgets'],
        uniqueSellingPoints: ['Zero ads and 100% private'],
        targetAudience: 'Software engineers and remote workers',
        brandTone: 'Direct & Value-Focused',
        preferredCta: 'Install free on Google Play',
        createdAt: now,
        updatedAt: now,
      );

      testCampaign = CampaignModel(
        id: 'camp-content-1',
        appId: 'app-content-1',
        name: 'Launch Blitz',
        objective: 'New App Launch',
        createdAt: now,
        updatedAt: now,
      );
    });

    test('TemplateContentProvider generates platform-specific YouTube content', () async {
      final generator = TemplateContentProvider();
      final result = await generator.generateContent(
        ContentGenerationRequest(
          app: testApp,
          campaign: testCampaign,
          targetPlatform: 'YouTube',
          contentFormat: 'video_script',
          topicOrTheme: 'Streak Building Routine',
        ),
      );

      expect(result.title.contains('FocusFlow Habits'), isTrue);
      expect(result.scriptHook.contains('FocusFlow Habits'), isTrue);
      expect(result.bodyText.contains('TIMESTAMPS'), isTrue);
      expect(result.bodyText.contains('Streak Counter'), isTrue);
      expect(result.bodyText.contains('Zero ads and 100% private'), isTrue);
      expect(Uri.decodeFull(result.ctaLink).contains('utm_source=youtube'), isTrue);
      expect(result.hashtags.contains('#FocusFlowHabits'), isTrue);
    });

    test('TemplateContentProvider generates TikTok short video storyboard', () async {
      final generator = TemplateContentProvider();
      final result = await generator.generateContent(
        ContentGenerationRequest(
          app: testApp,
          campaign: testCampaign,
          targetPlatform: 'TikTok',
          contentFormat: 'short_video',
          topicOrTheme: 'Productivity Hacks',
        ),
      );

      expect(result.bodyText.contains('SCENE-BY-SCENE SHORT VIDEO STORYBOARD'), isTrue);
      expect(result.bodyText.contains('Scroll Stopper'), isTrue);
      expect(Uri.decodeFull(result.ctaLink).contains('utm_source=tiktok'), isTrue);
    });

    test('TemplateContentProvider generates Instagram Reel and Carousel copy', () async {
      final generator = TemplateContentProvider();
      final reelResult = await generator.generateContent(
        ContentGenerationRequest(
          app: testApp,
          campaign: testCampaign,
          targetPlatform: 'Instagram',
          contentFormat: 'reel',
        ),
      );
      expect(reelResult.bodyText.contains('INSTAGRAM REEL SCRIPT'), isTrue);

      final carouselResult = await generator.generateContent(
        ContentGenerationRequest(
          app: testApp,
          campaign: testCampaign,
          targetPlatform: 'Instagram',
          contentFormat: 'carousel',
        ),
      );
      expect(carouselResult.bodyText.contains('CAROUSEL POST COPY'), isTrue);
    });

    test('ContentPost SQLite insert and query test', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onCreate: DatabaseMigrations.onCreate,
        ),
      );

      // Insert parent app
      await db.insert('apps', testApp.toMap());

      final post = ContentPostModel(
        id: 'post-1',
        appId: testApp.id,
        campaignId: testCampaign.id,
        targetPlatform: 'YouTube',
        title: 'Launch Demo',
        bodyText: 'Sample full video script...',
        hashtags: '#habits #android',
        scriptHook: 'Wait until you see this...',
        ctaLink: 'https://play.google.com/store/apps/details?id=com.studio.focusflow',
        format: 'video_script',
        status: 'draft',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await db.insert('content_posts', post.toMap());

      final res = await db.query('content_posts', where: 'id = ?', whereArgs: ['post-1']);
      expect(res.length, 1);
      final retrieved = ContentPostModel.fromMap(res.first);
      expect(retrieved.title, 'Launch Demo');
      expect(retrieved.targetPlatform, 'YouTube');

      await db.close();
    });
  });
}
