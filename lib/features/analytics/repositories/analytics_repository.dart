import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../apps/models/app_model.dart';
import '../../publishing/adapters/youtube/youtube_quota_tracker.dart';
import '../../publishing/adapters/youtube/youtube_token_storage.dart';
import '../models/campaign_report_model.dart';
import '../models/metric_snapshot_model.dart';

class AnalyticsRepository {
  final Database? _rawDb;
  final AppDatabase _dbProvider;
  final Uuid _uuid = const Uuid();

  AnalyticsRepository({AppDatabase? dbProvider, Database? db})
      : _dbProvider = dbProvider ?? AppDatabase.instance,
        _rawDb = db;

  Future<Database> get _database async => _rawDb ?? await _dbProvider.database;

  /// Insert an individual metric snapshot
  Future<void> recordSnapshot(MetricSnapshotModel snapshot) async {
    final db = await _database;
    await db.insert('metric_snapshots', snapshot.toMap());
  }

  /// Insert batch of metric snapshots inside transaction
  Future<void> recordBatch(List<MetricSnapshotModel> snapshots) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final s in snapshots) {
        await txn.insert('metric_snapshots', s.toMap());
      }
    });
  }

  /// Query metric snapshots for an application
  Future<List<MetricSnapshotModel>> getSnapshots({
    required String appId,
    String? platform,
    String? metricType,
    DateTime? since,
  }) async {
    final db = await _database;
    final whereClauses = <String>['app_id = ?'];
    final whereArgs = <dynamic>[appId];

    if (platform != null && platform.isNotEmpty && platform != 'all') {
      whereClauses.add('platform = ?');
      whereArgs.add(platform);
    }
    if (metricType != null && metricType.isNotEmpty && metricType != 'all') {
      whereClauses.add('metric_type = ?');
      whereArgs.add(metricType);
    }
    if (since != null) {
      whereClauses.add('measured_at >= ?');
      whereArgs.add(since.toUtc().toIso8601String());
    }

    final maps = await db.query(
      'metric_snapshots',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'measured_at DESC',
    );

    return maps.map(MetricSnapshotModel.fromMap).toList();
  }

  /// Scheduled metric retrieval for YouTube published videos via official API
  Future<int> syncYouTubeMetrics({
    required String appId,
    http.Client? httpClient,
    YouTubeTokenStorage? tokenStorage,
    YouTubeQuotaTracker? quotaTracker,
  }) async {
    final db = await _database;

    // 1. Find all YouTube published posts for this app
    final publishedRows = await db.rawQuery('''
      SELECT pp.id, pp.post_id, pp.remote_id, cp.title
      FROM published_posts pp
      INNER JOIN content_posts cp ON pp.post_id = cp.id
      WHERE cp.app_id = ? AND pp.platform = 'youtube' AND pp.remote_id IS NOT NULL
    ''', [appId]);

    if (publishedRows.isEmpty) return 0;

    final storage = tokenStorage ?? YouTubeTokenStorage(db);
    final quota = quotaTracker ?? YouTubeQuotaTracker(db);
    final creds = await storage.getCredentials();
    if (creds == null || creds.accessToken == null) return 0;

    final client = httpClient ?? http.Client();
    final now = DateTime.now().toUtc();
    int syncedCount = 0;

    final videoIds = publishedRows.map((r) => r['remote_id'] as String).toList();
    // YouTube allows comma-separated video IDs up to 50 in a single query (costs only 1 quota unit!)
    final chunks = <List<String>>[];
    for (var i = 0; i < videoIds.length; i += 50) {
      chunks.add(videoIds.sublist(i, i + 50 > videoIds.length ? videoIds.length : i + 50));
    }

    for (final chunk in chunks) {
      final idsParam = chunk.join(',');
      final uri = Uri.parse('https://www.googleapis.com/youtube/v3/videos?part=statistics&id=$idsParam');

      try {
        final response = await client.get(
          uri,
          headers: {'Authorization': 'Bearer ${creds.accessToken}'},
        );

        if (response.statusCode == 200) {
          await quota.recordConsumption(YouTubeQuotaTracker.costVideoList);
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];

          final snapshots = <MetricSnapshotModel>[];

          for (final item in items) {
            final vid = item['id'] as String;
            final stats = item['statistics'] as Map<String, dynamic>? ?? {};

            final views = double.tryParse(stats['viewCount']?.toString() ?? '0') ?? 0.0;
            final likes = double.tryParse(stats['likeCount']?.toString() ?? '0') ?? 0.0;
            final comments = double.tryParse(stats['commentCount']?.toString() ?? '0') ?? 0.0;

            snapshots.add(MetricSnapshotModel(
              id: _uuid.v4(),
              appId: appId,
              platform: 'youtube',
              metricName: 'views',
              metricValue: views,
              metricType: 'views',
              measuredAt: now,
              sourceRecordId: vid,
              isEstimated: false, // Measured directly from YouTube Data API v3
            ));

            snapshots.add(MetricSnapshotModel(
              id: _uuid.v4(),
              appId: appId,
              platform: 'youtube',
              metricName: 'likes',
              metricValue: likes,
              metricType: 'likes',
              measuredAt: now,
              sourceRecordId: vid,
              isEstimated: false,
            ));

            snapshots.add(MetricSnapshotModel(
              id: _uuid.v4(),
              appId: appId,
              platform: 'youtube',
              metricName: 'comments',
              metricValue: comments,
              metricType: 'comments',
              measuredAt: now,
              sourceRecordId: vid,
              isEstimated: false,
            ));

            syncedCount++;
          }

          if (snapshots.isNotEmpty) {
            await recordBatch(snapshots);
          }
        }
      } catch (_) {}
    }

    return syncedCount;
  }

  /// Generate a consolidated campaign and performance report
  Future<CampaignReportModel> generateReport({
    required AppModel app,
    String? campaignId,
    String? campaignName,
    String timeRange = '30d',
  }) async {
    final db = await _database;
    final now = DateTime.now().toUtc();

    DateTime? sinceDate;
    if (timeRange == '7d') {
      sinceDate = now.subtract(const Duration(days: 7));
    } else if (timeRange == '30d') {
      sinceDate = now.subtract(const Duration(days: 30));
    }

    final snapshots = await getSnapshots(appId: app.id, since: sinceDate);

    // Sum measured metrics
    int totalViews = 0;
    int totalLikes = 0;
    int totalComments = 0;
    int totalClicks = 0;

    final platformMap = <String, Map<String, dynamic>>{
      'youtube': {'views': 0, 'likes': 0, 'comments': 0, 'clicks': 0, 'posts': 0},
      'tiktok': {'views': 0, 'likes': 0, 'comments': 0, 'clicks': 0, 'posts': 0},
      'facebook': {'views': 0, 'likes': 0, 'comments': 0, 'clicks': 0, 'posts': 0},
      'instagram': {'views': 0, 'likes': 0, 'comments': 0, 'clicks': 0, 'posts': 0},
    };

    // Calculate latest metrics per source record to avoid double-counting periodic snapshots
    final latestBySourceAndMetric = <String, MetricSnapshotModel>{};
    for (final s in snapshots) {
      if (s.isMeasured) {
        final key = '${s.platform}_${s.sourceRecordId ?? "global"}_${s.metricType}';
        if (!latestBySourceAndMetric.containsKey(key)) {
          latestBySourceAndMetric[key] = s;
        }
      }
    }

    for (final s in latestBySourceAndMetric.values) {
      final val = s.metricValue.round();
      final pKey = s.platform.toLowerCase();
      final pStats = platformMap[pKey];

      switch (s.metricType) {
        case 'views':
          totalViews += val;
          if (pStats != null) pStats['views'] = (pStats['views'] as int) + val;
          break;
        case 'likes':
          totalLikes += val;
          if (pStats != null) pStats['likes'] = (pStats['likes'] as int) + val;
          break;
        case 'comments':
          totalComments += val;
          if (pStats != null) pStats['comments'] = (pStats['comments'] as int) + val;
          break;
        case 'clicks':
          totalClicks += val;
          if (pStats != null) pStats['clicks'] = (pStats['clicks'] as int) + val;
          break;
      }
    }

    // Count published posts per platform
    final postCounts = await db.rawQuery('''
      SELECT pp.platform, COUNT(DISTINCT pp.id) as cnt
      FROM published_posts pp
      INNER JOIN content_posts cp ON pp.post_id = cp.id
      WHERE cp.app_id = ?
      GROUP BY pp.platform
    ''', [app.id]);

    for (final row in postCounts) {
      final pKey = (row['platform'] as String).toLowerCase();
      final cnt = (row['cnt'] as num).toInt();
      if (platformMap.containsKey(pKey)) {
        platformMap[pKey]!['posts'] = cnt;
      }
    }

    // Modeled estimates with industry benchmark rates
    // Typical CTR from social views: 1.5%
    // Typical Play Store conversion from visits: 8.0%
    final estVisits = totalClicks > 0 ? totalClicks * 1.2 : (totalViews * 0.015);
    const benchmarkConversionRate = 0.08; // 8% Google Play average
    final estInstalls = estVisits * benchmarkConversionRate;

    // Platform breakdown
    final platformBreakdown = <String, PlatformMetrics>{};
    for (final entry in platformMap.entries) {
      final p = entry.key;
      final m = entry.value;
      final pViews = m['views'] as int;
      final pClicks = m['clicks'] as int;
      final pVisits = pClicks > 0 ? pClicks * 1.2 : (pViews * 0.015);
      final pInstalls = pVisits * benchmarkConversionRate;

      platformBreakdown[p] = PlatformMetrics(
        platform: p,
        views: pViews,
        likes: m['likes'] as int,
        comments: m['comments'] as int,
        clicks: pClicks,
        estimatedInstalls: pInstalls,
        postCount: m['posts'] as int,
      );
    }

    // Query top performing posts
    final topPostsQuery = await db.rawQuery('''
      SELECT cp.id as post_id, cp.title, pp.platform, pp.remote_url,
             COALESCE(MAX(CASE WHEN ms.metric_type = 'views' THEN ms.metric_value END), 0) as views,
             COALESCE(MAX(CASE WHEN ms.metric_type = 'likes' THEN ms.metric_value END), 0) as likes,
             COALESCE(MAX(CASE WHEN ms.metric_type = 'comments' THEN ms.metric_value END), 0) as comments
      FROM published_posts pp
      INNER JOIN content_posts cp ON pp.post_id = cp.id
      LEFT JOIN metric_snapshots ms ON pp.remote_id = ms.source_record_id
      WHERE cp.app_id = ?
      GROUP BY cp.id, pp.platform
      ORDER BY views DESC, likes DESC
      LIMIT 5
    ''', [app.id]);

    final topPosts = topPostsQuery.map((r) {
      return TopPerformingPost(
        postId: r['post_id'] as String,
        title: (r['title'] as String?) ?? 'Untitled Promo',
        platform: r['platform'] as String,
        views: (r['views'] as num).toInt(),
        likes: (r['likes'] as num).toInt(),
        comments: (r['comments'] as num).toInt(),
        remoteUrl: r['remote_url'] as String?,
      );
    }).toList();

    return CampaignReportModel(
      appId: app.id,
      appName: app.name,
      campaignId: campaignId,
      campaignName: campaignName,
      generatedAt: now,
      timeRange: timeRange,
      totalMeasuredViews: totalViews,
      totalMeasuredLikes: totalLikes,
      totalMeasuredComments: totalComments,
      totalMeasuredClicks: totalClicks,
      estimatedPlayStoreVisits: estVisits,
      estimatedInstalls: estInstalls,
      estimatedConversionRate: benchmarkConversionRate,
      platformBreakdown: platformBreakdown,
      topPosts: topPosts,
    );
  }
}
