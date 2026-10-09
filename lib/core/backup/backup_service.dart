import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../logging/app_logger.dart';

class BackupManifest {
  final String appName;
  final int backupVersion;
  final DateTime timestamp;
  final String databaseFileName;
  final int fileSize;

  const BackupManifest({
    required this.appName,
    required this.backupVersion,
    required this.timestamp,
    required this.databaseFileName,
    required this.fileSize,
  });

  Map<String, dynamic> toMap() => {
        'app_name': appName,
        'backup_version': backupVersion,
        'timestamp': timestamp.toIso8601String(),
        'database_file_name': databaseFileName,
        'file_size': fileSize,
      };

  factory BackupManifest.fromMap(Map<String, dynamic> map) => BackupManifest(
        appName: map['app_name'] as String,
        backupVersion: (map['backup_version'] as num).toInt(),
        timestamp: DateTime.parse(map['timestamp'] as String),
        databaseFileName: map['database_file_name'] as String,
        fileSize: (map['file_size'] as num).toInt(),
      );
}

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  /// Default backup directory in AppData
  Future<Directory> get _defaultBackupDir async {
    final appData = Platform.environment['APPDATA'] ?? '.';
    final dir = Directory('$appData\\AppGrowthStudio\\backups');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Create a complete, checkpointed backup of the local SQLite database
  Future<File> createBackup({String? targetDirectoryPath}) async {
    final db = await AppDatabase.instance.database;

    // 1. Force WAL checkpoint to flush all uncommitted pages to main file
    await db.rawQuery('PRAGMA wal_checkpoint(FULL);');

    final dbPath = AppDatabase.instance.databasePath;
    final sourceDbFile = File(dbPath);
    if (!sourceDbFile.existsSync()) {
      throw Exception('Source database file not found at: $dbPath');
    }

    final targetDir = targetDirectoryPath != null ? Directory(targetDirectoryPath) : await _defaultBackupDir;
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final now = DateTime.now().toUtc();
    final nowStr = DateFormat('yyyyMMdd_HHmmss').format(now);
    final backupFileName = 'AppGrowth_Backup_$nowStr.sqlite';
    final targetDbFile = File('${targetDir.path}\\$backupFileName');

    // 2. Copy SQLite file cleanly
    await sourceDbFile.copy(targetDbFile.path);

    // 3. Write manifest file alongside
    final manifest = BackupManifest(
      appName: 'AppGrowth Studio',
      backupVersion: 1,
      timestamp: now,
      databaseFileName: backupFileName,
      fileSize: targetDbFile.lengthSync(),
    );

    final manifestFile = File('${targetDir.path}\\AppGrowth_Backup_${nowStr}_manifest.json');
    await manifestFile.writeAsString(const JsonEncoder.withIndent('  ').convert(manifest.toMap()));

    await AppLogger.success('database', 'Full backup created successfully at ${targetDbFile.path}');
    return targetDbFile;
  }

  /// Validate backup file integrity
  Future<bool> validateBackupFile(File backupFile) async {
    if (!backupFile.existsSync()) return false;
    final length = await backupFile.length();
    if (length < 100) return false;

    // Read first 16 bytes: SQLite magic header is 'SQLite format 3\000'
    final bytes = await backupFile.openRead(0, 16).first;
    final header = String.fromCharCodes(bytes);
    return header.startsWith('SQLite format 3');
  }

  /// Restore database from a backup file
  Future<bool> restoreBackup(File backupFile) async {
    final isValid = await validateBackupFile(backupFile);
    if (!isValid) {
      throw Exception('The selected file is not a valid SQLite database backup.');
    }

    final dbPath = AppDatabase.instance.databasePath;
    final activeDbFile = File(dbPath);

    // 1. Close active database connection cleanly
    await AppDatabase.instance.close();

    // 2. Create emergency safety copy of current DB before overwriting
    if (activeDbFile.existsSync()) {
      final safetyCopy = File('${activeDbFile.path}.before_restore');
      await activeDbFile.copy(safetyCopy.path);
    }

    // 3. Overwrite active DB file with backup file
    await backupFile.copy(activeDbFile.path);

    // 4. Remove lingering -wal and -shm files if present
    final walFile = File('$dbPath-wal');
    if (walFile.existsSync()) walFile.deleteSync();
    final shmFile = File('$dbPath-shm');
    if (shmFile.existsSync()) shmFile.deleteSync();

    // 5. Re-open and verify database
    final db = await AppDatabase.instance.database;
    final integrity = await db.rawQuery('PRAGMA integrity_check;');
    final status = integrity.first['integrity_check'] as String?;

    if (status != 'ok') {
      await AppLogger.error('database', 'Restored database failed integrity check: $status');
      return false;
    }

    await AppLogger.success('database', 'Database restored successfully from ${backupFile.path}');
    return true;
  }

  /// List existing backups
  Future<List<File>> listBackups() async {
    final dir = await _defaultBackupDir;
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.sqlite')).toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }
}
