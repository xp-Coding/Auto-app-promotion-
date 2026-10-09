import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/providers/app_providers.dart';
import '../domain/keyword_relevance_scorer.dart';
import '../models/keyword_model.dart';
import '../providers/keyword_providers.dart';
import 'keyword_form_dialog.dart';
import 'keyword_import_export_dialog.dart';

class KeywordExplorerScreen extends ConsumerWidget {
  const KeywordExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keywordsAsync = ref.watch(keywordsListProvider);
    final selectedApp = ref.watch(selectedAppProvider);
    final intentFilter = ref.watch(keywordIntentFilterProvider);

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
                          'Keyword Explorer',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        keywordsAsync.maybeWhen(
                          data: (kws) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryIndigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${kws.length} keywords',
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
                          ? 'Targeting organic search terms for ${selectedApp.name}'
                          : 'Select an application from the top bar to explore keywords.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (selectedApp != null) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Generate Ideas'),
                        onPressed: () async {
                          final suggestions = KeywordRelevanceScorer.generateSuggestedKeywords(selectedApp);
                          final now = DateTime.now().toUtc();
                          final todayStr = DateFormat('yyyy-MM-dd').format(now);
                          final notifier = ref.read(keywordsListProvider.notifier);

                          for (final sug in suggestions) {
                            final exp = KeywordRelevanceScorer.calculateScore(
                              keyword: sug,
                              app: selectedApp,
                              intent: 'informational',
                              source: 'local_generator',
                            );
                            await notifier.addKeyword(
                              KeywordModel(
                                id: const Uuid().v4(),
                                appId: selectedApp.id,
                                keyword: sug,
                                topicCluster: 'Feature Discovery',
                                intent: 'informational',
                                relevanceScore: exp.score,
                                source: 'local_generator',
                                retrievalDate: todayStr,
                                createdAt: now,
                              ),
                            );
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Added ${suggestions.length} organic keyword suggestions!')),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.import_export, size: 16),
                        label: const Text('CSV Import / Export'),
                        onPressed: () => KeywordImportExportDialog.show(context, selectedApp),
                      ),
                      const SizedBox(width: 10),
                    ],
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Keyword'),
                      onPressed: () => KeywordFormDialog.show(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search & Filter Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search keyword, cluster, or notes...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (val) {
                          ref.read(keywordSearchQueryProvider.notifier).state = val;
                          ref.read(keywordsListProvider.notifier).loadKeywords();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        value: intentFilter,
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Intents')),
                          DropdownMenuItem(value: 'informational', child: Text('Informational')),
                          DropdownMenuItem(value: 'commercial', child: Text('Commercial')),
                          DropdownMenuItem(value: 'navigational', child: Text('Navigational')),
                          DropdownMenuItem(value: 'transactional', child: Text('Transactional')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(keywordIntentFilterProvider.notifier).state = val;
                            ref.read(keywordsListProvider.notifier).loadKeywords();
                          }
                        },
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      onPressed: () => ref.read(keywordsListProvider.notifier).loadKeywords(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Keywords List
            Expanded(
              child: keywordsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading keywords: $err')),
                data: (keywords) {
                  if (keywords.isEmpty) {
                    return _buildEmptyState(context, selectedApp);
                  }

                  return Card(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: keywords.length,
                      separatorBuilder: (context, index) => const Divider(height: 12),
                      itemBuilder: (context, idx) {
                        final kw = keywords[idx];
                        return _KeywordRow(keyword: kw);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, dynamic app) {
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
                child: const Icon(Icons.travel_explore, size: 48, color: AppTheme.accentCyan),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Keywords Stored for this Application',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add long-tail keywords, import research lists from CSV, or automatically generate suggestions based on your app\'s registered features.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Keyword'),
                    onPressed: () => KeywordFormDialog.show(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeywordRow extends ConsumerWidget {
  final KeywordModel keyword;

  const _KeywordRow({required this.keyword});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Keyword text
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  keyword.keyword,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (keyword.notes != null && keyword.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    keyword.notes!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Cluster pill
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                keyword.topicCluster ?? 'General',
                style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Intent badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              keyword.intent.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryIndigo),
            ),
          ),
          const SizedBox(width: 14),

          // Relevance Score
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: keyword.relevanceScore / 100,
                      minHeight: 6,
                      color: keyword.relevanceScore >= 70 ? AppTheme.accentEmerald : AppTheme.accentAmber,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${keyword.relevanceScore.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Source & Date
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  keyword.source,
                  style: const TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.w500),
                ),
                Text(
                  keyword.retrievalDate,
                  style: const TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary),
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy Keyword',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: keyword.keyword));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Keyword copied')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.accentRose),
                tooltip: 'Delete Keyword',
                onPressed: () async {
                  await ref.read(keywordsListProvider.notifier).deleteKeyword(keyword.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
