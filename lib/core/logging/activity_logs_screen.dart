import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'activity_log_model.dart';
import 'activity_log_repository.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final _repo = ActivityLogRepository();
  final _searchController = TextEditingController();

  String _selectedLevel = 'all';
  String _selectedCategory = 'all';
  List<ActivityLogModel> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _repo.getLogs(
      level: _selectedLevel == 'all' ? null : _selectedLevel,
      category: _selectedCategory == 'all' ? null : _selectedCategory,
      searchQuery: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
    );
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleClearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Activity Logs?'),
        content: const Text('This will delete all stored audit and activity log entries from SQLite.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentRose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.clearLogs();
      await _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local Activity & Audit Logs',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Structured local SQLite event records for publishing jobs, OAuth events, and analytics sync.',
                      style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      onPressed: _loadLogs,
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRose),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Clear Logs'),
                      onPressed: _handleClearLogs,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Bar
            Row(
              children: [
                // Level ChoiceChips
                Wrap(
                  spacing: 8,
                  children: [
                    _buildLevelChip('all', 'All Levels'),
                    _buildLevelChip('info', 'Info'),
                    _buildLevelChip('success', 'Success'),
                    _buildLevelChip('warn', 'Warnings'),
                    _buildLevelChip('error', 'Errors'),
                  ],
                ),
                const SizedBox(width: 16),
                // Category dropdown
                DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: Theme.of(context).cardColor,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Categories')),
                    DropdownMenuItem(value: 'publishing', child: Text('Publishing')),
                    DropdownMenuItem(value: 'auth', child: Text('Authentication')),
                    DropdownMenuItem(value: 'analytics', child: Text('Analytics')),
                    DropdownMenuItem(value: 'database', child: Text('Database')),
                    DropdownMenuItem(value: 'system', child: Text('System')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                      _loadLogs();
                    }
                  },
                ),
                const Spacer(),
                // Search field
                SizedBox(
                  width: 260,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search logs...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _loadLogs(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Logs List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notes, size: 48, color: Theme.of(context).hintColor),
                              const SizedBox(height: 12),
                              const Text('No log entries match your criteria', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text('Events will appear here as you publish content and manage campaigns.', style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _logs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final levelColor = _getLevelColor(log.level);

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Theme.of(context).dividerColor),
                              ),
                              child: ExpansionTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: levelColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(_getLevelIcon(log.level), color: levelColor, size: 18),
                                ),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).dividerColor.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        log.category.toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        log.message,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp.toLocal()),
                                  style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                                ),
                                children: [
                                  if (log.details != null && log.details!.isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).scaffoldBackgroundColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: SelectableText(
                                        const JsonEncoder.withIndent('  ').convert(log.details),
                                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelChip(String level, String label) {
    final isSelected = _selectedLevel == level;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedLevel = level);
        _loadLogs();
      },
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'success':
        return AppTheme.accentEmerald;
      case 'warn':
        return AppTheme.accentAmber;
      case 'error':
        return AppTheme.accentRose;
      case 'info':
      default:
        return AppTheme.primaryIndigo;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'success':
        return Icons.check_circle_outline;
      case 'warn':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }
}
