import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/post_job_model.dart';
import '../providers/publishing_providers.dart';
import 'job_attempts_dialog.dart';

class PublishingQueueScreen extends ConsumerStatefulWidget {
  const PublishingQueueScreen({super.key});

  @override
  ConsumerState<PublishingQueueScreen> createState() => _PublishingQueueScreenState();
}

class _PublishingQueueScreenState extends ConsumerState<PublishingQueueScreen> {
  bool _isProcessing = false;

  Future<void> _handleProcessQueue() async {
    setState(() => _isProcessing = true);
    try {
      final summary = await ref.read(publishingJobsListProvider.notifier).processQueueNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Queue processed: ${summary.succeeded} succeeded, ${summary.failed} failed, ${summary.retried} retrying, ${summary.skippedAlreadyPublished} skipped.',
            ),
            backgroundColor: summary.failed > 0 ? AppTheme.accentAmber : AppTheme.accentEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error running queue: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(publishingJobsListProvider);
    final quotaAsync = ref.watch(youtubeQuotaStatusProvider);
    final currentStatusFilter = ref.watch(queueStatusFilterProvider);
    final currentPlatformFilter = ref.watch(queuePlatformFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header & Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Publishing Queue & Job Engine',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Persistent SQLite job scheduler with idempotency protection and bounded exponential retries.',
                      style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      onPressed: () {
                        ref.read(publishingJobsListProvider.notifier).refreshJobs();
                        ref.invalidate(youtubeQuotaStatusProvider);
                      },
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryIndigo,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.play_arrow, size: 18),
                      label: Text(_isProcessing ? 'Processing Queue...' : 'Process Due Jobs Now'),
                      onPressed: _isProcessing ? null : _handleProcessQueue,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metrics & Quota Gauges
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Queued',
                    value: jobsAsync.value?.length.toString() ?? '...',
                    icon: Icons.all_inbox_outlined,
                    color: AppTheme.primaryIndigo,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Pending Due',
                    value: jobsAsync.value?.where((j) => j.isPending).length.toString() ?? '...',
                    icon: Icons.hourglass_top_outlined,
                    color: AppTheme.accentCyan,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Succeeded',
                    value: jobsAsync.value?.where((j) => j.isSucceeded).length.toString() ?? '...',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.accentEmerald,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Failed / Action Needed',
                    value: jobsAsync.value?.where((j) => j.isFailed || j.isManualRequired).length.toString() ?? '...',
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.accentRose,
                  ),
                ),
                const SizedBox(width: 14),
                // YouTube Quota Gauge Card
                Expanded(
                  flex: 2,
                  child: quotaAsync.when(
                    loading: () => const Card(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))),
                    error: (err, stack) => const SizedBox(),
                    data: (quota) {
                      final percent = (quota.usedToday / quota.dailyLimit).clamp(0.0, 1.0);
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.video_collection, color: AppTheme.platformYoutube, size: 16),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'YouTube Daily Quota',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${quota.usedToday} / ${quota.dailyLimit} units',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: quota.isExceeded ? AppTheme.accentRose : AppTheme.darkTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: percent,
                                backgroundColor: Theme.of(context).dividerColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  quota.isExceeded
                                      ? AppTheme.accentRose
                                      : percent > 0.8
                                          ? AppTheme.accentAmber
                                          : AppTheme.accentEmerald,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                minHeight: 6,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${quota.remaining} units remaining • Resets midnight PT',
                                style: const TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filters row
            Row(
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    _buildStatusFilterChip('all', 'All Statuses', currentStatusFilter),
                    _buildStatusFilterChip('pending', 'Pending', currentStatusFilter),
                    _buildStatusFilterChip('running', 'Running', currentStatusFilter),
                    _buildStatusFilterChip('succeeded', 'Succeeded', currentStatusFilter),
                    _buildStatusFilterChip('manual_required', 'Manual Required', currentStatusFilter),
                    _buildStatusFilterChip('failed', 'Failed', currentStatusFilter),
                  ],
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: currentPlatformFilter,
                  dropdownColor: Theme.of(context).cardColor,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Platforms')),
                    DropdownMenuItem(value: 'youtube', child: Text('YouTube')),
                    DropdownMenuItem(value: 'tiktok', child: Text('TikTok')),
                    DropdownMenuItem(value: 'facebook', child: Text('Facebook')),
                    DropdownMenuItem(value: 'instagram', child: Text('Instagram')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(queuePlatformFilterProvider.notifier).state = val;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Queue List
            Expanded(
              child: jobsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error loading queue: $err')),
                data: (jobs) {
                  if (jobs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Theme.of(context).hintColor),
                          const SizedBox(height: 16),
                          const Text(
                            'Publishing queue is empty',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Create posts in Content Studio and schedule them to this queue.',
                            style: TextStyle(color: AppTheme.darkTextSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: jobs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      return _buildJobCard(job);
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

  Widget _buildStatusFilterChip(String value, String label, String current) {
    final isSelected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ref.read(queueStatusFilterProvider.notifier).state = value,
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(PostJobModel job) {
    final platformColor = _getPlatformColor(job.targetPlatform);
    final isFailed = job.isFailed;
    final isManual = job.isManualRequired;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isFailed
              ? AppTheme.accentRose.withOpacity(0.4)
              : isManual
                  ? AppTheme.accentAmber.withOpacity(0.4)
                  : Theme.of(context).dividerColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Platform Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: platformColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getPlatformIcon(job.targetPlatform), color: platformColor, size: 20),
                ),
                const SizedBox(width: 12),
                // Platform & scheduled date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            job.targetPlatform.toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: platformColor),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(job.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              job.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(job.status),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (job.retryCount > 0)
                            Text(
                              'Retry ${job.retryCount}/${job.maxRetries}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.accentAmber),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled for: ${DateFormat('MMM d, yyyy • HH:mm').format(job.scheduledAt.toLocal())}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Logs'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => JobAttemptsDialog(job: job),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    if (job.canRetry || isManual || isFailed)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accentAmber,
                          foregroundColor: Colors.black,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry Now'),
                        onPressed: () => ref.read(publishingJobsListProvider.notifier).retryJob(job.id),
                      ),
                    if (job.isPending) ...[
                      IconButton(
                        tooltip: 'Cancel Job',
                        icon: const Icon(Icons.cancel_outlined, size: 20, color: AppTheme.darkTextSecondary),
                        onPressed: () => ref.read(publishingJobsListProvider.notifier).cancelJob(job.id),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            // Error display banner
            if (job.lastErrorCode != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentRose.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentRose.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppTheme.accentRose),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '[${job.lastErrorCode}] ${job.lastErrorMessage ?? ''}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.accentRose),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (job.nextRetryAt != null && job.isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppTheme.accentAmber),
                  const SizedBox(width: 6),
                  Text(
                    'Next automatic attempt: ${DateFormat('HH:mm:ss').format(job.nextRetryAt!.toLocal())}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.accentAmber),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'succeeded':
        return AppTheme.accentEmerald;
      case 'running':
        return AppTheme.accentCyan;
      case 'pending':
        return AppTheme.primaryIndigo;
      case 'manual_required':
        return AppTheme.accentAmber;
      case 'failed':
        return AppTheme.accentRose;
      default:
        return AppTheme.darkTextSecondary;
    }
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
