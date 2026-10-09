import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/providers/app_providers.dart';
import '../models/content_post_model.dart';
import '../providers/content_studio_providers.dart';
import 'post_editor_dialog.dart';
import 'post_preview_dialog.dart';
import '../../publishing/providers/publishing_providers.dart';

class ContentStudioScreen extends ConsumerWidget {
  const ContentStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(contentPostsListProvider);
    final selectedApp = ref.watch(selectedAppProvider);
    final filterState = ref.watch(contentFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Content Studio',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        postsAsync.maybeWhen(
                          data: (posts) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryIndigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${posts.length} drafts',
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
                          ? 'Generating tailored promotional copy for ${selectedApp.name}'
                          : 'Select an application from the top bar to filter content.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create New Draft'),
                  onPressed: () => PostEditorDialog.show(context),
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
                    const Text('Platform:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        value: filterState.selectedPlatform,
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Platforms')),
                          DropdownMenuItem(value: 'YouTube', child: Text('YouTube')),
                          DropdownMenuItem(value: 'TikTok', child: Text('TikTok')),
                          DropdownMenuItem(value: 'Instagram', child: Text('Instagram')),
                          DropdownMenuItem(value: 'Facebook', child: Text('Facebook')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(contentFilterProvider.notifier).update((s) => s.copyWith(selectedPlatform: val));
                            ref.read(contentPostsListProvider.notifier).loadPosts();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text('Status:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        value: filterState.selectedStatus,
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'draft', child: Text('Draft')),
                          DropdownMenuItem(value: 'ready', child: Text('Ready')),
                          DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(contentFilterProvider.notifier).update((s) => s.copyWith(selectedStatus: val));
                            ref.read(contentPostsListProvider.notifier).loadPosts();
                          }
                        },
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      onPressed: () => ref.read(contentPostsListProvider.notifier).loadPosts(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content Grid
            Expanded(
              child: postsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading posts: $err')),
                data: (posts) {
                  if (posts.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 440,
                      mainAxisExtent: 260,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, idx) {
                      final post = posts[idx];
                      return _PostCard(post: post);
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
                  color: AppTheme.accentCyan.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 48, color: AppTheme.accentCyan),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Promotional Drafts Saved Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create or generate platform-specific video scripts, captions, reels, and stories with customized Play Store UTM attribution links.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create First Draft'),
                onPressed: () => PostEditorDialog.show(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  final ContentPostModel post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platformColor = _getPlatformColor(post.targetPlatform);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Platform chip, Format chip, Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: platformColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        post.targetPlatform,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: platformColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(post.format.replaceAll('_', ' '), style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(post.status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    post.status.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getStatusColor(post.status)),
                  ),
                ),
              ],
            ),

            // Middle: Title & snippet
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.title != null && post.title!.isNotEmpty) ...[
                  Text(
                    post.title!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  post.bodyText,
                  style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            // Bottom: Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      tooltip: 'Preview & Copy Post',
                      onPressed: () => PostPreviewDialog.show(context, post),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Draft',
                      onPressed: () => PostEditorDialog.show(context, initialPost: post),
                    ),
                    IconButton(
                      icon: const Icon(Icons.schedule_send_outlined, size: 18, color: AppTheme.primaryIndigo),
                      tooltip: 'Schedule to Publishing Queue',
                      onPressed: () async {
                        await ref.read(publishingJobsListProvider.notifier).enqueueJob(
                          contentId: post.id,
                          targetPlatform: post.targetPlatform,
                          campaignId: post.campaignId,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Scheduled to ${post.targetPlatform.toUpperCase()} publishing queue!'),
                              backgroundColor: AppTheme.accentEmerald,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.accentRose),
                  tooltip: 'Delete Draft',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Draft?'),
                        content: const Text('Are you sure you want to delete this promotional draft?'),
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
                      await ref.read(contentPostsListProvider.notifier).deletePost(post.id);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return Colors.redAccent;
      case 'tiktok':
        return Colors.pinkAccent;
      case 'instagram':
        return Colors.purpleAccent;
      case 'facebook':
        return Colors.blueAccent;
      default:
        return AppTheme.primaryIndigo;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ready':
        return AppTheme.accentEmerald;
      case 'scheduled':
        return AppTheme.accentCyan;
      default:
        return AppTheme.darkTextSecondary;
    }
  }
}
