import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/activity_log_repository.dart';
import '../../../core/services/safe_background_worker.dart';
import '../../../core/theme/app_theme.dart';
import '../../apps/providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _dbPath = 'Loading...';
  String _dbSize = 'Loading...';
  List<File> _backups = [];
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadSystemInfo();
  }

  Future<void> _loadSystemInfo() async {
    try {
      final path = AppDatabase.instance.databasePath;
      final file = File(path);
      String sizeStr = '0 KB';
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        sizeStr = bytes > 1024 * 1024
            ? '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB'
            : '${(bytes / 1024).toStringAsFixed(1)} KB';
      }

      final backups = await BackupService.instance.listBackups();

      if (mounted) {
        setState(() {
          _dbPath = path;
          _dbSize = sizeStr;
          _backups = backups;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleCreateBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final backupFile = await BackupService.instance.createBackup();
      await _loadSystemInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup created: ${backupFile.path}'),
            backgroundColor: AppTheme.accentEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup error: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleRestoreBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Database Restore?'),
        content: Text(
          'Are you sure you want to restore from ${file.uri.pathSegments.last}? Current database will be backed up safely before replacing.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentAmber),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Database'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRestoring = true);
    try {
      final success = await BackupService.instance.restoreBackup(file);
      await _loadSystemInfo();
      if (mounted) {
        if (success) {
          ref.invalidate(appsListProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database restored successfully!'),
              backgroundColor: AppTheme.accentEmerald,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restore failed integrity check.'), backgroundColor: AppTheme.accentRose),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _handlePruneLogs() async {
    final deleted = await ActivityLogRepository().pruneOldLogs(daysToKeep: 30);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pruned $deleted activity logs older than 30 days.'),
          backgroundColor: AppTheme.accentEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgWorkerActive = SafeBackgroundWorker.instance.isActive;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings & System Management',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage local database backups, background queue processing, and system diagnostics.',
                  style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Card 1: System & SQLite Diagnostics
            _buildCard(
              title: 'System & Local Database Diagnostics',
              icon: Icons.storage_outlined,
              child: Column(
                children: [
                  _buildDiagRow('Database File', _dbPath),
                  const Divider(height: 16),
                  _buildDiagRow('Database Size on Disk', _dbSize),
                  const Divider(height: 16),
                  _buildDiagRow('Concurrency & Journal Mode', 'Write-Ahead Logging (WAL Mode)'),
                  const Divider(height: 16),
                  _buildDiagRow('Foreign Key Constraints', 'Enabled (ON DELETE CASCADE)'),
                  const Divider(height: 16),
                  _buildDiagRow('Platform / Runtime', 'Windows Desktop (Pure Dart SQLite FFI)'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card 2: Backup & Restore
            _buildCard(
              title: 'Database Backup & Restore',
              icon: Icons.backup_outlined,
              action: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
                icon: _isBackingUp
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add, size: 18),
                label: const Text('Create New Backup'),
                onPressed: _isBackingUp ? null : _handleCreateBackup,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backups are complete, checkpointed copies of your local SQLite database including all apps, campaigns, keyword research, and published post attributions.',
                    style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (_backups.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No backup files found yet. Click "Create New Backup" above.'),
                    ),
                  ] else ...[
                    const Text('Available Backups:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _backups.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final file = _backups[index];
                        final name = file.uri.pathSegments.last;
                        final mod = DateFormat('yyyy-MM-dd HH:mm').format(file.lastModifiedSync().toLocal());
                        final size = '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.inventory_2_outlined, color: AppTheme.accentCyan, size: 22),
                          title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('$mod • $size', style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                          trailing: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Restore'),
                            onPressed: _isRestoring ? null : () => _handleRestoreBackup(file),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card 3: Safe Windows Background Execution
            _buildCard(
              title: 'Windows Background Execution & Heartbeat',
              icon: Icons.sync_alt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Periodic Queue Heartbeat (30s interval)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            bgWorkerActive
                                ? 'Active: Automatically checks and processes due publishing jobs while app is open.'
                                : 'Paused: Background auto-publishing is currently paused.',
                            style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                          ),
                        ],
                      ),
                      Switch(
                        value: bgWorkerActive,
                        onChanged: (val) {
                          if (val) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Background worker active.')),
                            );
                          } else {
                            SafeBackgroundWorker.instance.stop();
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Restart Recovery: When the application launches, interrupted jobs are automatically detected, verified against remote platform endpoints, and safely recovered.',
                    style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card 4: Maintenance & Data Retention
            _buildCard(
              title: 'Data Retention & Maintenance',
              icon: Icons.cleaning_services_outlined,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prune Activity Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: 2),
                      Text('Remove activity log entries older than 30 days to save space.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Prune Old Logs'),
                    onPressed: _handlePruneLogs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    Widget? action,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppTheme.primaryIndigo, size: 20),
                    const SizedBox(width: 10),
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDiagRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
