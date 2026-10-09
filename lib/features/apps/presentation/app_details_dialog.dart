import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/url_launcher.dart';
import '../models/app_model.dart';
import 'app_form_dialog.dart';

class AppDetailsDialog extends StatelessWidget {
  final AppModel app;

  const AppDetailsDialog({super.key, required this.app});

  static void show(BuildContext context, AppModel app) {
    showDialog(
      context: context,
      builder: (context) => AppDetailsDialog(app: app),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quality = app.listingQuality;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
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
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primaryIndigo.withOpacity(0.15),
                        child: Text(
                          app.name.isNotEmpty ? app.name[0].toUpperCase() : 'A',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryIndigo,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                app.name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (app.isArchived) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentAmber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Archived', style: TextStyle(fontSize: 11, color: AppTheme.accentAmber)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            app.packageName,
                            style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Edit Application',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          Navigator.of(context).pop();
                          AppFormDialog.show(context, initialApp: app);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Action Bar
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                app.playStoreUrl,
                                style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.copy, size: 14),
                              label: const Text('Copy URL', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: app.playStoreUrl));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Play Store URL copied to clipboard')),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_browser, size: 14),
                              label: const Text('Open in Browser', style: TextStyle(fontSize: 12)),
                              onPressed: () => AppUrlLauncher.openUrl(app.playStoreUrl),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Metadata Grid
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              context,
                              title: 'Overview & Target Audience',
                              children: [
                                _buildField('Category', app.category),
                                _buildField('Target Audience', app.targetAudience ?? 'Not specified'),
                                _buildField('Brand Tone', app.brandTone ?? 'Informative'),
                                _buildField('Preferred CTA', app.preferredCta ?? 'Install now'),
                                _buildField('Countries', app.targetCountries.join(', ')),
                                _buildField('Languages', app.supportedLanguages.join(', ')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildInfoCard(
                              context,
                              title: 'Listing Quality (${quality.score}%)',
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: quality.score / 100,
                                        minHeight: 6,
                                        color: quality.score >= 70 ? AppTheme.accentEmerald : AppTheme.accentAmber,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${quality.score}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...quality.items.take(4).map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.isPassed ? Icons.check_circle : Icons.warning_amber_rounded,
                                          size: 14,
                                          color: item.isPassed ? AppTheme.accentEmerald : AppTheme.accentAmber,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(item.title, style: const TextStyle(fontSize: 11)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Descriptions
                      if (app.shortDescription != null && app.shortDescription!.isNotEmpty) ...[
                        _buildSectionHeader('Short Description (${app.shortDescription!.length}/80)'),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Text(app.shortDescription!, style: const TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (app.fullDescription != null && app.fullDescription!.isNotEmpty) ...[
                        _buildSectionHeader('Full Description'),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Text(
                            app.fullDescription!,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Features & USPs
                      if (app.mainFeatures.isNotEmpty) ...[
                        _buildSectionHeader('Key Features (${app.mainFeatures.length})'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: app.mainFeatures.map((f) => Chip(label: Text(f, style: const TextStyle(fontSize: 12)))).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (app.uniqueSellingPoints.isNotEmpty) ...[
                        _buildSectionHeader('Unique Selling Points (${app.uniqueSellingPoints.length})'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: app.uniqueSellingPoints.map((u) => Chip(
                            backgroundColor: AppTheme.primaryIndigo.withOpacity(0.12),
                            label: Text(u, style: const TextStyle(fontSize: 12, color: AppTheme.primaryIndigo)),
                          )).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Suggested Organic Campaign Angles (Derived from real fields)
                      _buildSectionHeader('Suggested Organic Angles (Generated from app profile)'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accentCyan.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAngleRow(
                              'Problem/Solution Hook:',
                              'Frustrated with complex tools? See how ${app.name} simplifies your daily routine.',
                            ),
                            const SizedBox(height: 6),
                            if (app.mainFeatures.isNotEmpty)
                              _buildAngleRow(
                                'Feature Showcase:',
                                'Deep dive into "${app.mainFeatures.first}" and how it boosts efficiency for ${app.targetAudience ?? "users"}.',
                              ),
                            const SizedBox(height: 6),
                            if (app.uniqueSellingPoints.isNotEmpty)
                              _buildAngleRow(
                                'USP Comparison:',
                                'Why users switch to ${app.name}: ${app.uniqueSellingPoints.first}.',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkTextSecondary),
    );
  }

  Widget _buildAngleRow(String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentCyan),
        ),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
