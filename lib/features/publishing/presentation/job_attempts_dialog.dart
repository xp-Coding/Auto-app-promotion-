import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/post_job_model.dart';
import '../providers/publishing_providers.dart';

class JobAttemptsDialog extends ConsumerWidget {
  final PostJobModel job;

  const JobAttemptsDialog({super.key, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(jobAttemptsProvider(job.id));

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryIndigo.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.history_edu_outlined, color: AppTheme.primaryIndigo, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Publication Execution Log',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Job ID: ${job.id.substring(0, 8)}... • Platform: ${job.targetPlatform.toUpperCase()}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Job status summary banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Job Status', job.status.toUpperCase(), _getStatusColor(job.status)),
                    _buildSummaryItem('Retries', '${job.retryCount} / ${job.maxRetries}', null),
                    _buildSummaryItem('Scheduled', DateFormat('MMM d, HH:mm').format(job.scheduledAt.toLocal()), null),
                    if (job.nextRetryAt != null)
                      _buildSummaryItem(
                        'Next Retry',
                        DateFormat('HH:mm:ss').format(job.nextRetryAt!.toLocal()),
                        AppTheme.accentAmber,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Attempts List
              const Text(
                'Attempt History',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: attemptsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error loading attempts: $err')),
                  data: (attempts) {
                    if (attempts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hourglass_empty, size: 40, color: Theme.of(context).hintColor),
                            const SizedBox(height: 12),
                            const Text(
                              'No execution attempts recorded yet.\nJob will run when due.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.darkTextSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: attempts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final attempt = attempts[index];
                        final isSuccess = attempt.status == 'success';
                        final isSkipped = attempt.status == 'skipped_idempotent';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSuccess
                                  ? AppTheme.accentEmerald.withOpacity(0.4)
                                  : isSkipped
                                      ? AppTheme.accentCyan.withOpacity(0.4)
                                      : AppTheme.accentRose.withOpacity(0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isSuccess
                                            ? Icons.check_circle_outline
                                            : isSkipped
                                                ? Icons.verified_outlined
                                                : Icons.error_outline,
                                        size: 18,
                                        color: isSuccess
                                            ? AppTheme.accentEmerald
                                            : isSkipped
                                                ? AppTheme.accentCyan
                                                : AppTheme.accentRose,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Attempt #${attempt.attemptNumber}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isSuccess
                                                  ? AppTheme.accentEmerald
                                                  : isSkipped
                                                      ? AppTheme.accentCyan
                                                      : AppTheme.accentRose)
                                              .withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          attempt.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSuccess
                                                ? AppTheme.accentEmerald
                                                : isSkipped
                                                    ? AppTheme.accentCyan
                                                    : AppTheme.accentRose,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    DateFormat('MMM d, HH:mm:ss').format(attempt.attemptedAt.toLocal()),
                                    style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                                  ),
                                ],
                              ),
                              if (attempt.remoteId != null) ...[
                                const SizedBox(height: 8),
                                SelectableText(
                                  'Remote Publication ID: ${attempt.remoteId}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.accentCyan, fontFamily: 'monospace'),
                                ),
                              ],
                              if (attempt.errorCode != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentRose.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.accentRose),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '[${attempt.errorCode}] ${attempt.errorMessage ?? ''}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.accentRose),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color? color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
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
}
