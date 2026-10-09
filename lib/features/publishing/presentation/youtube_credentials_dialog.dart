import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../adapters/youtube/youtube_token_storage.dart';
import '../providers/publishing_providers.dart';

class YouTubeCredentialsDialog extends ConsumerStatefulWidget {
  const YouTubeCredentialsDialog({super.key});

  @override
  ConsumerState<YouTubeCredentialsDialog> createState() => _YouTubeCredentialsDialogState();
}

class _YouTubeCredentialsDialogState extends ConsumerState<YouTubeCredentialsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _refreshTokenController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final tokenStorage = ref.read(youtubeTokenStorageProvider);
    final creds = await tokenStorage.getCredentials();
    if (creds != null && mounted) {
      setState(() {
        _clientIdController.text = creds.clientId;
        _clientSecretController.text = creds.clientSecret;
        _refreshTokenController.text = creds.refreshToken ?? '';
      });
    }
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _refreshTokenController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final success = await ref.read(socialAccountsListProvider.notifier).connectYouTube(
            clientId: _clientIdController.text.trim(),
            clientSecret: _clientSecretController.text.trim(),
            refreshToken: _refreshTokenController.text.trim().isNotEmpty ? _refreshTokenController.text.trim() : null,
          );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('YouTube account connected successfully!'),
              backgroundColor: AppTheme.accentEmerald,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credentials saved. Provide a valid refresh token to enable unattended publishing.'),
              backgroundColor: AppTheme.accentAmber,
            ),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving credentials: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isTesting = true);

    try {
      final tokenStorage = ref.read(youtubeTokenStorageProvider);
      await tokenStorage.saveCredentials(
        YouTubeCredentials(
          clientId: _clientIdController.text.trim(),
          clientSecret: _clientSecretController.text.trim(),
          refreshToken: _refreshTokenController.text.trim().isNotEmpty ? _refreshTokenController.text.trim() : null,
        ),
      );

      final channel = await ref.read(youtubeAdapterProvider).fetchChannelInfo();
      if (mounted) {
        if (channel != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection verified! Connected to channel: ${channel.accountName}'),
              backgroundColor: AppTheme.accentEmerald,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to verify connection. Check Client ID, Client Secret, and Refresh Token.'),
              backgroundColor: AppTheme.accentRose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                            color: AppTheme.platformYoutube.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.video_collection, color: AppTheme.platformYoutube, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YouTube OAuth 2.0 Credentials',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Official YouTube Data API v3 desktop client configuration',
                              style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
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
                const SizedBox(height: 16),

                // Info banner explaining official API compliance
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryIndigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryIndigo.withOpacity(0.3)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: AppTheme.primaryIndigo),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '100% Free & Compliant: Create free desktop OAuth credentials in Google Cloud Console with scope "youtube.upload" and "youtube.readonly". Tokens are stored encrypted locally on your Windows PC.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Client ID
                TextFormField(
                  controller: _clientIdController,
                  decoration: const InputDecoration(
                    labelText: 'OAuth Client ID *',
                    hintText: 'e.g. 123456789-abc.apps.googleusercontent.com',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Client ID is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Client Secret
                TextFormField(
                  controller: _clientSecretController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'OAuth Client Secret *',
                    hintText: 'e.g. GOCSPX-xxxxxxxxxxxx',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Client Secret is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Refresh Token
                TextFormField(
                  controller: _refreshTokenController,
                  decoration: const InputDecoration(
                    labelText: 'OAuth Refresh Token (Optional for initial setup)',
                    hintText: '1//0xxxxxxxxxxxxxxxxxxxx',
                    prefixIcon: Icon(Icons.sync),
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: _isTesting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.network_check, size: 16),
                      label: const Text('Test Connection'),
                      onPressed: (_isLoading || _isTesting) ? null : _handleTest,
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
                      onPressed: (_isLoading || _isTesting) ? null : _handleSave,
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Credentials'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
