import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/models/app_model.dart';
import '../../apps/providers/app_providers.dart';
import '../models/campaign_model.dart';
import '../providers/campaign_providers.dart';

class CampaignFormDialog extends ConsumerStatefulWidget {
  final CampaignModel? initialCampaign;

  const CampaignFormDialog({super.key, this.initialCampaign});

  static Future<bool?> show(BuildContext context, {CampaignModel? initialCampaign}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CampaignFormDialog(initialCampaign: initialCampaign),
    );
  }

  @override
  ConsumerState<CampaignFormDialog> createState() => _CampaignFormDialogState();
}

class _CampaignFormDialogState extends ConsumerState<CampaignFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _targetAudienceController;
  late TextEditingController _targetCountryController;
  late TextEditingController _languageController;
  late TextEditingController _notesController;
  final _themeInputController = TextEditingController();

  late String _selectedObjective;
  late String _selectedStatus;
  late String _selectedFrequency;
  AppModel? _selectedApp;

  DateTime? _startDate;
  DateTime? _endDate;
  final Set<String> _selectedPlatforms = {'YouTube', 'TikTok', 'Instagram'};
  late List<String> _contentThemes;

  bool _isSaving = false;

  static const List<String> _objectives = [
    'New App Launch',
    'Feature Showcase',
    'Problem & Solution Angle',
    'Tutorial & How-To Series',
    'App Update Announcement',
    'FAQ & Tips',
    'Feature Comparison vs Competitors',
    'Educational & Niche Industry Tips',
  ];

  static const List<String> _frequencies = [
    'Daily (7 posts/wk)',
    '3 times per week',
    'Twice per week',
    'Weekly',
    'Bi-weekly',
  ];

  static const List<String> _allPlatforms = [
    'YouTube',
    'TikTok',
    'Instagram',
    'Facebook',
  ];

  @override
  void initState() {
    super.initState();
    final camp = widget.initialCampaign;

    _nameController = TextEditingController(text: camp?.name ?? '');
    _targetAudienceController = TextEditingController(text: camp?.targetAudience ?? '');
    _targetCountryController = TextEditingController(text: camp?.targetCountry ?? 'US');
    _languageController = TextEditingController(text: camp?.language ?? 'en');
    _notesController = TextEditingController(text: camp?.notes ?? '');

    _selectedObjective = camp?.objective ?? _objectives.first;
    _selectedStatus = camp?.status ?? 'draft';
    _selectedFrequency = camp?.postingFrequency ?? _frequencies[1];

    if (camp?.startDate != null) {
      _startDate = DateTime.tryParse(camp!.startDate!);
    } else {
      _startDate = DateTime.now();
    }

    if (camp?.endDate != null) {
      _endDate = DateTime.tryParse(camp!.endDate!);
    } else {
      _endDate = DateTime.now().add(const Duration(days: 30));
    }

    if (camp != null) {
      _selectedPlatforms.clear();
      _selectedPlatforms.addAll(camp.platforms);
      _contentThemes = List.from(camp.contentThemes);
    } else {
      _contentThemes = ['Core Feature Deep-dive', 'Problem Solution', 'User Benefits'];
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedApp == null) {
      final currentApp = ref.read(selectedAppProvider);
      final appsAsync = ref.read(appsListProvider);
      final apps = appsAsync.value ?? [];

      if (widget.initialCampaign != null) {
        _selectedApp = apps.where((a) => a.id == widget.initialCampaign!.appId).firstOrNull;
      } else {
        _selectedApp = currentApp ?? apps.firstOrNull;
      }

      if (_selectedApp != null && _targetAudienceController.text.isEmpty) {
        _targetAudienceController.text = _selectedApp?.targetAudience ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAudienceController.dispose();
    _targetCountryController.dispose();
    _languageController.dispose();
    _notesController.dispose();
    _themeInputController.dispose();
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
    final now = DateTime.now().toUtc();
    final dateFormat = DateFormat('yyyy-MM-dd');

    try {
      final campaign = CampaignModel(
        id: widget.initialCampaign?.id ?? const Uuid().v4(),
        appId: _selectedApp!.id,
        name: _nameController.text.trim(),
        objective: _selectedObjective,
        targetAudience: _targetAudienceController.text.trim().isEmpty ? null : _targetAudienceController.text.trim(),
        targetCountry: _targetCountryController.text.trim().isEmpty ? null : _targetCountryController.text.trim(),
        language: _languageController.text.trim().isEmpty ? null : _languageController.text.trim(),
        startDate: _startDate != null ? dateFormat.format(_startDate!) : null,
        endDate: _endDate != null ? dateFormat.format(_endDate!) : null,
        status: _selectedStatus,
        postingFrequency: _selectedFrequency,
        platforms: _selectedPlatforms.toList(),
        contentThemes: _contentThemes,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.initialCampaign?.createdAt ?? now,
        updatedAt: now,
      );

      final notifier = ref.read(campaignsListProvider.notifier);
      if (widget.initialCampaign == null) {
        await notifier.createCampaign(campaign);
      } else {
        await notifier.updateCampaign(campaign);
      }

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
    final appsAsync = ref.watch(appsListProvider);
    final isEditing = widget.initialCampaign != null;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
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
                            isEditing ? 'Edit Campaign Strategy' : 'Create Organic Promotion Campaign',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Organize content themes, target platforms, and publishing schedules.',
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
              const Divider(height: 24),

              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App selection & Campaign Name
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: appsAsync.maybeWhen(
                                data: (apps) => DropdownButtonFormField<AppModel>(
                                  value: _selectedApp != null && apps.any((a) => a.id == _selectedApp!.id)
                                      ? apps.firstWhere((a) => a.id == _selectedApp!.id)
                                      : apps.firstOrNull,
                                  decoration: const InputDecoration(
                                    labelText: 'Target Application *',
                                    prefixIcon: Icon(Icons.android, size: 18),
                                  ),
                                  items: apps.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                                  onChanged: (app) {
                                    setState(() {
                                      _selectedApp = app;
                                      if (app?.targetAudience != null && _targetAudienceController.text.isEmpty) {
                                        _targetAudienceController.text = app!.targetAudience!;
                                      }
                                    });
                                  },
                                ),
                                orElse: () => const Text('Loading apps...'),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 6,
                              child: TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Campaign Name *',
                                  hintText: 'e.g., Q4 Android Discovery Boost',
                                  prefixIcon: Icon(Icons.label_outline, size: 18),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campaign name is required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Objective & Posting Frequency
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedObjective,
                                decoration: const InputDecoration(
                                  labelText: 'Campaign Objective *',
                                  prefixIcon: Icon(Icons.flag_outlined, size: 18),
                                ),
                                items: _objectives.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (val) => setState(() => _selectedObjective = val ?? _selectedObjective),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedFrequency,
                                decoration: const InputDecoration(
                                  labelText: 'Desired Posting Frequency',
                                  prefixIcon: Icon(Icons.repeat, size: 18),
                                ),
                                items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                onChanged: (val) => setState(() => _selectedFrequency = val ?? _selectedFrequency),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Target Audience & Country
                        Row(
                          children: [
                            Expanded(
                              flex: 7,
                              child: TextFormField(
                                controller: _targetAudienceController,
                                decoration: const InputDecoration(
                                  labelText: 'Target Audience Persona',
                                  hintText: 'e.g., Busy professionals wanting daily focus',
                                  prefixIcon: Icon(Icons.people_outline, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _targetCountryController,
                                decoration: const InputDecoration(
                                  labelText: 'Country Code',
                                  hintText: 'US',
                                  prefixIcon: Icon(Icons.public, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Date Pickers (Start & End)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: Text(_startDate != null ? 'Start: ${dateFormat.format(_startDate!)}' : 'Select Start Date'),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate ?? DateTime.now(),
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) setState(() => _startDate = picked);
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.event, size: 16),
                                label: Text(_endDate != null ? 'End: ${dateFormat.format(_endDate!)}' : 'Select End Date'),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                                    firstDate: DateTime(2024),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) setState(() => _endDate = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Target Platforms Selector
                        const Text('Target Publishing Platforms *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          children: _allPlatforms.map((plat) {
                            final isChecked = _selectedPlatforms.contains(plat);
                            return FilterChip(
                              label: Text(plat),
                              selected: isChecked,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedPlatforms.add(plat);
                                  } else if (_selectedPlatforms.length > 1) {
                                    _selectedPlatforms.remove(plat);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),

                        // Content Themes Tags
                        const Text('Content Themes & Angles', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        const Text('Define topics or series angles for automated draft generation.', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _themeInputController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g., 5-Minute Productivity Hacks',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onFieldSubmitted: (val) {
                                  if (val.trim().isNotEmpty && !_contentThemes.contains(val.trim())) {
                                    setState(() {
                                      _contentThemes.add(val.trim());
                                      _themeInputController.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () {
                                final val = _themeInputController.text;
                                if (val.trim().isNotEmpty && !_contentThemes.contains(val.trim())) {
                                  setState(() {
                                    _contentThemes.add(val.trim());
                                    _themeInputController.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        if (_contentThemes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _contentThemes.map((th) => Chip(
                              label: Text(th, style: const TextStyle(fontSize: 12)),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => setState(() => _contentThemes.remove(th)),
                            )).toList(),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Strategy Notes',
                            hintText: 'Internal notes regarding goals, target influencers, or hashtag strategy...',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(height: 24),
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
                        : Text(isEditing ? 'Update Campaign' : 'Create Campaign'),
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
