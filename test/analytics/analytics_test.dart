import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/features/analytics/models/metric_snapshot_model.dart';
import 'package:appgrowth_studio/features/analytics/repositories/analytics_repository.dart';
import 'package:appgrowth_studio/features/apps/models/app_model.dart';
import 'package:appgrowth_studio/features/publishing/adapters/youtube/youtube_quota_tracker.dart';
import 'package:appgrowth_studio/features/publishing/adapters/youtube/youtube_token_storage.dart';

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('Analytics & Campaign Reports Integration Tests', () {
    late Database db;
    late AnalyticsRepository analyticsRepo;
    late YouTubeTokenStorage tokenStorage;
    late YouTubeQuotaTracker quotaTracker;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onCreate: DatabaseMigrations.onCreate,
        ),
      );

      analyticsRepo = AnalyticsRepository(db: db);
      tokenStorage = YouTubeTokenStorage(db);
      quotaTracker = YouTubeQuotaTracker(db);

      // Seed app
      await db.insert('apps', {
        'id': 'app_analytics_1',
        'name': 'FitPulse Tracker',
        'package_name': 'com.fitpulse.app',
        'play_store_url': 'https://play.google.com/store/apps/details?id=com.fitpulse.app',
        'category': 'Health & Fitness',
        'is_archived': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Seed content post & published post
      await db.insert('content_posts', {
        'id': 'post_analytics_1',
        'app_id': 'app_analytics_1',
        'target_platform': 'youtube',
        'title': 'Top 5 Workout Habits',
        'body_text': 'Build momentum with daily tracking.',
        'format': 'video_script',
        'status': 'published',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await db.insert('published_posts', {
        'id': 'pub_analytics_1',
        'post_id': 'post_analytics_1',
        'platform': 'youtube',
        'remote_id': 'yt_vid_fitpulse_001',
        'remote_url': 'https://youtube.com/watch?v=yt_vid_fitpulse_001',
        'published_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'active',
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Metric snapshots distinguish measured metrics from estimates', () async {
      final measuredSnapshot = MetricSnapshotModel(
        id: 'ms_1',
        appId: 'app_analytics_1',
        platform: 'youtube',
        metricName: 'views',
        metricValue: 2450.0,
        metricType: 'views',
        measuredAt: DateTime.now().toUtc(),
        isEstimated: false,
      );

      final estimatedSnapshot = MetricSnapshotModel(
        id: 'ms_2',
        appId: 'app_analytics_1',
        platform: 'youtube',
        metricName: 'installs',
        metricValue: 196.0,
        metricType: 'installs',
        measuredAt: DateTime.now().toUtc(),
        isEstimated: true,
      );

      await analyticsRepo.recordSnapshot(measuredSnapshot);
      await analyticsRepo.recordSnapshot(estimatedSnapshot);

      final retrieved = await analyticsRepo.getSnapshots(appId: 'app_analytics_1');
      expect(retrieved.length, equals(2));

      final views = retrieved.firstWhere((s) => s.metricName == 'views');
      final installs = retrieved.firstWhere((s) => s.metricName == 'installs');

      expect(views.isMeasured, isTrue);
      expect(views.isEstimated, isFalse);

      expect(installs.isMeasured, isFalse);
      expect(installs.isEstimated, isTrue);
    });

    test('syncYouTubeMetrics fetches official stats and records measured snapshots', () async {
      await tokenStorage.saveCredentials(
        const YouTubeCredentials(
          clientId: 'mock_client',
          clientSecret: 'mock_secret',
          accessToken: 'mock_access_token',
        ),
      );

      final mockClient = MockClient((request) async {
        if (request.url.queryParameters['id'] == 'yt_vid_fitpulse_001') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'yt_vid_fitpulse_001',
                  'statistics': {
                    'viewCount': '1420',
                    'likeCount': '85',
                    'commentCount': '12',
                  }
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final syncedCount = await analyticsRepo.syncYouTubeMetrics(
        appId: 'app_analytics_1',
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        quotaTracker: quotaTracker,
      );

      expect(syncedCount, equals(1));

      final snapshots = await analyticsRepo.getSnapshots(appId: 'app_analytics_1');
      expect(snapshots.length, equals(3)); // views, likes, comments

      final viewsSnapshot = snapshots.firstWhere((s) => s.metricType == 'views');
      expect(viewsSnapshot.metricValue, equals(1420.0));
      expect(viewsSnapshot.isMeasured, isTrue);
    });

    test('generateReport generates structured campaign model with CSV rows', () async {
      // Seed some measured snapshots
      await analyticsRepo.recordBatch([
        MetricSnapshotModel(
          id: 'ms_v1',
          appId: 'app_analytics_1',
          platform: 'youtube',
          metricName: 'views',
          metricValue: 5000.0,
          metricType: 'views',
          sourceRecordId: 'yt_vid_fitpulse_001',
          measuredAt: DateTime.now().toUtc(),
          isEstimated: false,
        ),
        MetricSnapshotModel(
          id: 'ms_l1',
          appId: 'app_analytics_1',
          platform: 'youtube',
          metricName: 'likes',
          metricValue: 250.0,
          metricType: 'likes',
          sourceRecordId: 'yt_vid_fitpulse_001',
          measuredAt: DateTime.now().toUtc(),
          isEstimated: false,
        ),
      ]);

      final app = AppModel(
        id: 'app_analytics_1',
        name: 'FitPulse Tracker',
        packageName: 'com.fitpulse.app',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.fitpulse.app',
        category: 'Health & Fitness',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final report = await analyticsRepo.generateReport(app: app, timeRange: '30d');

      expect(report.totalMeasuredViews, equals(5000));
      expect(report.totalMeasuredLikes, equals(250));
      expect(report.estimatedPlayStoreVisits, greaterThan(0));
      expect(report.estimatedInstalls, greaterThan(0));
      expect(report.platformBreakdown.containsKey('youtube'), isTrue);

      final csvRows = report.toCsvRows();
      expect(csvRows.isNotEmpty, isTrue);
      expect(csvRows.any((row) => row.contains('Total Video Views')), isTrue);
      expect(csvRows.any((row) => row.contains('Benchmark Model (8.0% Play Store CVR)')), isTrue);
    });
  });
}
