import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/providers/app_providers.dart';
import '../models/campaign_model.dart';
import '../providers/campaign_providers.dart';
import 'campaign_details_dialog.dart';
import 'campaign_form_dialog.dart';

class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsListProvider);
    final selectedApp = ref.watch(selectedAppProvider);
    final filterStatus = ref.watch(campaignFilterStatusProvider);

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
                          'Campaign Planner',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        campaignsAsync.maybeWhen(
                          data: (camps) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryIndigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${camps.length} campaigns',
                              style: const TextStyle(color: AppTheme.primaryIndigo, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedApp != null
                          ? 'Planning campaigns for ${selectedApp.name}'
                          : 'Select an application from the top bar to filter campaigns.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Campaign'),
                  onPressed: () => CampaignFormDialog.show(context),
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
                    const Text('Status Filter:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        value: filterStatus,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'draft', child: Text('Draft')),
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'paused', child: Text('Paused')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(campaignFilterStatusProvider.notifier).state = val;
                            ref.read(campaignsListProvider.notifier).loadCampaigns();
                          }
                        },
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      onPressed: () => ref.read(campaignsListProvider.notifier).loadCampaigns(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content Area
            Expanded(
              child: campaignsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading campaigns: $err')),
                data: (campaigns) {
                  if (campaigns.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 460,
                      mainAxisExtent: 260,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: campaigns.length,
                    itemBuilder: (context, idx) {
                      final camp = campaigns[idx];
                      return _CampaignCard(campaign: camp, app: selectedApp);
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
          width: 500,
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
                child: const Icon(Icons.campaign_outlined, size: 48, color: AppTheme.primaryIndigo),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Campaigns Planned Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your first marketing campaign to schedule video releases, platform-specific posts, and track UTM links for Google Play Store discovery.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create New Campaign'),
                onPressed: () => CampaignFormDialog.show(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignCard extends ConsumerWidget {
  final CampaignModel campaign;
  final dynamic app;

  const _CampaignCard({required this.campaign, this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor(campaign.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Name, Objective badge, Status badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        campaign.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        campaign.status.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    campaign.objective,
                    style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                  ),
                ),
              ],
            ),

            // Middle: Timeline, Platforms, Themes count
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: AppTheme.darkTextSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${campaign.startDate ?? "TBD"} → ${campaign.endDate ?? "TBD"}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: campaign.platforms.map((p) => Chip(
                    label: Text(p, style: const TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  )).toList(),
                ),
                if (campaign.contentThemes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${campaign.contentThemes.length} planned themes: ${campaign.contentThemes.first}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),

            // Bottom Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      tooltip: 'View Campaign & UTM Links',
                      onPressed: () => CampaignDetailsDialog.show(context, campaign: campaign, app: app),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Campaign',
                      onPressed: () => CampaignFormDialog.show(context, initialCampaign: campaign),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (val) async {
                    if (val == 'activate') {
                      await ref.read(campaignsListProvider.notifier).updateStatus(campaign.id, 'active');
                    } else if (val == 'pause') {
                      await ref.read(campaignsListProvider.notifier).updateStatus(campaign.id, 'paused');
                    } else if (val == 'complete') {
                      await ref.read(campaignsListProvider.notifier).updateStatus(campaign.id, 'completed');
                    } else if (val == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Campaign?'),
                          content: Text('Are you sure you want to delete "${campaign.name}"?'),
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
                        await ref.read(campaignsListProvider.notifier).deleteCampaign(campaign.id);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    if (campaign.status != 'active')
                      const PopupMenuItem(value: 'activate', child: Text('Mark as Active')),
                    if (campaign.status == 'active')
                      const PopupMenuItem(value: 'pause', child: Text('Pause Campaign')),
                    if (campaign.status != 'completed')
                      const PopupMenuItem(value: 'complete', child: Text('Mark as Completed')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Campaign', style: TextStyle(color: AppTheme.accentRose))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppTheme.accentEmerald;
      case 'paused':
        return AppTheme.accentAmber;
      case 'completed':
        return AppTheme.accentCyan;
      default:
        return AppTheme.darkTextSecondary;
    }
  }
}
