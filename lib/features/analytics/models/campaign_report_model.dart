class PlatformMetrics {
  final String platform;
  final int views;
  final int likes;
  final int comments;
  final int clicks;
  final double estimatedInstalls;
  final int postCount;

  const PlatformMetrics({
    required this.platform,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.clicks = 0,
    this.estimatedInstalls = 0.0,
    this.postCount = 0,
  });
}

class TopPerformingPost {
  final String postId;
  final String title;
  final String platform;
  final int views;
  final int likes;
  final int comments;
  final String? remoteUrl;

  const TopPerformingPost({
    required this.postId,
    required this.title,
    required this.platform,
    required this.views,
    required this.likes,
    required this.comments,
    this.remoteUrl,
  });
}

class CampaignReportModel {
  final String appId;
  final String appName;
  final String? campaignId;
  final String? campaignName;
  final DateTime generatedAt;
  final String timeRange; // '7d', '30d', 'all'

  // Confirmed Measured Metrics (from official APIs & verified interactions)
  final int totalMeasuredViews;
  final int totalMeasuredLikes;
  final int totalMeasuredComments;
  final int totalMeasuredClicks;

  // Modeled / Benchmark Estimates (explicitly identified as estimates)
  final double estimatedPlayStoreVisits;
  final double estimatedInstalls;
  final double estimatedConversionRate; // e.g., 0.08 (8%) based on Google Play average

  final Map<String, PlatformMetrics> platformBreakdown;
  final List<TopPerformingPost> topPosts;

  const CampaignReportModel({
    required this.appId,
    required this.appName,
    this.campaignId,
    this.campaignName,
    required this.generatedAt,
    required this.timeRange,
    required this.totalMeasuredViews,
    required this.totalMeasuredLikes,
    required this.totalMeasuredComments,
    required this.totalMeasuredClicks,
    required this.estimatedPlayStoreVisits,
    required this.estimatedInstalls,
    this.estimatedConversionRate = 0.08,
    required this.platformBreakdown,
    this.topPosts = const [],
  });

  /// Convert report data into standard CSV rows for file export
  List<List<dynamic>> toCsvRows() {
    final rows = <List<dynamic>>[];
    rows.add(['AppGrowth Studio Campaign & Analytics Report']);
    rows.add(['Application', appName, 'App ID', appId]);
    if (campaignName != null) {
      rows.add(['Campaign', campaignName!, 'Campaign ID', campaignId ?? '']);
    }
    rows.add(['Time Range', timeRange, 'Generated At', generatedAt.toIso8601String()]);
    rows.add([]);

    rows.add(['--- MEASURED PERFORMANCE METRICS (OFFICIAL API) ---']);
    rows.add(['Metric', 'Value', 'Source Type']);
    rows.add(['Total Video Views', totalMeasuredViews, 'Measured (API)']);
    rows.add(['Total Likes', totalMeasuredLikes, 'Measured (API)']);
    rows.add(['Total Comments', totalMeasuredComments, 'Measured (API)']);
    rows.add(['Total Link Clicks', totalMeasuredClicks, 'Measured (Attribution)']);
    rows.add([]);

    rows.add(['--- STATISTICAL ESTIMATES & CONVERSIONS ---']);
    rows.add(['Metric', 'Estimated Value', 'Methodology / Benchmark']);
    rows.add(['Estimated Play Store Visits', estimatedPlayStoreVisits.round(), 'Estimated based on 1.2x click attribution']);
    rows.add(['Estimated Installs', estimatedInstalls.round(), 'Benchmark Model (${(estimatedConversionRate * 100).toStringAsFixed(1)}% Play Store CVR)']);
    rows.add([]);

    rows.add(['--- PLATFORM BREAKDOWN ---']);
    rows.add(['Platform', 'Posts', 'Views', 'Likes', 'Comments', 'Clicks', 'Est. Installs']);
    for (final entry in platformBreakdown.entries) {
      final p = entry.value;
      rows.add([p.platform.toUpperCase(), p.postCount, p.views, p.likes, p.comments, p.clicks, p.estimatedInstalls.round()]);
    }
    rows.add([]);

    if (topPosts.isNotEmpty) {
      rows.add(['--- TOP PERFORMING POSTS ---']);
      rows.add(['Platform', 'Post Title', 'Views', 'Likes', 'Comments', 'URL']);
      for (final post in topPosts) {
        rows.add([post.platform.toUpperCase(), post.title, post.views, post.likes, post.comments, post.remoteUrl ?? '']);
      }
    }

    return rows;
  }
}
