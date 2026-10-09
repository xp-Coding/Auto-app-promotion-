import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/app_database.dart';
import 'activity_log_model.dart';

class ActivityLogRepository {
  final Database? _rawDb;
  final AppDatabase _dbProvider;

  ActivityLogRepository({AppDatabase? dbProvider, Database? db})
      : _dbProvider = dbProvider ?? AppDatabase.instance,
        _rawDb = db;

  Future<Database> get _database async => _rawDb ?? await _dbProvider.database;

  Future<void> addLog(ActivityLogModel log) async {
    final db = await _database;
    await db.insert('activity_logs', log.toMap());
  }

  Future<List<ActivityLogModel>> getLogs({
    String? level,
    String? category,
    String? searchQuery,
    int limit = 100,
  }) async {
    final db = await _database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (level != null && level.isNotEmpty && level != 'all') {
      whereClauses.add('level = ?');
      whereArgs.add(level.toLowerCase());
    }

    if (category != null && category.isNotEmpty && category != 'all') {
      whereClauses.add('category = ?');
      whereArgs.add(category.toLowerCase());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(message LIKE ? OR details_json LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      whereArgs.addAll([term, term]);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      'activity_logs',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map(ActivityLogModel.fromMap).toList();
  }

  Future<void> clearLogs() async {
    final db = await _database;
    await db.delete('activity_logs');
  }

  Future<int> pruneOldLogs({int daysToKeep = 30}) async {
    final db = await _database;
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: daysToKeep)).toIso8601String();
    return db.delete('activity_logs', where: 'timestamp < ?', whereArgs: [cutoff]);
  }
}
