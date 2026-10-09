import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../content_studio/models/content_post_model.dart';
import '../../../media_library/models/media_item_model.dart';
import '../../domain/platform_adapter.dart';
import '../../models/post_job_model.dart';
import '../../models/social_account_model.dart';
import '../../repositories/social_accounts_repository.dart';
import 'youtube_quota_tracker.dart';
import 'youtube_token_storage.dart';

class YouTubeAdapter implements PublishingPlatformAdapter {
  final http.Client _client;
  final YouTubeTokenStorage _tokenStorage;
  final YouTubeQuotaTracker _quotaTracker;
  final SocialAccountsRepository _socialAccountsRepo;

  static const String _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String _youtubeApiBase = 'https://www.googleapis.com/youtube/v3';
  static const String _youtubeUploadBase = 'https://www.googleapis.com/upload/youtube/v3';

  YouTubeAdapter({
    http.Client? httpClient,
    YouTubeTokenStorage? tokenStorage,
    YouTubeQuotaTracker? quotaTracker,
    SocialAccountsRepository? socialAccountsRepo,
  })  : _client = httpClient ?? http.Client(),
        _tokenStorage = tokenStorage ?? YouTubeTokenStorage(),
        _quotaTracker = quotaTracker ?? YouTubeQuotaTracker(),
        _socialAccountsRepo = socialAccountsRepo ?? SocialAccountsRepository();

  @override
  String get platformId => 'youtube';

  @override
  String get platformDisplayName => 'YouTube';

  @override
  Future<bool> isAuthenticated() async {
    final credentials = await _tokenStorage.getCredentials();
    if (credentials == null) return false;
    return credentials.refreshToken != null || credentials.hasValidToken;
  }

  /// Refreshes OAuth token if expired or nearing expiry
  Future<String?> _getValidAccessToken() async {
    final credentials = await _tokenStorage.getCredentials();
    if (credentials == null) return null;

    if (!credentials.needsRefresh && credentials.accessToken != null) {
      return credentials.accessToken;
    }

    // Refresh token is required for unattended desktop publishing
    if (credentials.refreshToken == null || credentials.refreshToken!.isEmpty) {
      return credentials.accessToken;
    }

    try {
      final response = await _client.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': credentials.clientId,
          'client_secret': credentials.clientSecret,
          'refresh_token': credentials.refreshToken!,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String;
        final expiresInSeconds = (data['expires_in'] as num?)?.toInt() ?? 3600;
        final newExpiry = DateTime.now().toUtc().add(Duration(seconds: expiresInSeconds));

        await _tokenStorage.updateTokens(
          accessToken: newAccessToken,
          expiresAt: newExpiry,
        );

        return newAccessToken;
      } else {
        final errorData = jsonDecode(response.body);
        final err = errorData['error']?.toString() ?? 'token_refresh_failed';
        if (err == 'invalid_grant') {
          await _socialAccountsRepo.updateAccountStatus('youtube', 'expired');
        }
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PublishResult> publish({
    required ContentPostModel post,
    required PostJobModel job,
    List<MediaItemModel> media = const [],
  }) async {
    // 1. Check OAuth token
    final accessToken = await _getValidAccessToken();
    if (accessToken == null) {
      return const PublishResult.failure(
        error: PublishError(
          code: 'AUTH_REQUIRED',
          message: 'Valid YouTube OAuth authorization token is missing or expired.',
          isTransient: false,
          resolutionGuide: 'Go to Social Accounts tab and connect/re-authorize your YouTube account.',
        ),
      );
    }

    // 2. Validate video media requirement
    File? videoFile;
    if (media.isNotEmpty) {
      for (final m in media) {
        if (m.mediaType == 'video') {
          final file = File(m.filePath);
          if (file.existsSync()) {
            videoFile = file;
            break;
          }
        }
      }
    }

    // YouTube requires a video file for publishing
    if (videoFile == null) {
      return const PublishResult.failure(
        error: PublishError(
          code: 'MEDIA_MISSING',
          message: 'YouTube publication requires an existing local MP4/MOV video file.',
          isTransient: false,
          resolutionGuide: 'Attach a valid video asset from the Media Library to this post before publishing.',
        ),
      );
    }

    // 3. Check YouTube Quota
    final canInsert = await _quotaTracker.canConsume(YouTubeQuotaTracker.costVideoInsert);
    if (!canInsert) {
      return const PublishResult.failure(
        error: PublishError(
          code: 'QUOTA_EXCEEDED',
          message: 'Daily YouTube Data API v3 quota limit reached (10,000 units/day).',
          isTransient: false,
          resolutionGuide: 'Wait until midnight PT for quota reset or request a quota increase from Google Cloud Console.',
        ),
      );
    }

    // 4. Construct video metadata
    final tags = (post.hashtags ?? '')
        .split(RegExp(r'\s+'))
        .where((t) => t.startsWith('#'))
        .map((t) => t.replaceFirst('#', '').trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final fullDescription = [
      post.bodyText,
      if (post.ctaLink != null && post.ctaLink!.isNotEmpty) '\nGet the app on Google Play:\n${post.ctaLink}',
      if (post.hashtags != null && post.hashtags!.isNotEmpty) '\n${post.hashtags}',
    ].join('\n');

    final metadata = {
      'snippet': {
        'title': (post.title != null && post.title!.isNotEmpty) ? post.title : 'App Preview',
        'description': fullDescription,
        'tags': tags,
        'categoryId': '22', // People & Blogs
      },
      'status': {
        'privacyStatus': 'public',
        'selfDeclaredMadeForKids': false,
      },
    };

    // 5. Send Video Insert Request
    try {
      // Multipart upload for video files
      final requestUri = Uri.parse('$_youtubeUploadBase/videos?uploadType=multipart&part=snippet,status');
      final request = http.MultipartRequest('POST', requestUri);
      request.headers['Authorization'] = 'Bearer $accessToken';

      request.fields['snippet'] = jsonEncode(metadata);

      final fileStream = http.ByteStream(videoFile.openRead());
      final fileLength = await videoFile.length();
      request.files.add(
        http.MultipartFile(
          'media',
          fileStream,
          fileLength,
          filename: videoFile.uri.pathSegments.last,
        ),
      );

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _quotaTracker.recordConsumption(YouTubeQuotaTracker.costVideoInsert);

        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final videoId = responseData['id'] as String;
        final watchUrl = 'https://www.youtube.com/watch?v=$videoId';

        return PublishResult.success(
          remoteId: videoId,
          remoteUrl: watchUrl,
          publishedAt: DateTime.now().toUtc(),
          metadata: responseData,
        );
      } else {
        return _handleApiError(response.statusCode, response.body);
      }
    } on SocketException {
      return const PublishResult.failure(
        error: PublishError(
          code: 'NETWORK_ERROR',
          message: 'Network connection failed while connecting to YouTube API.',
          isTransient: true,
          resolutionGuide: 'Check your internet connection. Queue worker will retry automatically.',
        ),
      );
    } catch (e) {
      return PublishResult.failure(
        error: PublishError(
          code: 'UNEXPECTED_ERROR',
          message: 'Unexpected error during video upload: $e',
          isTransient: true,
          resolutionGuide: 'Queue worker will retry with exponential backoff.',
        ),
      );
    }
  }

  @override
  Future<VerificationResult> verifyPublication({required String remoteId}) async {
    final accessToken = await _getValidAccessToken();
    if (accessToken == null) {
      return const VerificationResult(
        exists: false,
        status: 'auth_missing',
        details: 'Cannot verify publication: OAuth token missing or expired.',
      );
    }

    try {
      final uri = Uri.parse('$_youtubeApiBase/videos?part=snippet,status&id=$remoteId');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        await _quotaTracker.recordConsumption(YouTubeQuotaTracker.costVideoList);

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];

        if (items.isEmpty) {
          return const VerificationResult(
            exists: false,
            status: 'not_found',
            details: 'Video not found on YouTube. It may have been deleted.',
          );
        }

        final item = items.first as Map<String, dynamic>;
        final statusMap = item['status'] as Map<String, dynamic>? ?? {};
        final snippetMap = item['snippet'] as Map<String, dynamic>? ?? {};

        final uploadStatus = statusMap['uploadStatus'] as String? ?? 'uploaded';
        final title = snippetMap['title'] as String?;
        final watchUrl = 'https://www.youtube.com/watch?v=$remoteId';

        return VerificationResult(
          exists: true,
          status: uploadStatus,
          title: title,
          remoteUrl: watchUrl,
          details: 'Privacy: ${statusMap['privacyStatus'] ?? 'unknown'}',
        );
      } else {
        return VerificationResult(
          exists: false,
          status: 'error',
          details: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return VerificationResult(
        exists: false,
        status: 'error',
        details: 'Verification query failed: $e',
      );
    }
  }

  /// Fetches channel information and updates the connected social_account record in SQLite
  Future<SocialAccountModel?> fetchChannelInfo() async {
    final accessToken = await _getValidAccessToken();
    if (accessToken == null) return null;

    try {
      final uri = Uri.parse('$_youtubeApiBase/channels?part=snippet,statistics&mine=true');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        await _quotaTracker.recordConsumption(YouTubeQuotaTracker.costChannelList);

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        if (items.isEmpty) return null;

        final item = items.first as Map<String, dynamic>;
        final channelId = item['id'] as String;
        final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
        final statistics = item['statistics'] as Map<String, dynamic>? ?? {};

        final channelTitle = snippet['title'] as String? ?? 'YouTube Channel';
        final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
        final defaultThumb = (thumbnails['default'] as Map<String, dynamic>?)?['url'] as String?;

        final account = SocialAccountModel(
          id: 'youtube_$channelId',
          platform: 'youtube',
          accountName: channelTitle,
          accountId: channelId,
          profilePictureUrl: defaultThumb,
          status: 'connected',
          connectedAt: DateTime.now().toUtc(),
          lastSyncedAt: DateTime.now().toUtc(),
          capabilities: ['videos.insert', 'videos.list', 'channels.list', 'shorts'],
          metadata: {
            'subscriberCount': statistics['subscriberCount'],
            'videoCount': statistics['videoCount'],
            'viewCount': statistics['viewCount'],
          },
        );

        await _socialAccountsRepo.saveAccount(account);
        return account;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<QuotaStatus> checkQuota() async {
    return _quotaTracker.getStatus();
  }

  @override
  Future<void> revokeAuth() async {
    await _tokenStorage.clearCredentials();
    await _socialAccountsRepo.disconnectAccount('youtube');
  }

  PublishResult _handleApiError(int statusCode, String responseBody) {
    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>? ?? {};
      final errorsList = error['errors'] as List<dynamic>? ?? [];
      final reason = errorsList.isNotEmpty
          ? (errorsList.first as Map<String, dynamic>)['reason'] as String? ?? ''
          : '';
      final message = error['message'] as String? ?? 'YouTube API error ($statusCode)';

      if (reason == 'quotaExceeded' || statusCode == 403 && message.contains('quota')) {
        return PublishResult.failure(
          error: PublishError(
            code: 'QUOTA_EXCEEDED',
            message: message,
            isTransient: false,
            resolutionGuide: 'Daily quota resets at midnight Pacific Time. Request higher quota in Google Cloud Console.',
          ),
        );
      }

      if (statusCode == 401 || reason == 'authError') {
        return PublishResult.failure(
          error: PublishError(
            code: 'AUTH_EXPIRED',
            message: message,
            isTransient: false,
            resolutionGuide: 'Please reconnect your YouTube account in the Social Accounts tab.',
          ),
        );
      }

      if (statusCode == 429 || reason == 'rateLimitExceeded') {
        return PublishResult.failure(
          error: PublishError(
            code: 'RATE_LIMIT',
            message: message,
            isTransient: true,
            resolutionGuide: 'Worker will automatically retry with exponential backoff.',
          ),
        );
      }

      if (statusCode >= 500) {
        return PublishResult.failure(
          error: PublishError(
            code: 'SERVER_ERROR',
            message: 'YouTube server error ($statusCode): $message',
            isTransient: true,
            resolutionGuide: 'Temporary YouTube platform outage. Worker will retry.',
          ),
        );
      }

      // Default permanent client error
      return PublishResult.failure(
        error: PublishError(
          code: 'API_ERROR_$statusCode',
          message: message,
          isTransient: false,
          resolutionGuide: 'Review post content and video formatting in Content Studio.',
        ),
      );
    } catch (_) {
      return PublishResult.failure(
        error: PublishError(
          code: 'HTTP_$statusCode',
          message: 'HTTP $statusCode error: $responseBody',
          isTransient: statusCode >= 500,
          resolutionGuide: 'Check network status and YouTube account configuration.',
        ),
      );
    }
  }
}
