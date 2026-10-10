import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../apps/models/app_model.dart';
import '../apps/presentation/app_form_dialog.dart';
import '../apps/presentation/apps_screen.dart';
import '../apps/providers/app_providers.dart';
import '../campaigns/presentation/campaigns_screen.dart';
import '../content_studio/presentation/content_studio_screen.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../keywords/presentation/keyword_explorer_screen.dart';
import '../keywords/presentation/market_research_screen.dart';
import '../media_library/presentation/media_library_screen.dart';
import '../publishing/presentation/publishing_queue_screen.dart';
import '../publishing/presentation/social_accounts_screen.dart';
import '../analytics/presentation/analytics_screen.dart';
import '../../core/logging/activity_logs_screen.dart';
import '../settings/presentation/settings_screen.dart';
import '../autopilot/presentation/autopilot_studio_screen.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);
final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final themeMode = ref.watch(themeModeProvider);
    final appsListAsync = ref.watch(appsListProvider);
    final selectedApp = ref.watch(selectedAppProvider);

    final navItems = [
      _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      _NavItem(Icons.apps_outlined, Icons.apps, 'My Apps'),
      _NavItem(Icons.travel_explore_outlined, Icons.travel_explore, 'Market Research'),
      _NavItem(Icons.tag_outlined, Icons.tag, 'Keyword Explorer'),
      _NavItem(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Content Studio'),
      _NavItem(Icons.photo_library_outlined, Icons.photo_library, 'Media Library'),
      _NavItem(Icons.campaign_outlined, Icons.campaign, 'Campaign Planner'),
      _NavItem(Icons.schedule_send_outlined, Icons.schedule_send, 'Publishing Queue'),
      _NavItem(Icons.account_tree_outlined, Icons.account_tree, 'Social Accounts'),
      _NavItem(Icons.insights_outlined, Icons.insights, 'Analytics'),
      _NavItem(Icons.rocket_launch_outlined, Icons.rocket_launch, 'Autopilot Studio'),
      _NavItem(Icons.list_alt_outlined, Icons.list_alt, 'Activity Logs'),
      _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Collapsible Left Navigation Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCollapsed ? 72 : 240,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                // Brand Header
                Container(
                  height: 64,
                  padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryIndigo, AppTheme.accentCyan],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                      ),
                      if (!isCollapsed) ...[
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AppGrowth',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: -0.3),
                              ),
                              Text(
                                'Studio Desktop',
                                style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Navigation Items List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    itemCount: navItems.length,
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      final isSelected = selectedIndex == index;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: InkWell(
                          onTap: () => ref.read(selectedNavIndexProvider.notifier).state = index,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 42,
                            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 14 : 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryIndigo.withOpacity(0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(color: AppTheme.primaryIndigo.withOpacity(0.3))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  size: 19,
                                  color: isSelected ? AppTheme.primaryIndigo : AppTheme.darkTextSecondary,
                                ),
                                if (!isCollapsed) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: isSelected ? Theme.of(context).colorScheme.onSurface : AppTheme.darkTextSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 1),

                // Sidebar Toggle at bottom
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                    children: [
                      if (!isCollapsed)
                        const Expanded(
                          child: Text(
                            'v1.0.0 • Local SQLite',
                            style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      IconButton(
                        icon: Icon(isCollapsed ? Icons.chevron_right : Icons.chevron_left, size: 20),
                        tooltip: isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                        onPressed: () => ref.read(sidebarCollapsedProvider.notifier).state = !isCollapsed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content Area & Desktop Topbar
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Active App Selector Dropdown
                      Row(
                        children: [
                          const Icon(Icons.android, size: 18, color: AppTheme.primaryIndigo),
                          const SizedBox(width: 8),
                          appsListAsync.maybeWhen(
                            data: (apps) {
                              if (apps.isEmpty) {
                                return const Text(
                                  'No App Selected',
                                  style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                                );
                              }
                              return DropdownButton<AppModel>(
                                value: selectedApp != null && apps.any((a) => a.id == selectedApp.id)
                                    ? apps.firstWhere((a) => a.id == selectedApp.id)
                                    : apps.first,
                                underline: const SizedBox.shrink(),
                                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                items: apps.map((app) {
                                  return DropdownMenuItem<AppModel>(
                                    value: app,
                                    child: Text(
                                      app.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (app) {
                                  if (app != null) {
                                    ref.read(selectedAppProvider.notifier).state = app;
                                  }
                                },
                              );
                            },
                            orElse: () => const Text('Loading apps...', style: TextStyle(fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Add App', style: TextStyle(fontSize: 12)),
                            onPressed: () => AppFormDialog.show(context),
                          ),
                        ],
                      ),

                      // Actions: Theme switch, System status badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentEmerald.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.shield_outlined, size: 14, color: AppTheme.accentEmerald),
                                SizedBox(width: 4),
                                Text(
                                  'Local-First & Offline Ready',
                                  style: TextStyle(fontSize: 11, color: AppTheme.accentEmerald, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          IconButton(
                            icon: Icon(
                              themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                              size: 20,
                            ),
                            tooltip: 'Toggle Theme',
                            onPressed: () {
                              ref.read(themeModeProvider.notifier).state =
                                  themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Screen body corresponding to selected sidebar tab
                Expanded(
                  child: _buildCurrentScreen(selectedIndex, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen(int index, WidgetRef ref) {
    switch (index) {
      case 0:
        return DashboardScreen(
          onNavigateTab: (idx) => ref.read(selectedNavIndexProvider.notifier).state = idx,
        );
      case 1:
        return const AppsScreen();
      case 2:
        return const MarketResearchScreen();
      case 3:
        return const KeywordExplorerScreen();
      case 4:
        return const ContentStudioScreen();
      case 5:
        return const MediaLibraryScreen();
      case 6:
        return const CampaignsScreen();
      case 7:
        return const PublishingQueueScreen();
      case 8:
        return const SocialAccountsScreen();
      case 9:
        return const AnalyticsScreen();
      case 10:
        return const AutopilotStudioScreen();
      case 11:
        return const ActivityLogsScreen();
      case 12:
        return const SettingsScreen();
      default:
        return const AppsScreen();
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String title;

  _NavItem(this.icon, this.activeIcon, this.title);
}
