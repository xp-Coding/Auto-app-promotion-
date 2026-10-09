import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/models/app_model.dart';
import '../providers/keyword_providers.dart';

class KeywordImportExportDialog extends ConsumerStatefulWidget {
  final AppModel app;

  const KeywordImportExportDialog({super.key, required this.app});

  static void show(BuildContext context, AppModel app) {
    showDialog(
      context: context,
      builder: (context) => KeywordImportExportDialog(app: app),
    );
  }

  @override
  ConsumerState<KeywordImportExportDialog> createState() => _KeywordImportExportDialogState();
}

class _KeywordImportExportDialogState extends ConsumerState<KeywordImportExportDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _importTextController = TextEditingController();
  String _exportCsv = '';
  bool _isLoadingExport = true;
  bool _isImporting = false;
  String? _importStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExportCsv();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _importTextController.dispose();
    super.dispose();
  }

  Future<void> _loadExportCsv() async {
    setState(() => _isLoadingExport = true);
    final repo = ref.read(keywordRepositoryProvider);
    final csv = await repo.exportKeywordsToCsv(widget.app.id);
    setState(() {
      _exportCsv = csv;
      _isLoadingExport = false;
    });
  }

  Future<void> _handleImport() async {
    final text = _importTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste CSV content to import')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _importStatus = null;
    });

    try {
      final count = await ref.read(keywordsListProvider.notifier).importFromCsv(widget.app.id, text);
      setState(() {
        _isImporting = false;
        _importStatus = 'Successfully imported $count keywords into SQLite!';
      });
      _importTextController.clear();
      _loadExportCsv();
    } catch (e) {
      setState(() {
        _isImporting = false;
        _importStatus = 'Import error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
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
                        child: const Icon(Icons.import_export, color: AppTheme.primaryIndigo, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Keywords CSV Import / Export',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'App: ${widget.app.name} • RFC 4180 Compliant',
                            style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 14),

              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.file_upload_outlined, size: 18), text: 'Export Keywords'),
                  Tab(icon: Icon(Icons.file_download_outlined, size: 18), text: 'Import Keywords'),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Export Tab
                    _isLoadingExport
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Generated CSV Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy CSV to Clipboard'),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: _exportCsv));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('CSV copied to clipboard')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                  ),
                                  child: SelectableText(
                                    _exportCsv.isEmpty ? 'No keywords stored yet to export.' : _exportCsv,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
                                  ),
                                ),
                              ),
                            ],
                          ),

                    // Import Tab
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Paste CSV Data (Header: Keyword, Topic Cluster, Intent, Score, Source, Date, Notes):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _importTextController,
                            maxLines: 8,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Keyword,Topic Cluster,Intent,Score,Source,Date,Notes\nbest habit tracker,Tutorials,commercial,85.0,manual,2026-10-09,Key topic',
                            ),
                          ),
                        ),
                        if (_importStatus != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _importStatus!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _importStatus!.contains('Error') ? AppTheme.accentRose : AppTheme.accentEmerald,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: _isImporting
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload, size: 16),
                          label: const Text('Execute CSV Import'),
                          onPressed: _isImporting ? null : _handleImport,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
