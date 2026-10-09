import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/models/app_model.dart';
import '../../apps/providers/app_providers.dart';
import '../domain/keyword_relevance_scorer.dart';
import '../models/keyword_model.dart';
import '../providers/keyword_providers.dart';

class KeywordFormDialog extends ConsumerStatefulWidget {
  final String? initialKeyword;

  const KeywordFormDialog({super.key, this.initialKeyword});

  static Future<bool?> show(BuildContext context, {String? initialKeyword}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => KeywordFormDialog(initialKeyword: initialKeyword),
    );
  }

  @override
  ConsumerState<KeywordFormDialog> createState() => _KeywordFormDialogState();
}

class _KeywordFormDialogState extends ConsumerState<KeywordFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _keywordController;
  final _topicClusterController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedIntent = 'informational';
  final String _selectedSource = 'manual';
  AppModel? _selectedApp;
  bool _isSaving = false;

  static const List<String> _intents = [
    'informational',
    'commercial',
    'navigational',
    'transactional',
  ];

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController(text: widget.initialKeyword ?? '');
    _keywordController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedApp ??= ref.read(selectedAppProvider) ?? ref.read(appsListProvider).value?.firstOrNull;
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _topicClusterController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  ScoreExplanation? get _currentScoreExplanation {
    if (_selectedApp == null || _keywordController.text.trim().isEmpty) return null;
    return KeywordRelevanceScorer.calculateScore(
      keyword: _keywordController.text.trim(),
      app: _selectedApp!,
      intent: _selectedIntent,
      source: _selectedSource,
    );
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
    final explanation = _currentScoreExplanation;
    final now = DateTime.now().toUtc();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    try {
      final model = KeywordModel(
        id: const Uuid().v4(),
        appId: _selectedApp!.id,
        keyword: _keywordController.text.trim(),
        topicCluster: _topicClusterController.text.trim().isNotEmpty ? _topicClusterController.text.trim() : null,
        intent: _selectedIntent,
        relevanceScore: explanation?.score ?? 50.0,
        source: _selectedSource,
        retrievalDate: todayStr,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: now,
      );

      await ref.read(keywordsListProvider.notifier).addKeyword(model);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving keyword: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(appsListProvider).value ?? [];
    final explanation = _currentScoreExplanation;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
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
                          child: const Icon(Icons.tag, color: AppTheme.primaryIndigo, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Keyword or Topic Idea',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Catalog long-tail keywords with transparent qualitative relevance scoring.',
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

                // App & Keyword text
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
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
                      flex: 6,
                      child: TextFormField(
                        controller: _keywordController,
                        decoration: const InputDecoration(
                          labelText: 'Keyword or Long-Tail Phrase *',
                          hintText: 'e.g., best habit tracker for android',
                          prefixIcon: Icon(Icons.search, size: 18),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Keyword is required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Intent & Topic Cluster
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedIntent,
                        decoration: const InputDecoration(labelText: 'Audience Intent *', prefixIcon: Icon(Icons.psychology_outlined, size: 18)),
                        items: _intents.map((i) => DropdownMenuItem(value: i, child: Text(i.toUpperCase()))).toList(),
                        onChanged: (val) => setState(() => _selectedIntent = val ?? _selectedIntent),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _topicClusterController,
                        decoration: const InputDecoration(
                          labelText: 'Topic Cluster / Category',
                          hintText: 'e.g., Feature Tutorials, Competitor Angles',
                          prefixIcon: Icon(Icons.folder_open, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Qualitative Score Explanation Card
                if (explanation != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Qualitative Relevance Score:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accentEmerald.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${explanation.score.toStringAsFixed(0)}% Score',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentEmerald),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: explanation.score / 100,
                          minHeight: 6,
                          color: AppTheme.accentEmerald,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          explanation.rationale,
                          style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                        ),
                        if (explanation.contributingFactors.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...explanation.contributingFactors.map(
                            (f) => Text('• $f', style: const TextStyle(fontSize: 11, color: AppTheme.accentCyan)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Research Notes',
                    hintText: 'e.g., Identified in YouTube comments for competing productivity video',
                    prefixIcon: Icon(Icons.note_alt_outlined, size: 18),
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
                          : const Text('Save Keyword'),
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
