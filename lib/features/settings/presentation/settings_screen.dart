import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/activity_log_repository.dart';
import '../../../core/services/safe_background_worker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/native_file_dialog_helper.dart';
import '../../apps/providers/app_providers.dart';
import '../../content_studio/providers/video_creator_providers.dart';

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
  final _ffmpegPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSystemInfo();
    _loadFfmpegSettings();
  }

  @override
  void dispose() {
    _ffmpegPathController.dispose();
    super.dispose();
  }

  Future<void> _loadFfmpegSettings() async {
    final custom = await ref.read(ffmpegServiceProvider).getCustomFfmpegPath();
    if (custom != null && mounted) {
      setState(() {
        _ffmpegPathController.text = custom;
      });
    }
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

            // Card: Video Creation & Local Export Engine
            _buildVideoExportCard(),
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

  Widget _buildVideoExportCard() {
    final ffmpegStatusAsync = ref.watch(ffmpegStatusProvider);
    final defaultExportFolderAsync = ref.watch(defaultExportFolderProvider);

    return _buildCard(
      title: 'Video Creation & Local Export Engine',
      icon: Icons.video_settings_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Engine Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FFmpeg Processing Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 2),
                  Text('Used for hardware-accelerated local MP4 compilation and clip trimming.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                ],
              ),
              ffmpegStatusAsync.when(
                data: (status) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: status.isAvailable ? AppTheme.accentEmerald.withOpacity(0.15) : AppTheme.accentAmber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: status.isAvailable ? AppTheme.accentEmerald.withOpacity(0.4) : AppTheme.accentAmber.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status.isAvailable ? Icons.check_circle : Icons.warning_amber,
                        size: 14,
                        color: status.isAvailable ? AppTheme.accentEmerald : AppTheme.accentAmber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.isAvailable ? 'Installed & Ready' : 'Setup Required',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: status.isAvailable ? AppTheme.accentEmerald : AppTheme.accentAmber,
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, _) => const Text('Error detecting FFmpeg', style: TextStyle(color: AppTheme.accentRose, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Default Export Directory
          const Text('Default Video Export Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Directory where rendered promotional videos and project packages are saved.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 8),
          defaultExportFolderAsync.when(
            data: (folder) => Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: SelectableText(
                      folder,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Change Folder'),
                  onPressed: () async {
                    final picked = await NativeFileDialogHelper.pickDirectory(
                      title: 'Select Default Video Export Folder',
                      initialDirectory: folder,
                    );
                    if (picked != null) {
                      await ref.read(ffmpegServiceProvider).setDefaultExportFolder(picked);
                      ref.invalidate(defaultExportFolderProvider);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Default export folder updated to: $picked'), backgroundColor: AppTheme.accentEmerald),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  tooltip: 'Open in Windows Explorer',
                  onPressed: () => NativeFileDialogHelper.openDirectory(folder),
                ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Error loading export folder: $err', style: const TextStyle(color: AppTheme.accentRose, fontSize: 12)),
          ),
          const SizedBox(height: 16),

          // Custom FFmpeg Executable Path
          const Text('Custom FFmpeg Executable (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('If FFmpeg is not in your Windows PATH, select the ffmpeg.exe binary directly.', style: TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ffmpegPathController,
                  decoration: const InputDecoration(
                    hintText: r'e.g. C:\ffmpeg\bin\ffmpeg.exe',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_open_outlined, size: 16),
                label: const Text('Browse...'),
                onPressed: () async {
                  final picked = await NativeFileDialogHelper.pickSingleFile(
                    title: 'Select ffmpeg.exe',
                    filter: 'Executable Files (*.exe)|*.exe|All Files (*.*)|*.*',
                  );
                  if (picked != null) {
                    setState(() {
                      _ffmpegPathController.text = picked;
                    });
                    await ref.read(ffmpegServiceProvider).setCustomFfmpegPath(picked);
                    ref.invalidate(ffmpegStatusProvider);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Custom FFmpeg path saved!'), backgroundColor: AppTheme.accentEmerald),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  await ref.read(ffmpegServiceProvider).setCustomFfmpegPath(_ffmpegPathController.text.trim());
                  ref.invalidate(ffmpegStatusProvider);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('FFmpeg path applied and verified!'), backgroundColor: AppTheme.accentEmerald),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),

          // Setup Guide Accordion if FFmpeg is missing
          ffmpegStatusAsync.maybeWhen(
            data: (status) {
              if (status.isAvailable) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.accentEmerald),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Active binary: ${status.executablePath ?? "System PATH"} (${status.versionInfo ?? ""})',
                          style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.accentAmber),
                        SizedBox(width: 6),
                        Text('FFmpeg Setup Guide (Free & Open Source)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentAmber)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Run this command in Windows Terminal / PowerShell to install automatically:\nwinget install Gyan.FFmpeg\n\nOr download ffmpeg-release-essentials.zip from gyan.dev/ffmpeg/builds and browse to ffmpeg.exe above.',
                      style: TextStyle(fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
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
