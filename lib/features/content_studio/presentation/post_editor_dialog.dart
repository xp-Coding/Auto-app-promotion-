import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/utm_builder.dart';
import '../../apps/models/app_model.dart';
import '../../apps/providers/app_providers.dart';
import '../../campaigns/models/campaign_model.dart';
import '../../campaigns/providers/campaign_providers.dart';
import '../domain/content_generation_provider.dart';
import '../models/content_post_model.dart';
import '../providers/content_studio_providers.dart';
import '../../publishing/providers/publishing_providers.dart';

class PostEditorDialog extends ConsumerStatefulWidget {
  final ContentPostModel? initialPost;
  final String? initialPlatform;
  final String? initialFormat;

  const PostEditorDialog({
    super.key,
    this.initialPost,
    this.initialPlatform,
    this.initialFormat,
  });

  static Future<bool?> show(
    BuildContext context, {
    ContentPostModel? initialPost,
    String? initialPlatform,
    String? initialFormat,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PostEditorDialog(
        initialPost: initialPost,
        initialPlatform: initialPlatform,
        initialFormat: initialFormat,
      ),
    );
  }

  @override
  ConsumerState<PostEditorDialog> createState() => _PostEditorDialogState();
}

class _PostEditorDialogState extends ConsumerState<PostEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late TextEditingController _hookController;
  late TextEditingController _hashtagsController;
  late TextEditingController _ctaLinkController;
  final _themePromptController = TextEditingController();

  late String _selectedPlatform;
  late String _selectedFormat;
  late String _selectedStatus;
  AppModel? _selectedApp;
  CampaignModel? _selectedCampaign;

  bool _isGenerating = false;
  bool _isSaving = false;

  static const List<String> _platforms = ['YouTube', 'TikTok', 'Instagram', 'Facebook'];
  static const List<String> _formats = ['video_script', 'caption', 'reel', 'carousel', 'story'];
  static const List<String> _statuses = ['draft', 'ready', 'scheduled'];

  @override
  void initState() {
    super.initState();
    final p = widget.initialPost;

    _titleController = TextEditingController(text: p?.title ?? '');
    _bodyController = TextEditingController(text: p?.bodyText ?? '');
    _hookController = TextEditingController(text: p?.scriptHook ?? '');
    _hashtagsController = TextEditingController(text: p?.hashtags ?? '');
    _ctaLinkController = TextEditingController(text: p?.ctaLink ?? '');

    _selectedPlatform = p?.targetPlatform ?? widget.initialPlatform ?? _platforms.first;
    _selectedFormat = p?.format ?? widget.initialFormat ?? _formats.first;
    _selectedStatus = p?.status ?? _statuses.first;

    _bodyController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedApp == null) {
      final apps = ref.read(appsListProvider).value ?? [];
      final currentApp = ref.read(selectedAppProvider);

      if (widget.initialPost != null) {
        _selectedApp = apps.where((a) => a.id == widget.initialPost!.appId).firstOrNull;
      } else {
        _selectedApp = currentApp ?? apps.firstOrNull;
      }

      final campaigns = ref.read(campaignsListProvider).value ?? [];
      if (widget.initialPost?.campaignId != null) {
        _selectedCampaign = campaigns.where((c) => c.id == widget.initialPost!.campaignId).firstOrNull;
      } else {
        _selectedCampaign = campaigns.firstOrNull;
      }

      if (_ctaLinkController.text.isEmpty && _selectedApp != null) {
        _generateUtmLink();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _hookController.dispose();
    _hashtagsController.dispose();
    _ctaLinkController.dispose();
    _themePromptController.dispose();
    super.dispose();
  }

  void _generateUtmLink() {
    if (_selectedApp == null) return;
    final url = UtmBuilder.buildPlayStoreUtmUrl(
      basePlayStoreUrl: _selectedApp!.playStoreUrl,
      utmSource: _selectedPlatform.toLowerCase(),
      utmMedium: UtmBuilder.getSuggestedMediumForPlatform(_selectedPlatform),
      utmCampaign: _selectedCampaign?.name.replaceAll(' ', '_') ?? 'organic_promo',
      utmContent: _selectedFormat,
    );
    setState(() {
      _ctaLinkController.text = url;
    });
  }

  Future<void> _handleTemplateGenerate() async {
    if (_selectedApp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or register an app first')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final generator = ref.read(contentGenerationProvider);
      final result = await generator.generateContent(
        ContentGenerationRequest(
          app: _selectedApp!,
          campaign: _selectedCampaign,
          targetPlatform: _selectedPlatform,
          contentFormat: _selectedFormat,
          topicOrTheme: _themePromptController.text.trim().isNotEmpty ? _themePromptController.text.trim() : null,
        ),
      );

      setState(() {
        _titleController.text = result.title;
        _bodyController.text = result.bodyText;
        _hookController.text = result.scriptHook;
        _hashtagsController.text = result.hashtags;
        _ctaLinkController.text = result.ctaLink;
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promotional draft generated via template!')),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generation error: $e')));
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an application')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now().toUtc();

    try {
      final post = ContentPostModel(
        id: widget.initialPost?.id ?? const Uuid().v4(),
        appId: _selectedApp!.id,
        campaignId: _selectedCampaign?.id,
        targetPlatform: _selectedPlatform,
        title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        bodyText: _bodyController.text.trim(),
        hashtags: _hashtagsController.text.trim().isEmpty ? null : _hashtagsController.text.trim(),
        scriptHook: _hookController.text.trim().isEmpty ? null : _hookController.text.trim(),
        ctaLink: _ctaLinkController.text.trim().isEmpty ? null : _ctaLinkController.text.trim(),
        format: _selectedFormat,
        status: _selectedStatus,
        createdAt: widget.initialPost?.createdAt ?? now,
        updatedAt: now,
      );

      await ref.read(contentPostsListProvider.notifier).savePost(post);

      if (_selectedStatus == 'scheduled') {
        await ref.read(publishingJobsListProvider.notifier).enqueueJob(
          contentId: post.id,
          targetPlatform: post.targetPlatform,
          campaignId: post.campaignId,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(appsListProvider);
    final campaignsAsync = ref.watch(campaignsListProvider);
    final isEditing = widget.initialPost != null;

    final wordCount = _bodyController.text.trim().isEmpty
        ? 0
        : _bodyController.text.trim().split(RegExp(r'\s+')).length;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
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
                        child: const Icon(Icons.edit_note, color: AppTheme.primaryIndigo, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Promotional Post' : 'Content Studio Post Editor',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Platform-specific captions, video storyboards, hooks, and UTM tracking links.',
                            style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: Colors.black87,
                        ),
                        icon: _isGenerating
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Generate With Template'),
                        onPressed: _isGenerating ? null : _handleTemplateGenerate,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              // Form body
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Target App, Campaign, Platform & Format
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: appsAsync.maybeWhen(
                                data: (apps) => DropdownButtonFormField<AppModel>(
                                  value: _selectedApp != null && apps.any((a) => a.id == _selectedApp!.id)
                                      ? apps.firstWhere((a) => a.id == _selectedApp!.id)
                                      : apps.firstOrNull,
                                  decoration: const InputDecoration(labelText: 'Target App *', prefixIcon: Icon(Icons.android, size: 18)),
                                  items: apps.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                                  onChanged: (app) {
                                    setState(() {
                                      _selectedApp = app;
                                      _generateUtmLink();
                                    });
                                  },
                                ),
                                orElse: () => const Text('Loading...'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: campaignsAsync.maybeWhen(
                                data: (camps) => DropdownButtonFormField<CampaignModel?>(
                                  value: _selectedCampaign != null && camps.any((c) => c.id == _selectedCampaign!.id)
                                      ? camps.firstWhere((c) => c.id == _selectedCampaign!.id)
                                      : null,
                                  decoration: const InputDecoration(labelText: 'Campaign (Optional)', prefixIcon: Icon(Icons.campaign, size: 18)),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('No Campaign')),
                                    ...camps.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
                                  ],
                                  onChanged: (camp) {
                                    setState(() {
                                      _selectedCampaign = camp;
                                      _generateUtmLink();
                                    });
                                  },
                                ),
                                orElse: () => const Text('Loading...'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedPlatform,
                                decoration: const InputDecoration(labelText: 'Platform *', prefixIcon: Icon(Icons.share, size: 18)),
                                items: _platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedPlatform = val ?? _selectedPlatform;
                                    _generateUtmLink();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedFormat,
                                decoration: const InputDecoration(labelText: 'Format *', prefixIcon: Icon(Icons.view_agenda, size: 18)),
                                items: _formats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedFormat = val ?? _selectedFormat;
                                    _generateUtmLink();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Topic Prompt helper row for generator
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.accentAmber),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _themePromptController,
                                  decoration: const InputDecoration(
                                    hintText: 'Optional topic/angle (e.g. "Morning Habit Routine", "Feature Spotlight")',
                                    isDense: true,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title / Headline
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Post Title / Video Headline',
                            hintText: 'e.g., How to Master Habits Without Falling Off',
                            prefixIcon: Icon(Icons.title, size: 18),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Hook (for videos / reels)
                        TextFormField(
                          controller: _hookController,
                          decoration: const InputDecoration(
                            labelText: 'Opening Hook (First 3 Seconds / First Line)',
                            hintText: 'e.g., If you have an Android phone, you need this app right now...',
                            prefixIcon: Icon(Icons.flash_on, size: 18),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Main Body / Script
                        TextFormField(
                          controller: _bodyController,
                          maxLines: 8,
                          decoration: InputDecoration(
                            labelText: 'Content Body / Full Video Script *',
                            hintText: 'Enter complete caption copy or scene-by-scene script...',
                            alignLabelWithHint: true,
                            helperText: '${_bodyController.text.length} characters • $wordCount words',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Post body text is required' : null,
                        ),
                        const SizedBox(height: 14),

                        // Hashtags & Status
                        Row(
                          children: [
                            Expanded(
                              flex: 7,
                              child: TextFormField(
                                controller: _hashtagsController,
                                decoration: const InputDecoration(
                                  labelText: 'Relevant Hashtags',
                                  hintText: '#Android #AppPromo #Productivity',
                                  prefixIcon: Icon(Icons.tag, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.flag, size: 18)),
                                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                                onChanged: (val) => setState(() => _selectedStatus = val ?? _selectedStatus),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // CTA & Tracking Link with regenerate button
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _ctaLinkController,
                                decoration: InputDecoration(
                                  labelText: 'Google Play UTM Attribution URL',
                                  hintText: 'https://play.google.com/store/apps/details?id=...&referrer=...',
                                  prefixIcon: const Icon(Icons.link, size: 18),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.refresh, size: 18),
                                    tooltip: 'Regenerate UTM Parameters',
                                    onPressed: _generateUtmLink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(height: 24),

              // Action buttons
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
                        : Text(isEditing ? 'Save Changes' : 'Save Draft'),
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
