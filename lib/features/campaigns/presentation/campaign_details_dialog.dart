import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/utm_builder.dart';
import '../../apps/models/app_model.dart';
import '../models/campaign_model.dart';

class CampaignDetailsDialog extends StatelessWidget {
  final CampaignModel campaign;
  final AppModel? app;

  const CampaignDetailsDialog({
    super.key,
    required this.campaign,
    this.app,
  });

  static void show(BuildContext context, {required CampaignModel campaign, AppModel? app}) {
    showDialog(
      context: context,
      builder: (context) => CampaignDetailsDialog(campaign: campaign, app: app),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 680),
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
                        child: const Icon(Icons.campaign, color: AppTheme.primaryIndigo, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            campaign.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'App: ${app?.name ?? "Linked Application"} • Status: ${campaign.status.toUpperCase()}',
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
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview details
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildCard(
                              context,
                              title: 'Campaign Objective & Schedule',
                              children: [
                                _buildRow('Objective', campaign.objective),
                                _buildRow('Frequency', campaign.postingFrequency ?? 'Not specified'),
                                _buildRow('Timeline', '${campaign.startDate ?? "TBD"} to ${campaign.endDate ?? "TBD"}'),
                                _buildRow('Target Country', campaign.targetCountry ?? 'Global'),
                                _buildRow('Language', campaign.language ?? 'en'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildCard(
                              context,
                              title: 'Audience & Platforms',
                              children: [
                                _buildRow('Audience Persona', campaign.targetAudience ?? 'Broad audience'),
                                const SizedBox(height: 8),
                                const Text('Target Platforms:', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: campaign.platforms.map((p) => Chip(
                                    label: Text(p, style: const TextStyle(fontSize: 11)),
                                    backgroundColor: AppTheme.accentCyan.withOpacity(0.12),
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Themes & Content Angles
                      if (campaign.contentThemes.isNotEmpty) ...[
                        const Text('Content Themes & Planned Angles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: campaign.contentThemes.map((th) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.accentAmber),
                                const SizedBox(width: 6),
                                Text(th, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Campaign-Specific UTM Attribution Links (Section 17)
                      if (app != null) ...[
                        const Text('Campaign-Specific Google Play Attribution Links (UTM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text('Use these customized Play Store links in your video descriptions and bio links to measure referral traffic.', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                        const SizedBox(height: 10),
                        ...campaign.platforms.map((platform) {
                          final utmUrl = UtmBuilder.buildPlayStoreUtmUrl(
                            basePlayStoreUrl: app!.playStoreUrl,
                            utmSource: platform.toLowerCase(),
                            utmMedium: UtmBuilder.getSuggestedMediumForPlatform(platform),
                            utmCampaign: campaign.name.replaceAll(' ', '_'),
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(platform, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    utmUrl,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  tooltip: 'Copy UTM Link',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: utmUrl));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Copied $platform campaign link')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      if (campaign.notes != null && campaign.notes!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text('Strategy Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Text(campaign.notes!, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
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

  Widget _buildCard(BuildContext context, {required String title, required List<Widget> children}) {
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

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
