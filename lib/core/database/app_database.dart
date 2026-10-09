import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'migrations.dart';
import 'sqlite_initializer.dart';

/// Database provider and connection manager for AppGrowth Studio.
class AppDatabase {
  static AppDatabase? _instance;
  Database? _db;

  AppDatabase._();

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  /// Get or initialize the active SQLite database instance.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  /// Determine the storage path for the local SQLite database.
  static String getDatabaseDirectoryPath() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? Platform.environment['USERPROFILE'] ?? '.';
      final dir = Directory(p.join(appData, 'AppGrowthStudio'));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir.path;
    } else {
      final dir = Directory(p.join(Directory.current.path, '.data'));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir.path;
    }
  }

  static String getDatabaseFilePath() {
    return p.join(getDatabaseDirectoryPath(), 'appgrowth_studio.db');
  }

  /// The absolute path to the active SQLite database file.
  String get databasePath => getDatabaseFilePath();

  Future<Database> _initDatabase() async {
    SqliteInitializer.initialize();

    final dbPath = getDatabaseFilePath();
    debugPrint('Opening AppGrowth Studio database at: $dbPath');

    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.currentVersion,
        onConfigure: (db) async {
          // Enable Foreign Keys and WAL Mode for desktop reliability
          await db.execute('PRAGMA foreign_keys = ON;');
          await db.execute('PRAGMA journal_mode = WAL;');
        },
        onCreate: DatabaseMigrations.onCreate,
        onUpgrade: DatabaseMigrations.onUpgrade,
      ),
    );

    return db;
  }

  /// Closes the database cleanly.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
