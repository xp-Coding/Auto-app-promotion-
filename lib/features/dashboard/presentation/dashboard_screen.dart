import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/presentation/app_details_dialog.dart';
import '../../apps/presentation/app_form_dialog.dart';
import '../../apps/providers/app_providers.dart';
import '../../campaigns/providers/campaign_providers.dart';
import '../../content_studio/providers/content_studio_providers.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider((ref) => DashboardRepository());

final dashboardMetricsProvider = FutureProvider.autoDispose<DashboardMetrics>((ref) async {
  // Watch apps, drafts, and campaigns so metrics refresh reactively
  ref.watch(appsListProvider);
  ref.watch(contentPostsListProvider);
  ref.watch(campaignsListProvider);
  final repo = ref.read(dashboardRepositoryProvider);
  return repo.getMetrics();
});

class DashboardScreen extends ConsumerWidget {
  final ValueChanged<int>? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final appsAsync = ref.watch(appsListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AppGrowth Marketing Studio',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Local-first organic promotion dashboard for your Google Play applications.',
                        style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      onPressed: () {
                        ref.invalidate(dashboardMetricsProvider);
                        ref.read(appsListProvider.notifier).loadApps();
                      },
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.rocket_launch, size: 18),
                      label: const Text('Start Autopilot'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryIndigo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (onNavigateTab != null) {
                          onNavigateTab!(10); // Index of Autopilot Studio
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Register App'),
                      onPressed: () => AppFormDialog.show(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Autopilot Quick Launch Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryIndigo.withOpacity(0.18),
                    AppTheme.accentCyan.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryIndigo.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt, color: AppTheme.primaryIndigo, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚡ 1-Click App Promotion Autopilot',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Provide a Google Play Store URL. The system scrapes details, discovers keywords, creates 30 days of posts, renders local assets, and schedules to the queue automatically.',
                          style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.rocket_launch, size: 16),
                    label: const Text('Launch Autopilot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryIndigo,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (onNavigateTab != null) onNavigateTab!(10);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Top Metric Cards (Real SQLite data)
            metricsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (err, _) => Center(child: Text('Error loading metrics: $err')),
              data: (metrics) => Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int crossAxisCount = 5;
                      if (width < 600) {
                        crossAxisCount = 1;
                      } else if (width < 900) {
                        crossAxisCount = 2;
                      } else if (width < 1150) {
                        crossAxisCount = 3;
                      }
                      final itemWidth = (width - ((crossAxisCount - 1) * 16)) / crossAxisCount;

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _buildMetricCard(
                              context,
                              title: 'Registered Apps',
                              value: '${metrics.registeredAppsCount}',
                              icon: Icons.android,
                              accentColor: AppTheme.primaryIndigo,
                              subtitle: 'Tracked Play Store profiles',
                              onTap: () => onNavigateTab?.call(1),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildMetricCard(
                              context,
                              title: 'Connected Accounts',
                              value: '${metrics.connectedAccountsCount}',
                              icon: Icons.share_outlined,
                              accentColor: AppTheme.accentCyan,
                              subtitle: 'YouTube, Meta & TikTok',
                              onTap: () => onNavigateTab?.call(8),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildMetricCard(
                              context,
                              title: 'Draft Content',
                              value: '${metrics.draftPostsCount}',
                              icon: Icons.edit_note,
                              accentColor: AppTheme.accentAmber,
                              subtitle: 'Saved promotional posts',
                              onTap: () => onNavigateTab?.call(4),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildMetricCard(
                              context,
                              title: 'Scheduled Queue',
                              value: '${metrics.scheduledPostsCount}',
                              icon: Icons.schedule,
                              accentColor: AppTheme.accentEmerald,
                              subtitle: 'Pending local publications',
                              onTap: () => onNavigateTab?.call(7),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildMetricCard(
                              context,
                              title: 'Failed Jobs',
                              value: '${metrics.failedJobsCount}',
                              icon: Icons.warning_amber_rounded,
                              accentColor: metrics.failedJobsCount > 0 ? AppTheme.accentRose : AppTheme.darkTextSecondary,
                              subtitle: 'Require user attention',
                              onTap: () => onNavigateTab?.call(7),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // If database is empty, show First-Run Experience
                  if (metrics.registeredAppsCount == 0) ...[
                    const SizedBox(height: 24),
                    _buildFirstRunCard(context),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions & Recent Apps Section
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 850;
                final quickActionsWidget = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Marketing Workflows',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '100% free, local-first organic growth pipeline.',
                          style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                        ),
                        const SizedBox(height: 16),
                        _buildWorkflowItem(
                          icon: Icons.app_registration,
                          color: AppTheme.primaryIndigo,
                          title: 'Register Android App',
                          desc: 'Enter Play Store URL, validate listing score, and capture features.',
                          buttonText: 'Add App',
                          onPressed: () => AppFormDialog.show(context),
                        ),
                        const Divider(height: 20),
                        _buildWorkflowItem(
                          icon: Icons.tag,
                          color: AppTheme.accentCyan,
                          title: 'Research Keywords & Topics',
                          desc: 'Cluster topics, analyze competitor titles, and discover video hooks.',
                          buttonText: 'Research',
                          onPressed: () => onNavigateTab?.call(3),
                        ),
                        const Divider(height: 20),
                        _buildWorkflowItem(
                          icon: Icons.auto_awesome,
                          color: AppTheme.accentEmerald,
                          title: 'Content Studio',
                          desc: 'Generate platform-specific video scripts, captions, and carousel copy.',
                          buttonText: 'Open Studio',
                          onPressed: () => onNavigateTab?.call(4),
                        ),
                      ],
                    ),
                  ),
                );

                final recentAppsWidget = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Registered Apps',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () => onNavigateTab?.call(1),
                              child: const Text('View All Apps', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        appsAsync.when(
                          loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                          error: (e, _) => Text('Error loading apps: $e'),
                          data: (apps) {
                            if (apps.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    const Icon(Icons.apps, size: 36, color: AppTheme.darkTextSecondary),
                                    const SizedBox(height: 8),
                                    const Text('No apps registered yet.', style: TextStyle(color: AppTheme.darkTextSecondary)),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () => AppFormDialog.show(context),
                                      child: const Text('Register App Now'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: apps.take(5).length,
                              separatorBuilder: (context, index) => const Divider(height: 16),
                              itemBuilder: (context, idx) {
                                final app = apps[idx];
                                final quality = app.listingQuality;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryIndigo.withOpacity(0.15),
                                    child: Text(app.name.isNotEmpty ? app.name[0].toUpperCase() : 'A',
                                        style: const TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text(
                                    '${app.packageName} • ${app.category}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentEmerald.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${quality.score}% Quality',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.accentEmerald, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.arrow_forward_ios, size: 14),
                                        onPressed: () => AppDetailsDialog.show(context, app),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: quickActionsWidget),
                      const SizedBox(width: 16),
                      Expanded(flex: 6, child: recentAppsWidget),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      quickActionsWidget,
                      const SizedBox(height: 16),
                      recentAppsWidget,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 16, color: accentColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          child: Text(buttonText, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildFirstRunCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryIndigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rocket_launch, color: AppTheme.primaryIndigo, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to AppGrowth Studio — Zero-Cost Organic Marketing',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This platform operates 100% locally on your Windows desktop with SQLite persistence. '
                  'No subscriptions, no cloud databases, and no forced paid API keys. '
                  'Start by registering your Google Play Store application to begin keyword research and campaign generation.',
                  style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Register Your App Now'),
                  onPressed: () => AppFormDialog.show(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
