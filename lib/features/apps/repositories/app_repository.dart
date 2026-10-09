import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:appgrowth_studio/core/database/app_database.dart';
import '../models/app_model.dart';

/// Exception thrown for application data errors.
class AppRepositoryException implements Exception {
  final String message;
  const AppRepositoryException(this.message);

  @override
  String toString() => message;
}

/// SQLite Repository for managing registered Google Play apps.
class AppRepository {
  final AppDatabase _dbProvider;

  AppRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<Database> get _db => _dbProvider.database;

  /// Retrieves registered applications with optional search and category filters.
  Future<List<AppModel>> getAllApps({
    bool includeArchived = false,
    String? searchQuery,
    String? category,
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (!includeArchived) {
      whereClauses.add('is_archived = 0');
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR package_name LIKE ? OR category LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      whereArgs.addAll([term, term, term]);
    }

    if (category != null && category.trim().isNotEmpty && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category.trim());
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'apps',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'updated_at DESC',
    );

    return results.map((map) => AppModel.fromMap(map)).toList();
  }

  /// Retrieves a specific application by unique ID.
  Future<AppModel?> getAppById(String id) async {
    final db = await _db;
    final results = await db.query(
      'apps',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return AppModel.fromMap(results.first);
  }

  /// Retrieves a specific application by package name.
  Future<AppModel?> getAppByPackageName(String packageName) async {
    final db = await _db;
    final results = await db.query(
      'apps',
      where: 'package_name = ?',
      whereArgs: [packageName.trim()],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return AppModel.fromMap(results.first);
  }

  /// Registers a new application, enforcing duplicate package name constraints.
  Future<AppModel> createApp(AppModel app) async {
    final db = await _db;

    // Check for duplicate package name
    final existing = await getAppByPackageName(app.packageName);
    if (existing != null) {
      throw AppRepositoryException(
        'An application with package name "${app.packageName}" is already registered (${existing.name}).',
      );
    }

    await db.insert('apps', app.toMap());
    return app;
  }

  /// Updates an existing application.
  Future<AppModel> updateApp(AppModel app) async {
    final db = await _db;

    // Verify app exists
    final existing = await getAppById(app.id);
    if (existing == null) {
      throw AppRepositoryException('Application with ID "${app.id}" was not found.');
    }

    // Check if package name changed to another existing app
    if (existing.packageName != app.packageName) {
      final conflict = await getAppByPackageName(app.packageName);
      if (conflict != null && conflict.id != app.id) {
        throw AppRepositoryException(
          'Package name "${app.packageName}" is already used by "${conflict.name}".',
        );
      }
    }

    final updated = app.copyWith(updatedAt: DateTime.now().toUtc());
    await db.update(
      'apps',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [app.id],
    );

    return updated;
  }

  /// Sets the archive status of an application.
  Future<void> archiveApp(String id, bool archive) async {
    final db = await _db;
    await db.update(
      'apps',
      {
        'is_archived': archive ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Permanently deletes an application and cascades associated records.
  Future<void> deleteApp(String id) async {
    final db = await _db;
    await db.delete(
      'apps',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns total count of active apps.
  Future<int> getActiveAppsCount() async {
    final db = await _db;
    final res = await db.rawQuery('SELECT COUNT(*) AS total FROM apps WHERE is_archived = 0');
    if (res.isNotEmpty && res.first['total'] != null) {
      return (res.first['total'] as num).toInt();
    }
    return 0;
  }
}
