import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/csv_helper.dart';
import '../../apps/providers/app_providers.dart';
import '../models/campaign_report_model.dart';
import '../providers/analytics_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  Future<void> _handleExportCsv(BuildContext context, CampaignReportModel report) async {
    final rows = report.toCsvRows();
    final csvString = CsvHelper.encode(rows);

    try {
      final nowStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final downloadsDir = Directory('${Platform.environment['USERPROFILE']}\\Downloads');
      final exportDir = downloadsDir.existsSync() ? downloadsDir : Directory.current;
      final file = File('${exportDir.path}\\AppGrowth_Report_${report.appName}_$nowStr.csv');

      await file.writeAsString(csvString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported successfully to: ${file.path}'),
            backgroundColor: AppTheme.accentEmerald,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(campaignReportProvider);
    final selectedApp = ref.watch(selectedAppProvider);
    final isSyncing = ref.watch(analyticsSyncProvider);
    final timeRange = ref.watch(analyticsTimeRangeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header & Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Performance Analytics & Campaign Reports',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedApp != null
                          ? 'Showing campaign data and attribution for: ${selectedApp.name}'
                          : 'Select an application to view performance analytics',
                      style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Time range chips
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: '7d', label: Text('7 Days')),
                        ButtonSegment(value: '30d', label: Text('30 Days')),
                        ButtonSegment(value: 'all', label: Text('All Time')),
                      ],
                      selected: {timeRange},
                      onSelectionChanged: (val) {
                        ref.read(analyticsTimeRangeProvider.notifier).state = val.first;
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: isSyncing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync, size: 18),
                      label: Text(isSyncing ? 'Syncing...' : 'Sync YouTube'),
                      onPressed: isSyncing
                          ? null
                          : () async {
                              final count = await ref.read(analyticsSyncProvider.notifier).syncMetricsNow();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Synchronized $count published video statistics from YouTube!'),
                                    backgroundColor: AppTheme.accentEmerald,
                                  ),
                                );
                              }
                            },
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export CSV'),
                      onPressed: reportAsync.value == null
                          ? null
                          : () => _handleExportCsv(context, reportAsync.value!),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (selectedApp == null) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Text('Please select or register an application in My Apps tab first.'),
                ),
              ),
            ] else ...[
              reportAsync.when(
                loading: () => const Center(
                  child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Center(child: Text('Error loading report: $err')),
                data: (report) {
                  if (report == null) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Measured Metrics
                      _buildSectionHeader(
                        title: 'Confirmed Measured Performance',
                        subtitle: 'Real statistics captured directly from official social APIs and link attribution.',
                        badgeText: 'MEASURED (OFFICIAL)',
                        badgeColor: AppTheme.accentEmerald,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Video Views',
                              value: NumberFormat.compact().format(report.totalMeasuredViews),
                              icon: Icons.play_arrow,
                              color: AppTheme.accentCyan,
                              isMeasured: true,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Total Likes',
                              value: NumberFormat.compact().format(report.totalMeasuredLikes),
                              icon: Icons.thumb_up_alt_outlined,
                              color: AppTheme.accentEmerald,
                              isMeasured: true,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Comments',
                              value: NumberFormat.compact().format(report.totalMeasuredComments),
                              icon: Icons.chat_bubble_outline,
                              color: AppTheme.primaryIndigo,
                              isMeasured: true,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Attributed Clicks',
                              value: NumberFormat.compact().format(report.totalMeasuredClicks),
                              icon: Icons.link,
                              color: AppTheme.accentAmber,
                              isMeasured: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section 2: Modeled / Estimated Metrics
                      _buildSectionHeader(
                        title: 'Modeled Funnel Estimates & Projections',
                        subtitle: 'Statistically projected conversion estimates using standard Google Play Store benchmark rates (8.0% CVR).',
                        badgeText: 'STATISTICAL ESTIMATE',
                        badgeColor: AppTheme.primaryIndigo,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Est. Play Store Visits',
                              value: NumberFormat.compact().format(report.estimatedPlayStoreVisits.round()),
                              icon: Icons.storefront_outlined,
                              color: AppTheme.primaryIndigo,
                              isMeasured: false,
                              subtitle: 'Modeled from attributed clicks',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Projected App Installs',
                              value: NumberFormat.compact().format(report.estimatedInstalls.round()),
                              icon: Icons.download_for_offline_outlined,
                              color: AppTheme.accentEmerald,
                              isMeasured: false,
                              subtitle: 'Based on 8.0% industry benchmark',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildKpiCard(
                              title: 'Benchmark Conversion Rate',
                              value: '${(report.estimatedConversionRate * 100).toStringAsFixed(1)}%',
                              icon: Icons.trending_up,
                              color: AppTheme.accentAmber,
                              isMeasured: false,
                              subtitle: 'Standard organic Google Play rate',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Section 3: Platform Breakdown Cards
                      const Text(
                        'Platform Performance Comparison',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: report.platformBreakdown.entries.map((e) {
                          final p = e.value;
                          final color = _getPlatformColor(p.platform);
                          return Expanded(
                            child: Card(
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Theme.of(context).dividerColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          p.platform.toUpperCase(),
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${p.postCount} posts',
                                            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildMetricRow('Views', NumberFormat.compact().format(p.views)),
                                    _buildMetricRow('Likes', NumberFormat.compact().format(p.likes)),
                                    _buildMetricRow('Comments', NumberFormat.compact().format(p.comments)),
                                    _buildMetricRow('Est. Installs', p.estimatedInstalls.round().toString()),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),

                      // Section 4: Top Performing Content
                      if (report.topPosts.isNotEmpty) ...[
                        const Text(
                          'Top Performing Content Posts',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: report.topPosts.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final post = report.topPosts[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getPlatformColor(post.platform).withOpacity(0.15),
                                  child: Icon(
                                    _getPlatformIcon(post.platform),
                                    color: _getPlatformColor(post.platform),
                                    size: 18,
                                  ),
                                ),
                                title: Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  'Platform: ${post.platform.toUpperCase()} • ${NumberFormat.compact().format(post.views)} views • ${post.likes} likes • ${post.comments} comments',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                                ),
                                trailing: post.remoteUrl != null
                                    ? OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        icon: const Icon(Icons.open_in_new, size: 14),
                                        label: const Text('Open'),
                                        onPressed: () {},
                                      )
                                    : null,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withOpacity(0.3)),
          ),
          child: Text(
            badgeText,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isMeasured,
    String? subtitle,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return AppTheme.platformYoutube;
      case 'tiktok':
        return AppTheme.platformTiktok;
      case 'facebook':
        return AppTheme.platformFacebook;
      case 'instagram':
        return AppTheme.platformInstagram;
      default:
        return AppTheme.primaryIndigo;
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return Icons.video_collection;
      case 'tiktok':
        return Icons.music_video;
      case 'facebook':
        return Icons.thumb_up_alt_outlined;
      case 'instagram':
        return Icons.camera_alt_outlined;
      default:
        return Icons.public;
    }
  }
}
