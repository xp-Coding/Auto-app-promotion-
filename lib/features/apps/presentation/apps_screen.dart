import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/url_launcher.dart';
import '../models/app_model.dart';
import '../providers/app_providers.dart';
import 'app_details_dialog.dart';
import 'app_form_dialog.dart';

class AppsScreen extends ConsumerWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(appsListProvider);
    final filterState = ref.watch(appsFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'My Applications',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        appsAsync.maybeWhen(
                          data: (apps) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryIndigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${apps.length} registered',
                              style: const TextStyle(
                                color: AppTheme.primaryIndigo,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage your Android applications, listing metadata, and Play Store profiles.',
                      style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Register New App'),
                  onPressed: () => AppFormDialog.show(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Search field
                    Expanded(
                      flex: 4,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by app name, package ID, or category...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          suffixIcon: filterState.searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    ref.read(appsFilterProvider.notifier).update(
                                          (state) => state.copyWith(searchQuery: ''),
                                        );
                                    ref.read(appsListProvider.notifier).loadApps();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          ref.read(appsFilterProvider.notifier).update(
                                (state) => state.copyWith(searchQuery: val),
                              );
                          ref.read(appsListProvider.notifier).loadApps();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Category dropdown
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        value: filterState.selectedCategory,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Categories')),
                          DropdownMenuItem(value: 'Productivity', child: Text('Productivity')),
                          DropdownMenuItem(value: 'Tools & Utilities', child: Text('Tools & Utilities')),
                          DropdownMenuItem(value: 'Education', child: Text('Education')),
                          DropdownMenuItem(value: 'Finance', child: Text('Finance')),
                          DropdownMenuItem(value: 'Health & Fitness', child: Text('Health & Fitness')),
                          DropdownMenuItem(value: 'Entertainment', child: Text('Entertainment')),
                          DropdownMenuItem(value: 'Social', child: Text('Social')),
                          DropdownMenuItem(value: 'Games', child: Text('Games')),
                        ],
                        onChanged: (cat) {
                          if (cat != null) {
                            ref.read(appsFilterProvider.notifier).update(
                                  (state) => state.copyWith(selectedCategory: cat),
                                );
                            ref.read(appsListProvider.notifier).loadApps();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Show Archived Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: filterState.showArchived,
                          onChanged: (val) {
                            ref.read(appsFilterProvider.notifier).update(
                                  (state) => state.copyWith(showArchived: val ?? false),
                                );
                            ref.read(appsListProvider.notifier).loadApps();
                          },
                        ),
                        const Text('Include Archived', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content Area
            Expanded(
              child: appsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40, color: AppTheme.accentRose),
                      const SizedBox(height: 12),
                      Text('Error loading apps: $err'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.read(appsListProvider.notifier).loadApps(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (apps) {
                  if (apps.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 440,
                      mainAxisExtent: 240,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return _AppCard(app: app);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Card(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.apps_outlined, size: 48, color: AppTheme.primaryIndigo),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Applications Registered Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Register your Android application using its Google Play listing URL. AppGrowth Studio will securely track metadata, evaluate listing quality, and generate targeted promotional campaigns.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Register Your First App'),
                onPressed: () => AppFormDialog.show(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppCard extends ConsumerWidget {
  final AppModel app;

  const _AppCard({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = app.listingQuality;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Avatar, Title, Package, Quality badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryIndigo.withOpacity(0.15),
                  child: Text(
                    app.name.isNotEmpty ? app.name[0].toUpperCase() : 'A',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryIndigo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.packageName,
                        style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getQualityColor(quality.score).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${quality.score}%',
                    style: TextStyle(
                      color: _getQualityColor(quality.score),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Middle: Category, Audience snippet, Features count
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(app.category, style: const TextStyle(fontSize: 10)),
                    ),
                    const SizedBox(width: 8),
                    if (app.mainFeatures.isNotEmpty)
                      Text(
                        '${app.mainFeatures.length} features',
                        style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                      ),
                    const Spacer(),
                    if (app.isArchived)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentAmber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Archived', style: TextStyle(fontSize: 10, color: AppTheme.accentAmber)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  app.shortDescription ?? (app.fullDescription != null && app.fullDescription!.length > 60
                      ? '${app.fullDescription!.substring(0, 60)}...'
                      : 'No description entered yet.'),
                  style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            // Bottom Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      tooltip: 'View Full Metadata & Campaign Angles',
                      onPressed: () => AppDetailsDialog.show(context, app),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit App',
                      onPressed: () => AppFormDialog.show(context, initialApp: app),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      tooltip: 'Open in Play Store',
                      onPressed: () => AppUrlLauncher.openUrl(app.playStoreUrl),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (val) async {
                    if (val == 'archive') {
                      await ref.read(appsListProvider.notifier).archiveApp(app.id, !app.isArchived);
                    } else if (val == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Application?'),
                          content: Text(
                            'Are you sure you want to delete "${app.name}"? This will permanently remove its local metadata and marketing campaigns.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(appsListProvider.notifier).deleteApp(app.id);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(app.isArchived ? 'Unarchive App' : 'Archive App'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete App', style: TextStyle(color: AppTheme.accentRose)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getQualityColor(int score) {
    if (score >= 80) return AppTheme.accentEmerald;
    if (score >= 60) return AppTheme.accentAmber;
    return AppTheme.accentRose;
  }
}
