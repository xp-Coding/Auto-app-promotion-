import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:appgrowth_studio/core/database/app_database.dart';
import '../models/autopilot_run_model.dart';
import '../models/autopilot_settings_model.dart';

class AutopilotRepositoryException implements Exception {
  final String message;
  const AutopilotRepositoryException(this.message);

  @override
  String toString() => message;
}

/// SQLite Repository for managing Autopilot runs and configurations.
class AutopilotRepository {
  final AppDatabase _dbProvider;

  AutopilotRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<Database> get _db => _dbProvider.database;

  /// Loads current autopilot settings or creates default settings if missing.
  Future<AutopilotSettingsModel> getSettings() async {
    final db = await _db;
    final results = await db.query(
      'autopilot_settings',
      where: 'id = ?',
      whereArgs: ['default_autopilot_settings'],
      limit: 1,
    );

    if (results.isEmpty) {
      final defaultSettings = AutopilotSettingsModel(
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await db.insert('autopilot_settings', defaultSettings.toMap());
      return defaultSettings;
    }

    return AutopilotSettingsModel.fromMap(results.first);
  }

  /// Updates autopilot settings.
  Future<void> saveSettings(AutopilotSettingsModel settings) async {
    final db = await _db;
    final updated = settings.copyWith(updatedAt: DateTime.now().toUtc());
    await db.insert(
      'autopilot_settings',
      updated.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts a new autopilot run.
  Future<void> insertRun(AutopilotRunModel run) async {
    final db = await _db;
    await db.insert('autopilot_runs', run.toMap());
  }

  /// Updates an existing autopilot run.
  Future<void> updateRun(AutopilotRunModel run) async {
    final db = await _db;
    final updated = run.copyWith(updatedAt: DateTime.now().toUtc());
    await db.update(
      'autopilot_runs',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [run.id],
    );
  }

  /// Gets the most recent run for a specific app or system-wide.
  Future<AutopilotRunModel?> getLatestRun({String? appId}) async {
    final db = await _db;
    final results = await db.query(
      'autopilot_runs',
      where: appId != null ? 'app_id = ?' : null,
      whereArgs: appId != null ? [appId] : null,
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return AutopilotRunModel.fromMap(results.first);
  }

  /// Retrieves all runs history ordered by recency.
  Future<List<AutopilotRunModel>> getAllRuns({String? appId, int limit = 20}) async {
    final db = await _db;
    final results = await db.query(
      'autopilot_runs',
      where: appId != null ? 'app_id = ?' : null,
      whereArgs: appId != null ? [appId] : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return results.map((map) => AutopilotRunModel.fromMap(map)).toList();
  }

  /// Deletes or clears old runs.
  Future<void> deleteRun(String runId) async {
    final db = await _db;
    await db.delete(
      'autopilot_runs',
      where: 'id = ?',
      whereArgs: [runId],
    );
  }
}
