import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apps/providers/app_providers.dart';
import '../../campaigns/providers/campaign_providers.dart';
import '../../publishing/providers/publishing_providers.dart';
import '../models/campaign_report_model.dart';
import '../repositories/analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository();
});

final analyticsTimeRangeProvider = StateProvider<String>((ref) => '30d');

final campaignReportProvider = FutureProvider<CampaignReportModel?>((ref) async {
  final app = ref.watch(selectedAppProvider);
  if (app == null) return null;

  final timeRange = ref.watch(analyticsTimeRangeProvider);
  final repo = ref.watch(analyticsRepositoryProvider);
  final selectedCampaign = ref.watch(selectedCampaignProvider);

  return repo.generateReport(
    app: app,
    campaignId: selectedCampaign?.id,
    campaignName: selectedCampaign?.name,
    timeRange: timeRange,
  );
});

class AnalyticsSyncNotifier extends StateNotifier<bool> {
  final Ref _ref;

  AnalyticsSyncNotifier(this._ref) : super(false);

  Future<int> syncMetricsNow() async {
    final app = _ref.read(selectedAppProvider);
    if (app == null) return 0;

    state = true;
    try {
      final repo = _ref.read(analyticsRepositoryProvider);
      final tokenStorage = _ref.read(youtubeTokenStorageProvider);
      final quotaTracker = _ref.read(youtubeQuotaTrackerProvider);

      final syncedCount = await repo.syncYouTubeMetrics(
        appId: app.id,
        tokenStorage: tokenStorage,
        quotaTracker: quotaTracker,
      );

      _ref.invalidate(campaignReportProvider);
      _ref.invalidate(youtubeQuotaStatusProvider);
      return syncedCount;
    } finally {
      state = false;
    }
  }
}

final analyticsSyncProvider = StateNotifierProvider<AnalyticsSyncNotifier, bool>((ref) {
  return AnalyticsSyncNotifier(ref);
});
