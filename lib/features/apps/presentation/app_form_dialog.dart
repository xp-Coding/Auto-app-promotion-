import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../models/app_model.dart';
import '../providers/app_providers.dart';

class AppFormDialog extends ConsumerStatefulWidget {
  final AppModel? initialApp;

  const AppFormDialog({super.key, this.initialApp});

  static Future<bool?> show(BuildContext context, {AppModel? initialApp}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppFormDialog(initialApp: initialApp),
    );
  }

  @override
  ConsumerState<AppFormDialog> createState() => _AppFormDialogState();
}

class _AppFormDialogState extends ConsumerState<AppFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _packageNameController;
  late TextEditingController _playStoreUrlController;
  late TextEditingController _iconPathController;
  late TextEditingController _shortDescController;
  late TextEditingController _fullDescController;
  late TextEditingController _targetAudienceController;
  late TextEditingController _websiteUrlController;
  late TextEditingController _privacyPolicyUrlController;

  late String _selectedCategory;
  late String _selectedBrandTone;
  late String _selectedCta;

  late List<String> _mainFeatures;
  late List<String> _uniqueSellingPoints;
  late List<String> _targetCountries;
  late List<String> _supportedLanguages;

  final _featureInputController = TextEditingController();
  final _uspInputController = TextEditingController();
  final _countryInputController = TextEditingController();
  final _languageInputController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  static const List<String> _categories = [
    'Productivity',
    'Tools & Utilities',
    'Education',
    'Finance',
    'Health & Fitness',
    'Communication',
    'Entertainment',
    'Photography',
    'Social',
    'Lifestyle',
    'Business',
    'Personalization',
    'Games',
  ];

  static const List<String> _brandTones = [
    'Professional & Trustworthy',
    'Excited & Energetic',
    'Informative & Helpful',
    'Casual & Friendly',
    'Direct & Value-Focused',
    'Inspirational & Bold',
  ];

  static const List<String> _ctaOptions = [
    'Install now on Google Play',
    'Download for free on Google Play',
    'Try it free today',
    'Get started on Google Play',
    'Check it out on Google Play Store',
  ];

  @override
  void initState() {
    super.initState();
    final app = widget.initialApp;

    _nameController = TextEditingController(text: app?.name ?? '');
    _packageNameController = TextEditingController(text: app?.packageName ?? '');
    _playStoreUrlController = TextEditingController(text: app?.playStoreUrl ?? '');
    _iconPathController = TextEditingController(text: app?.iconPath ?? '');
    _shortDescController = TextEditingController(text: app?.shortDescription ?? '');
    _fullDescController = TextEditingController(text: app?.fullDescription ?? '');
    _targetAudienceController = TextEditingController(text: app?.targetAudience ?? '');
    _websiteUrlController = TextEditingController(text: app?.websiteUrl ?? '');
    _privacyPolicyUrlController = TextEditingController(text: app?.privacyPolicyUrl ?? '');

    _selectedCategory = app?.category ?? _categories.first;
    _selectedBrandTone = app?.brandTone ?? _brandTones.first;
    _selectedCta = app?.preferredCta ?? _ctaOptions.first;

    _mainFeatures = List.from(app?.mainFeatures ?? []);
    _uniqueSellingPoints = List.from(app?.uniqueSellingPoints ?? []);
    _targetCountries = List.from(app?.targetCountries ?? ['US', 'GB', 'CA', 'IN']);
    _supportedLanguages = List.from(app?.supportedLanguages ?? ['en']);

    _playStoreUrlController.addListener(_onUrlChanged);
    _nameController.addListener(() => setState(() {}));
    _shortDescController.addListener(() => setState(() {}));
    _fullDescController.addListener(() => setState(() {}));
  }

  void _onUrlChanged() {
    final url = _playStoreUrlController.text;
    if (_packageNameController.text.trim().isEmpty) {
      final extracted = Validators.extractPackageName(url);
      if (extracted != null) {
        setState(() {
          _packageNameController.text = extracted;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packageNameController.dispose();
    _playStoreUrlController.dispose();
    _iconPathController.dispose();
    _shortDescController.dispose();
    _fullDescController.dispose();
    _targetAudienceController.dispose();
    _websiteUrlController.dispose();
    _privacyPolicyUrlController.dispose();
    _featureInputController.dispose();
    _uspInputController.dispose();
    _countryInputController.dispose();
    _languageInputController.dispose();
    super.dispose();
  }

  ListingQualityResult get _currentQuality {
    return Validators.evaluateListingQuality(
      name: _nameController.text,
      packageName: _packageNameController.text,
      shortDescription: _shortDescController.text,
      fullDescription: _fullDescController.text,
      mainFeatures: _mainFeatures,
      uniqueSellingPoints: _uniqueSellingPoints,
      targetAudience: _targetAudienceController.text,
      iconPath: _iconPathController.text,
      privacyPolicyUrl: _privacyPolicyUrlController.text,
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now().toUtc();
      final app = AppModel(
        id: widget.initialApp?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        packageName: _packageNameController.text.trim(),
        playStoreUrl: _playStoreUrlController.text.trim(),
        iconPath: _iconPathController.text.trim().isEmpty ? null : _iconPathController.text.trim(),
        category: _selectedCategory,
        shortDescription: _shortDescController.text.trim().isEmpty ? null : _shortDescController.text.trim(),
        fullDescription: _fullDescController.text.trim().isEmpty ? null : _fullDescController.text.trim(),
        mainFeatures: _mainFeatures,
        uniqueSellingPoints: _uniqueSellingPoints,
        targetAudience: _targetAudienceController.text.trim().isEmpty ? null : _targetAudienceController.text.trim(),
        targetCountries: _targetCountries,
        supportedLanguages: _supportedLanguages,
        brandTone: _selectedBrandTone,
        preferredCta: _selectedCta,
        websiteUrl: _websiteUrlController.text.trim().isEmpty ? null : _websiteUrlController.text.trim(),
        privacyPolicyUrl: _privacyPolicyUrlController.text.trim().isEmpty ? null : _privacyPolicyUrlController.text.trim(),
        isArchived: widget.initialApp?.isArchived ?? false,
        createdAt: widget.initialApp?.createdAt ?? now,
        updatedAt: now,
      );

      final notifier = ref.read(appsListProvider.notifier);
      if (widget.initialApp == null) {
        await notifier.createApp(app);
      } else {
        await notifier.updateApp(app);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quality = _currentQuality;
    final isEditing = widget.initialApp != null;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 780),
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
                        child: const Icon(Icons.android, color: AppTheme.primaryIndigo, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Application Details' : 'Register New Google Play App',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Enter your store listing info to power organic marketing generation.',
                            style: TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary),
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
              const Divider(height: 28),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRose.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentRose.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.accentRose, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.accentRose, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Form body + Quality Checklist sidebar
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form fields
                    Expanded(
                      flex: 6,
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(right: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Play Store URL & Auto Extract
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _playStoreUrlController,
                                      decoration: InputDecoration(
                                        labelText: 'Google Play Listing URL *',
                                        hintText: 'https://play.google.com/store/apps/details?id=com.example.app',
                                        prefixIcon: const Icon(Icons.link, size: 18),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.auto_fix_high, size: 18),
                                          tooltip: 'Extract Package Name',
                                          onPressed: () {
                                            final id = Validators.extractPackageName(_playStoreUrlController.text);
                                            if (id != null) {
                                              _packageNameController.text = id;
                                            }
                                          },
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Play Store URL is required';
                                        }
                                        if (!Validators.isValidPlayStoreUrl(val)) {
                                          return 'Must be a valid Google Play Store URL with "?id=..."';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // App Name & Package Name
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nameController,
                                      maxLength: 50,
                                      decoration: InputDecoration(
                                        labelText: 'App Name *',
                                        hintText: 'e.g., FocusFlow Habit Tracker',
                                        prefixIcon: const Icon(Icons.label_outline, size: 18),
                                        helperText: '${_nameController.text.length}/30 Play recommended',
                                        counterText: '',
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'App name is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _packageNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Package Name *',
                                        hintText: 'e.g., com.studio.focusflow',
                                        prefixIcon: Icon(Icons.fingerprint, size: 18),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Package name is required';
                                        }
                                        if (!Validators.isValidPackageName(val)) {
                                          return 'Format must be valid Android package (e.g. com.example.app)';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Category & Brand Tone
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedCategory,
                                      decoration: const InputDecoration(
                                        labelText: 'App Category *',
                                        prefixIcon: Icon(Icons.category_outlined, size: 18),
                                      ),
                                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                      onChanged: (val) => setState(() => _selectedCategory = val ?? _selectedCategory),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedBrandTone,
                                      decoration: const InputDecoration(
                                        labelText: 'Marketing Brand Tone',
                                        prefixIcon: Icon(Icons.record_voice_over_outlined, size: 18),
                                      ),
                                      items: _brandTones.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                      onChanged: (val) => setState(() => _selectedBrandTone = val ?? _selectedBrandTone),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Short Description (with strict 80-char counter)
                              TextFormField(
                                controller: _shortDescController,
                                maxLength: 100,
                                decoration: InputDecoration(
                                  labelText: 'Short Description (Play Store max: 80 chars)',
                                  hintText: 'Concise summary of what makes your app essential',
                                  prefixIcon: const Icon(Icons.short_text, size: 18),
                                  helperText: '${_shortDescController.text.length}/80 characters',
                                  helperStyle: TextStyle(
                                    color: _shortDescController.text.length > 80 ? AppTheme.accentRose : null,
                                    fontWeight: _shortDescController.text.length > 80 ? FontWeight.bold : null,
                                  ),
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Full Description
                              TextFormField(
                                controller: _fullDescController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: 'Full Description',
                                  hintText: 'Detailed description explaining features, benefits, and usage...',
                                  alignLabelWithHint: true,
                                  helperText: '${_fullDescController.text.length} characters (Play Store allows up to 4000)',
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Main Features (Chip list)
                              _buildChipSection(
                                title: 'Key Features (${_mainFeatures.length})',
                                subtitle: 'Add individual features to generate feature-specific video scripts and captions.',
                                items: _mainFeatures,
                                inputController: _featureInputController,
                                hint: 'e.g., Offline Cloud Sync, Smart Reminders',
                                onAdd: (val) {
                                  if (val.trim().isNotEmpty && !_mainFeatures.contains(val.trim())) {
                                    setState(() {
                                      _mainFeatures.add(val.trim());
                                      _featureInputController.clear();
                                    });
                                  }
                                },
                                onRemove: (val) => setState(() => _mainFeatures.remove(val)),
                              ),
                              const SizedBox(height: 16),

                              // Unique Selling Points (Chip list)
                              _buildChipSection(
                                title: 'Unique Selling Points (${_uniqueSellingPoints.length})',
                                subtitle: 'What makes your app stand out versus direct competitors?',
                                items: _uniqueSellingPoints,
                                inputController: _uspInputController,
                                hint: 'e.g., 100% Free & No Ads, Privacy-first',
                                onAdd: (val) {
                                  if (val.trim().isNotEmpty && !_uniqueSellingPoints.contains(val.trim())) {
                                    setState(() {
                                      _uniqueSellingPoints.add(val.trim());
                                      _uspInputController.clear();
                                    });
                                  }
                                },
                                onRemove: (val) => setState(() => _uniqueSellingPoints.remove(val)),
                              ),
                              const SizedBox(height: 16),

                              // Target Audience & Preferred CTA
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _targetAudienceController,
                                      decoration: const InputDecoration(
                                        labelText: 'Target Audience Persona',
                                        hintText: 'e.g., Remote software developers and students',
                                        prefixIcon: Icon(Icons.people_outline, size: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedCta,
                                      decoration: const InputDecoration(
                                        labelText: 'Preferred Call-to-Action',
                                        prefixIcon: Icon(Icons.touch_app_outlined, size: 18),
                                      ),
                                      items: _ctaOptions.map((cta) => DropdownMenuItem(value: cta, child: Text(cta, overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (val) => setState(() => _selectedCta = val ?? _selectedCta),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Privacy Policy URL & Website URL
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _privacyPolicyUrlController,
                                      decoration: const InputDecoration(
                                        labelText: 'Privacy Policy URL * (Play requirement)',
                                        hintText: 'https://mysite.com/privacy',
                                        prefixIcon: Icon(Icons.shield_outlined, size: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _websiteUrlController,
                                      decoration: const InputDecoration(
                                        labelText: 'Website / Support URL',
                                        hintText: 'https://mysite.com',
                                        prefixIcon: Icon(Icons.language, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Icon Path
                              TextFormField(
                                controller: _iconPathController,
                                decoration: const InputDecoration(
                                  labelText: 'Local Icon File Path',
                                  hintText: 'e.g., C:/assets/icon.png',
                                  prefixIcon: Icon(Icons.image_outlined, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const VerticalDivider(width: 24),

                    // Listing Quality Checklist Side-Panel
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Listing Quality Score',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getScoreColor(quality.score).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${quality.score}% • ${quality.grade}',
                                    style: TextStyle(
                                      color: _getScoreColor(quality.score),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: quality.score / 100,
                                minHeight: 8,
                                backgroundColor: Theme.of(context).dividerColor,
                                valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(quality.score)),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Play Store Readiness Checklist:',
                              style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: quality.items.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 6),
                                itemBuilder: (context, idx) {
                                  final item = quality.items[idx];
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        item.isPassed ? Icons.check_circle : Icons.radio_button_unchecked,
                                        size: 16,
                                        color: item.isPassed ? AppTheme.accentEmerald : AppTheme.darkTextSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: item.isPassed ? FontWeight.w500 : FontWeight.normal,
                                                color: item.isPassed ? null : AppTheme.darkTextSecondary,
                                              ),
                                            ),
                                            if (!item.isPassed && item.recommendation != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                item.recommendation!,
                                                style: const TextStyle(fontSize: 11, color: AppTheme.accentAmber),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 28),

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
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEditing ? 'Save Changes' : 'Register App'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChipSection({
    required String title,
    required String subtitle,
    required List<String> items,
    required TextEditingController inputController,
    required String hint,
    required ValueChanged<String> onAdd,
    required ValueChanged<String> onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: inputController,
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onFieldSubmitted: onAdd,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => onAdd(inputController.text),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((item) {
              return Chip(
                label: Text(item, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => onRemove(item),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.accentEmerald;
    if (score >= 60) return AppTheme.accentAmber;
    return AppTheme.accentRose;
  }
}
