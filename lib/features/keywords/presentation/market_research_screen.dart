import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/providers/app_providers.dart';
import '../providers/keyword_providers.dart';
import 'keyword_form_dialog.dart';

class MarketResearchScreen extends ConsumerWidget {
  const MarketResearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keywordsAsync = ref.watch(keywordsListProvider);
    final selectedApp = ref.watch(selectedAppProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
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
                    const Text(
                      'Market Research & Content Gaps',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedApp != null
                          ? 'Analyzing topic clusters and discovery intent for ${selectedApp.name}'
                          : 'Select an application from the top bar to view research insights.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Research Topic'),
                  onPressed: () => KeywordFormDialog.show(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ethical data disclosure card (Section 9 requirement)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryIndigo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppTheme.primaryIndigo, size: 22),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Zero-Fabrication Data Standard: AppGrowth Studio does not fabricate artificial Google Play search numbers. '
                      'Relevance scores reflect transparent qualitative semantic alignment between your application profile and organic search patterns.',
                      style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            keywordsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (e, _) => Text('Error loading research: $e'),
              data: (keywords) {
                // Compute intent counts
                final infoCount = keywords.where((k) => k.intent == 'informational').length;
                final commCount = keywords.where((k) => k.intent == 'commercial').length;
                final transCount = keywords.where((k) => k.intent == 'transactional').length;

                // Identify content gaps (features with no keywords matching)
                final uncoveredFeatures = <String>[];
                if (selectedApp != null) {
                  for (final feat in selectedApp.mainFeatures) {
                    final matched = keywords.any((k) => k.keyword.toLowerCase().contains(feat.toLowerCase()));
                    if (!matched) uncoveredFeatures.add(feat);
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Intent Breakdown Metrics
                    Row(
                      children: [
                        Expanded(
                          child: _buildIntentCard(
                            context,
                            title: 'Informational Topics',
                            count: infoCount,
                            desc: 'How-to guides, educational queries, and troubleshooting',
                            color: AppTheme.accentCyan,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildIntentCard(
                            context,
                            title: 'Commercial Intent',
                            count: commCount,
                            desc: 'Best apps, feature comparisons, and alternative searches',
                            color: AppTheme.primaryIndigo,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildIntentCard(
                            context,
                            title: 'Transactional / Download',
                            count: transCount,
                            desc: 'Direct install queries and store download phrases',
                            color: AppTheme.accentEmerald,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Content Gaps Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Uncovered Feature Content Gaps',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: uncoveredFeatures.isNotEmpty ? AppTheme.accentAmber.withOpacity(0.15) : AppTheme.accentEmerald.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    uncoveredFeatures.isNotEmpty ? '${uncoveredFeatures.length} Gaps Detected' : 'All Features Covered',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: uncoveredFeatures.isNotEmpty ? AppTheme.accentAmber : AppTheme.accentEmerald,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'These core features of your app currently lack targeting in your keyword catalog. Create targeted keywords or video topics to maximize discoverability:',
                              style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                            ),
                            const SizedBox(height: 14),
                            if (uncoveredFeatures.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('✓ Excellent! Your registered features have targeted keywords cataloged.', style: TextStyle(color: AppTheme.accentEmerald)),
                              )
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: uncoveredFeatures.map((feat) {
                                  return ActionChip(
                                    avatar: const Icon(Icons.add, size: 14),
                                    label: Text('Create topic for "$feat"'),
                                    onPressed: () => KeywordFormDialog.show(context, initialKeyword: 'best app with $feat'),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Suggested Video Script Hooks from Keyword Catalog
                    if (keywords.isNotEmpty) ...[
                      const Text(
                        'High-Scoring Video Hooks Derived from Topics',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: keywords.take(4).length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final kw = keywords[idx];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.videocam_outlined, color: AppTheme.accentCyan, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Hook Concept: "Why I stopped using standard tools and switched for ${kw.keyword}"',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Topic: ${kw.topicCluster ?? "General"} • Relevance: ${kw.relevanceScore.toStringAsFixed(0)}%',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntentCard(
    BuildContext context, {
    required String title,
    required int count,
    required String desc,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.bubble_chart_outlined, size: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('$count', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary), maxLines: 2),
          ],
        ),
      ),
    );
  }
}
