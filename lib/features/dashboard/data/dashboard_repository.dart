import '../../../core/database/app_database.dart';

class DashboardMetrics {
  final int registeredAppsCount;
  final int connectedAccountsCount;
  final int draftPostsCount;
  final int scheduledPostsCount;
  final int publishedPostsCount;
  final int failedJobsCount;

  const DashboardMetrics({
    required this.registeredAppsCount,
    required this.connectedAccountsCount,
    required this.draftPostsCount,
    required this.scheduledPostsCount,
    required this.publishedPostsCount,
    required this.failedJobsCount,
  });
}

class DashboardRepository {
  final AppDatabase _dbProvider;

  DashboardRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<int> _getCount(String sql) async {
    final db = await _dbProvider.database;
    final res = await db.rawQuery(sql);
    if (res.isNotEmpty && res.first.values.isNotEmpty) {
      final val = res.first.values.first;
      if (val is num) return val.toInt();
    }
    return 0;
  }

  Future<DashboardMetrics> getMetrics() async {
    final appsCount = await _getCount('SELECT COUNT(*) FROM apps WHERE is_archived = 0');
    final accountsCount = await _getCount("SELECT COUNT(*) FROM social_accounts WHERE status = 'connected'");
    final draftsCount = await _getCount("SELECT COUNT(*) FROM content_posts WHERE status = 'draft'");
    final scheduledCount = await _getCount("SELECT COUNT(*) FROM post_jobs WHERE status = 'pending'");
    final publishedCount = await _getCount("SELECT COUNT(*) FROM published_posts WHERE status = 'published'");
    final failedCount = await _getCount("SELECT COUNT(*) FROM post_jobs WHERE status = 'failed'");

    return DashboardMetrics(
      registeredAppsCount: appsCount,
      connectedAccountsCount: accountsCount,
      draftPostsCount: draftsCount,
      scheduledPostsCount: scheduledCount,
      publishedPostsCount: publishedCount,
      failedJobsCount: failedCount,
    );
  }
}
