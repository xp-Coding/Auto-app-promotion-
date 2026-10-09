import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/providers/app_providers.dart';
import '../models/media_item_model.dart';
import '../providers/media_providers.dart';
import 'add_media_dialog.dart';

class MediaLibraryScreen extends ConsumerWidget {
  const MediaLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(mediaListProvider);
    final selectedApp = ref.watch(selectedAppProvider);
    final filterType = ref.watch(mediaFilterTypeProvider);

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
                          'Media Library',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        mediaAsync.maybeWhen(
                          data: (items) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryIndigo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${items.length} assets',
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
                          ? 'Cataloging creative assets for ${selectedApp.name}'
                          : 'Select an application from the top bar to filter media assets.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Add Media Asset'),
                  onPressed: () => AddMediaDialog.show(context),
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
                          hintText: 'Search by title, path, or tag...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (val) {
                          ref.read(mediaSearchQueryProvider.notifier).state = val;
                          ref.read(mediaListProvider.notifier).loadMedia();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        value: filterType,
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Media Types')),
                          DropdownMenuItem(value: 'icon', child: Text('Icons')),
                          DropdownMenuItem(value: 'screenshot', child: Text('Screenshots')),
                          DropdownMenuItem(value: 'banner', child: Text('Banners')),
                          DropdownMenuItem(value: 'video', child: Text('Videos')),
                          DropdownMenuItem(value: 'thumbnail', child: Text('Thumbnails')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(mediaFilterTypeProvider.notifier).state = val;
                            ref.read(mediaListProvider.notifier).loadMedia();
                          }
                        },
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      onPressed: () => ref.read(mediaListProvider.notifier).loadMedia(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content Grid
            Expanded(
              child: mediaAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading media: $err')),
                data: (items) {
                  if (items.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      mainAxisExtent: 260,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, idx) {
                      final item = items[idx];
                      return _MediaCard(item: item);
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
          width: 500,
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_outlined, size: 48, color: AppTheme.primaryIndigo),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Media Assets Cataloged',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Register screenshots, icons, feature graphics, and video clips stored on your PC to link them with scheduled campaigns.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Media Asset'),
                onPressed: () => AddMediaDialog.show(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaCard extends ConsumerWidget {
  final MediaItemModel item;

  const _MediaCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = File(item.filePath);
    final exists = item.fileExists;
    final isImage = ['png', 'jpg', 'jpeg', 'webp', 'bmp'].any((ext) => item.filePath.toLowerCase().endsWith(ext));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview Container
          Container(
            height: 130,
            width: double.infinity,
            color: Theme.of(context).dividerColor.withOpacity(0.3),
            child: exists && isImage
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, size: 36, color: AppTheme.darkTextSecondary),
                    ),
                  )
                : Center(
                    child: Icon(
                      item.mediaType == 'video' ? Icons.videocam_outlined : Icons.insert_drive_file_outlined,
                      size: 40,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
          ),

          // Details & Actions
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryIndigo.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.mediaType.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryIndigo),
                      ),
                    ),
                    Text(
                      item.formattedSize,
                      style: TextStyle(
                        fontSize: 11,
                        color: exists ? AppTheme.darkTextSecondary : AppTheme.accentRose,
                        fontWeight: exists ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title ?? file.uri.pathSegments.lastOrNull ?? 'Asset',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      exists ? 'Local Asset' : 'Missing File',
                      style: TextStyle(
                        fontSize: 11,
                        color: exists ? AppTheme.accentEmerald : AppTheme.accentRose,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.accentRose),
                      tooltip: 'Remove Asset Reference',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Remove Asset Reference?'),
                            content: const Text('This removes the database catalog entry without deleting your original file on disk.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(mediaListProvider.notifier).deleteMedia(item.id);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
