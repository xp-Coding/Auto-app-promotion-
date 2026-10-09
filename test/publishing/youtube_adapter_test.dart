import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/features/content_studio/models/content_post_model.dart';
import 'package:appgrowth_studio/features/media_library/models/media_item_model.dart';
import 'package:appgrowth_studio/features/publishing/adapters/youtube/youtube_adapter.dart';
import 'package:appgrowth_studio/features/publishing/adapters/youtube/youtube_quota_tracker.dart';
import 'package:appgrowth_studio/features/publishing/adapters/youtube/youtube_token_storage.dart';
import 'package:appgrowth_studio/features/publishing/models/post_job_model.dart';
import 'package:appgrowth_studio/features/publishing/repositories/social_accounts_repository.dart';

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('YouTube Official Platform Adapter Tests', () {
    late Database db;
    late YouTubeTokenStorage tokenStorage;
    late YouTubeQuotaTracker quotaTracker;
    late SocialAccountsRepository socialRepo;
    late Directory tempDir;
    late File dummyVideoFile;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onCreate: DatabaseMigrations.onCreate,
        ),
      );

      tokenStorage = YouTubeTokenStorage(db);
      quotaTracker = YouTubeQuotaTracker(db);
      socialRepo = SocialAccountsRepository(db);

      tempDir = await Directory.systemTemp.createTemp('yt_test_');
      dummyVideoFile = File('${tempDir.path}/promo_video.mp4');
      await dummyVideoFile.writeAsBytes([0, 0, 0, 24, 102, 116, 121, 112]); // dummy mp4 header
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      await db.close();
    });

    test('OAuth token refresh executes when access token is expired', () async {
      // 1. Save expired credentials with valid refresh token
      await tokenStorage.saveCredentials(
        YouTubeCredentials(
          clientId: 'mock_client_id.apps.googleusercontent.com',
          clientSecret: 'mock_client_secret',
          accessToken: 'old_expired_token',
          refreshToken: 'valid_refresh_token_123',
          expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
        ),
      );

      // 2. Setup MockClient responding to OAuth refresh
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://oauth2.googleapis.com/token') {
          expect(request.bodyFields['grant_type'], equals('refresh_token'));
          expect(request.bodyFields['refresh_token'], equals('valid_refresh_token_123'));

          return http.Response(
            jsonEncode({
              'access_token': 'fresh_access_token_456',
              'expires_in': 3600,
              'token_type': 'Bearer',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final adapter = YouTubeAdapter(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        quotaTracker: quotaTracker,
        socialAccountsRepo: socialRepo,
      );

      expect(await adapter.isAuthenticated(), isTrue);

      // Verify token was refreshed in storage
      final post = ContentPostModel(
        id: 'post_1',
        appId: 'app_1',
        targetPlatform: 'youtube',
        title: 'Launch Video',
        bodyText: 'Check out our new app!',
        format: 'video_script',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final job = PostJobModel(
        id: 'job_1',
        contentId: 'post_1',
        targetPlatform: 'youtube',
        scheduledAt: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      // Upload with mockClient returning 200
      final uploadMockClient = MockClient((request) async {
        if (request.url.toString() == 'https://oauth2.googleapis.com/token') {
          return http.Response(
            jsonEncode({'access_token': 'fresh_access_token_456', 'expires_in': 3600}),
            200,
          );
        }
        if (request.url.path.contains('/videos')) {
          expect(request.headers['Authorization'], equals('Bearer fresh_access_token_456'));
          return http.Response(
            jsonEncode({
              'id': 'yt_vid_abc123',
              'snippet': {'title': 'Launch Video'},
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final uploadAdapter = YouTubeAdapter(
        httpClient: uploadMockClient,
        tokenStorage: tokenStorage,
        quotaTracker: quotaTracker,
        socialAccountsRepo: socialRepo,
      );

      final media = [
        MediaItemModel(
          id: 'media_1',
          appId: 'app_1',
          filePath: dummyVideoFile.path,
          mediaType: 'video',
          createdAt: DateTime.now().toUtc(),
        ),
      ];

      final result = await uploadAdapter.publish(post: post, job: job, media: media);
      expect(result.success, isTrue);
      expect(result.remoteId, equals('yt_vid_abc123'));
      expect(result.remoteUrl, equals('https://www.youtube.com/watch?v=yt_vid_abc123'));

      // Check quota consumed 1600 units
      final quota = await quotaTracker.getStatus();
      expect(quota.usedToday, equals(1600));
    });

    test('Publishing fails gracefully when video file is missing', () async {
      await tokenStorage.saveCredentials(
        const YouTubeCredentials(
          clientId: 'mock_client_id',
          clientSecret: 'mock_client_secret',
          accessToken: 'valid_token',
        ),
      );

      final adapter = YouTubeAdapter(
        tokenStorage: tokenStorage,
        quotaTracker: quotaTracker,
        socialAccountsRepo: socialRepo,
      );

      final post = ContentPostModel(
        id: 'post_2',
        appId: 'app_1',
        targetPlatform: 'youtube',
        bodyText: 'Text post without video',
        format: 'caption',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final job = PostJobModel(
        id: 'job_2',
        contentId: 'post_2',
        targetPlatform: 'youtube',
        scheduledAt: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final result = await adapter.publish(post: post, job: job, media: []);
      expect(result.success, isFalse);
      expect(result.error?.code, equals('MEDIA_MISSING'));
      expect(result.error?.isTransient, isFalse);
    });

    test('Quota limit reached prevents API execution and returns structured error', () async {
      await tokenStorage.saveCredentials(
        const YouTubeCredentials(
          clientId: 'mock_client_id',
          clientSecret: 'mock_client_secret',
          accessToken: 'valid_token',
        ),
      );

      // Consume 9000 units so only 1000 remaining (< 1600 required)
      await quotaTracker.recordConsumption(9000);
      final quota = await quotaTracker.getStatus();
      expect(quota.remaining, equals(1000));

      final adapter = YouTubeAdapter(
        tokenStorage: tokenStorage,
        quotaTracker: quotaTracker,
        socialAccountsRepo: socialRepo,
      );

      final post = ContentPostModel(
        id: 'post_3',
        appId: 'app_1',
        targetPlatform: 'youtube',
        bodyText: 'Promo video',
        format: 'video_script',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final job = PostJobModel(
        id: 'job_3',
        contentId: 'post_3',
        targetPlatform: 'youtube',
        scheduledAt: DateTime.now().toUtc(),
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final media = [
        MediaItemModel(
          id: 'media_1',
          appId: 'app_1',
          filePath: dummyVideoFile.path,
          mediaType: 'video',
          createdAt: DateTime.now().toUtc(),
        ),
      ];

      final result = await adapter.publish(post: post, job: job, media: media);
      expect(result.success, isFalse);
      expect(result.error?.code, equals('QUOTA_EXCEEDED'));
      expect(result.error?.isTransient, isFalse);
    });

    test('Remote publication verification accurately checks YouTube video processing status', () async {
      await tokenStorage.saveCredentials(
        const YouTubeCredentials(
          clientId: 'mock_client_id',
          clientSecret: 'mock_client_secret',
          accessToken: 'valid_token',
        ),
      );

      final mockClient = MockClient((request) async {
        if (request.url.queryParameters['id'] == 'yt_sample_123') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'yt_sample_123',
                  'status': {
                    'uploadStatus': 'processed',
                    'privacyStatus': 'public',
                  },
                  'snippet': {
                    'title': 'My Great App Promo',
                  },
                }
              ]
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final adapter = YouTubeAdapter(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        quotaTracker: quotaTracker,
        socialAccountsRepo: socialRepo,
      );

      final verification = await adapter.verifyPublication(remoteId: 'yt_sample_123');
      expect(verification.exists, isTrue);
      expect(verification.status, equals('processed'));
      expect(verification.isReady, isTrue);
      expect(verification.title, equals('My Great App Promo'));
      expect(verification.remoteUrl, equals('https://www.youtube.com/watch?v=yt_sample_123'));
    });

    test('Channel info retrieval populates social_accounts table', () async {
      await tokenStorage.saveCredentials(
        const YouTubeCredentials(
          clientId: 'mock_client_id',
          clientSecret: 'mock_client_secret',
          accessToken: 'valid_token',
        ),
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/channels')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'UC_sample_channel_id',
                  'snippet': {
                    'title': 'Awesome Dev Studio',
                    'thumbnails': {
                      'default': {'url': 'https://example.com/channel.png'}
                    }
                  },
                  'statistics': {
                    'subscriberCount': '12500',
                    'videoCount': '42',
                    'viewCount': '150000',
                  }
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final adapter = YouTubeAdapter(
        httpClient: mockClient,
        tokenStorage: tokenStorage,
        quotaTracker: quotaTracker,
        socialAccountsRepo: socialRepo,
      );

      final account = await adapter.fetchChannelInfo();
      expect(account, isNotNull);
      expect(account?.accountId, equals('UC_sample_channel_id'));
      expect(account?.accountName, equals('Awesome Dev Studio'));
      expect(account?.metadata['subscriberCount'], equals('12500'));

      // Check saved in SQLite
      final retrieved = await socialRepo.getAccountByPlatform('youtube');
      expect(retrieved, isNotNull);
      expect(retrieved?.accountName, equals('Awesome Dev Studio'));
      expect(retrieved?.isConnected, isTrue);
    });
  });
}
