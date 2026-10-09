import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/social_account_model.dart';
import '../providers/publishing_providers.dart';
import 'youtube_credentials_dialog.dart';

class SocialAccountsScreen extends ConsumerWidget {
  const SocialAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(socialAccountsListProvider);
    final quotaAsync = ref.watch(youtubeQuotaStatusProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected Social Accounts & API Integrations',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage official OAuth 2.0 connections, API quotas, and platform credentials.',
                      style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh Accounts'),
                  onPressed: () {
                    ref.read(socialAccountsListProvider.notifier).refreshAccounts();
                    ref.invalidate(youtubeQuotaStatusProvider);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quota and Policy Reminder Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentEmerald.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security, color: AppTheme.accentEmerald, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Strict Compliance & Security Guarantee',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'AppGrowth Studio connects exclusively through official developer APIs. No passwords or scraping. All credentials and tokens reside encrypted on your local computer.',
                          style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Official Platform Adapters Grid
            accountsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading accounts: $err')),
              data: (accounts) {
                final youtubeAccount = accounts.cast<SocialAccountModel?>().firstWhere(
                      (a) => a?.platform == 'youtube',
                      orElse: () => null,
                    );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Official Platform Adapters',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 800;
                        return GridView.count(
                          crossAxisCount: isWide ? 2 : 1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: isWide ? 1.7 : 1.9,
                          children: [
                            // 1. YouTube Card (Active Official Adapter)
                            _buildYouTubeCard(context, ref, youtubeAccount, quotaAsync),

                            // 2. TikTok Card (Modular Architecture Placeholder)
                            _buildModularCard(
                              context: context,
                              platformName: 'TikTok',
                              platformId: 'tiktok',
                              color: AppTheme.platformTiktok,
                              icon: Icons.music_video,
                              description: 'TikTok Content Posting API for business and personal accounts.',
                              statusText: 'Modular Adapter — Independent Milestone',
                            ),

                            // 3. Instagram Card (Modular Architecture Placeholder)
                            _buildModularCard(
                              context: context,
                              platformName: 'Instagram',
                              platformId: 'instagram',
                              color: AppTheme.platformInstagram,
                              icon: Icons.camera_alt_outlined,
                              description: 'Instagram Graph API for Reels and Carousel image publishing.',
                              statusText: 'Modular Adapter — Independent Milestone',
                            ),

                            // 4. Facebook Card (Modular Architecture Placeholder)
                            _buildModularCard(
                              context: context,
                              platformName: 'Facebook',
                              platformId: 'facebook',
                              color: AppTheme.platformFacebook,
                              icon: Icons.thumb_up_alt_outlined,
                              description: 'Meta Graph API for Facebook Page feed post management.',
                              statusText: 'Modular Adapter — Independent Milestone',
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYouTubeCard(
    BuildContext context,
    WidgetRef ref,
    SocialAccountModel? account,
    AsyncValue quotaAsync,
  ) {
    final isConnected = account != null && account.isConnected;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isConnected ? AppTheme.platformYoutube.withOpacity(0.5) : Theme.of(context).dividerColor,
          width: isConnected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.platformYoutube.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.video_collection, color: AppTheme.platformYoutube, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'YouTube Data API v3',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isConnected ? AppTheme.accentEmerald : AppTheme.darkTextSecondary).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isConnected ? 'CONNECTED' : 'DISCONNECTED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isConnected ? AppTheme.accentEmerald : AppTheme.darkTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConnected
                            ? 'Channel: ${account.accountName} (${account.accountId})'
                            : 'Upload promotional videos & YouTube Shorts directly to your channel',
                        style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isConnected) ...[
              // Channel metrics & sync info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subscribers: ${account.metadata['subscriberCount'] ?? 'N/A'} • Videos: ${account.metadata['videoCount'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                  ),
                  if (account.lastSyncedAt != null)
                    Text(
                      'Synced: ${DateFormat('MMM d, HH:mm').format(account.lastSyncedAt!.toLocal())}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                    ),
                ],
              ),
            ],

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isConnected) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.link_off, size: 16, color: AppTheme.accentRose),
                    label: const Text('Disconnect', style: TextStyle(color: AppTheme.accentRose)),
                    onPressed: () => ref.read(socialAccountsListProvider.notifier).disconnect('youtube'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isConnected ? Theme.of(context).cardColor : AppTheme.platformYoutube,
                    foregroundColor: isConnected ? Theme.of(context).colorScheme.onSurface : Colors.white,
                    side: isConnected ? BorderSide(color: Theme.of(context).dividerColor) : null,
                  ),
                  icon: const Icon(Icons.settings, size: 16),
                  label: Text(isConnected ? 'Configure Credentials' : 'Connect YouTube Channel'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const YouTubeCredentialsDialog(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModularCard({
    required BuildContext context,
    required String platformName,
    required String platformId,
    required Color color,
    required IconData icon,
    required String description,
    required String statusText,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            platformName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.darkTextSecondary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'MODULAR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                ),
                OutlinedButton(
                  onPressed: null, // Disabled until milestone activation
                  child: const Text('Configure'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
