import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/models/app_model.dart';
import '../../apps/providers/app_providers.dart';
import '../models/media_item_model.dart';
import '../providers/media_providers.dart';

class AddMediaDialog extends ConsumerStatefulWidget {
  const AddMediaDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddMediaDialog(),
    );
  }

  @override
  ConsumerState<AddMediaDialog> createState() => _AddMediaDialogState();
}

class _AddMediaDialogState extends ConsumerState<AddMediaDialog> {
  final _formKey = GlobalKey<FormState>();

  final _pathController = TextEditingController();
  final _titleController = TextEditingController();
  final _tagsController = TextEditingController();

  String _selectedType = 'screenshot';
  AppModel? _selectedApp;
  bool _isSaving = false;

  static const List<String> _types = [
    'icon',
    'screenshot',
    'banner',
    'video',
    'thumbnail',
    'background',
    'logo',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedApp == null) {
      final current = ref.read(selectedAppProvider);
      final list = ref.read(appsListProvider).value ?? [];
      _selectedApp = current ?? list.firstOrNull;
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    _titleController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or register an application first')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final item = MediaItemModel(
        id: const Uuid().v4(),
        appId: _selectedApp!.id,
        filePath: _pathController.text.trim(),
        mediaType: _selectedType,
        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        tags: _tagsController.text.trim().isEmpty ? null : _tagsController.text.trim(),
        createdAt: DateTime.now().toUtc(),
      );

      await ref.read(mediaListProvider.notifier).addMedia(item);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(appsListProvider).value ?? [];
    final file = File(_pathController.text.trim());
    final fileExists = _pathController.text.trim().isNotEmpty && file.existsSync();

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
                            color: AppTheme.primaryIndigo.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.perm_media_outlined, color: AppTheme.primaryIndigo, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Register Media Asset',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Catalog icons, screenshots, promo banners, and local videos.',
                              style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                const Divider(height: 24),

                // App & Type selector
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: DropdownButtonFormField<AppModel>(
                        value: _selectedApp != null && apps.any((a) => a.id == _selectedApp!.id)
                            ? apps.firstWhere((a) => a.id == _selectedApp!.id)
                            : apps.firstOrNull,
                        decoration: const InputDecoration(labelText: 'Target App *', prefixIcon: Icon(Icons.android, size: 18)),
                        items: apps.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                        onChanged: (app) => setState(() => _selectedApp = app),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(labelText: 'Asset Type *', prefixIcon: Icon(Icons.category, size: 18)),
                        items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                        onChanged: (val) => setState(() => _selectedType = val ?? _selectedType),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // File Path Input
                TextFormField(
                  controller: _pathController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Local File Path *',
                    hintText: 'e.g. C:/Marketing/PromoScreenshots/shot_01.png',
                    prefixIcon: const Icon(Icons.folder_open, size: 18),
                    helperText: _pathController.text.trim().isEmpty
                        ? 'Enter absolute path to graphic or video file'
                        : fileExists
                            ? '✓ File exists on disk (${(file.lengthSync() / 1024).toStringAsFixed(1)} KB)'
                            : '⚠️ File does not currently exist at this path',
                    helperStyle: TextStyle(
                      color: _pathController.text.trim().isNotEmpty
                          ? (fileExists ? AppTheme.accentEmerald : AppTheme.accentAmber)
                          : null,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'File path is required' : null,
                ),
                const SizedBox(height: 14),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Asset Title / Label',
                    hintText: 'e.g., Home Dashboard Feature Callout',
                    prefixIcon: Icon(Icons.label_outline, size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Tags
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Search Tags',
                    hintText: 'e.g., dark_mode, feature_highlight, reel_clip',
                    prefixIcon: Icon(Icons.tag, size: 18),
                  ),
                ),

                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add to Library'),
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
