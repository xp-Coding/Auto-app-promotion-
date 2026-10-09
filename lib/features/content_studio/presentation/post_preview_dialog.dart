import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../models/content_post_model.dart';

class PostPreviewDialog extends StatelessWidget {
  final ContentPostModel post;

  const PostPreviewDialog({super.key, required this.post});

  static void show(BuildContext context, ContentPostModel post) {
    showDialog(
      context: context,
      builder: (context) => PostPreviewDialog(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platformColor = _getPlatformColor(post.targetPlatform);

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750, maxHeight: 680),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: platformColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          post.targetPlatform.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: platformColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        post.title ?? 'Post Preview',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      // Hook callout
                      if (post.scriptHook != null && post.scriptHook!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.flash_on, size: 16, color: AppTheme.accentAmber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Opening Hook:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.accentAmber)),
                                    const SizedBox(height: 2),
                                    Text(post.scriptHook!, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Main post body
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: SelectableText(
                          post.bodyText,
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Hashtags
                      if (post.hashtags != null && post.hashtags!.isNotEmpty) ...[
                        const Text('Hashtags:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.darkTextSecondary)),
                        const SizedBox(height: 4),
                        SelectableText(
                          post.hashtags!,
                          style: const TextStyle(fontSize: 12, color: AppTheme.accentCyan),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // CTA Link
                      if (post.ctaLink != null && post.ctaLink!.isNotEmpty) ...[
                        const Text('Call to Action & Google Play URL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.darkTextSecondary)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.link, size: 16, color: AppTheme.primaryIndigo),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  post.ctaLink!,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                tooltip: 'Copy Link',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: post.ctaLink!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tracking URL copied')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_all, size: 16),
                    label: const Text('Copy Complete Copy'),
                    onPressed: () {
                      final allContent = '${post.title != null ? "${post.title}\n\n" : ""}${post.bodyText}\n\n${post.hashtags ?? ""}\n\n${post.ctaLink ?? ""}';
                      Clipboard.setData(ClipboardData(text: allContent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Entire post copied to clipboard')),
                      );
                    },
                  ),
                  ElevatedButton(
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
}
