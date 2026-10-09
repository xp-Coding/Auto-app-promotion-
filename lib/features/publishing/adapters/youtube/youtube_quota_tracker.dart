import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/platform_adapter.dart';

class YouTubeQuotaTracker {
  final Database? _db;
  static const String _settingKey = 'youtube_quota_usage';
  static const int defaultDailyQuota = 10000;
  static const int costVideoInsert = 1600;
  static const int costVideoList = 1;
  static const int costChannelList = 1;

  YouTubeQuotaTracker([this._db]);

  Future<Database> get _database async => _db ?? await AppDatabase.instance.database;

  /// Returns current date string in Pacific Time (PT), YouTube's quota reset boundary
  String _currentPacificDateString() {
    // Pacific standard time is UTC-8
    final ptNow = DateTime.now().toUtc().subtract(const Duration(hours: 8));
    return "${ptNow.year.toString().padLeft(4, '0')}-${ptNow.month.toString().padLeft(2, '0')}-${ptNow.day.toString().padLeft(2, '0')}";
  }

  DateTime _nextResetTime() {
    final ptNow = DateTime.now().toUtc().subtract(const Duration(hours: 8));
    final tomorrowPt = DateTime.utc(ptNow.year, ptNow.month, ptNow.day + 1);
    // Convert back to UTC (+8 hours)
    return tomorrowPt.add(const Duration(hours: 8));
  }

  Future<Map<String, dynamic>> _readUsageMap() async {
    final db = await _database;
    final maps = await db.query(
      'application_settings',
      where: 'key = ?',
      whereArgs: [_settingKey],
      limit: 1,
    );

    final todayPt = _currentPacificDateString();

    if (maps.isEmpty) {
      return {'date': todayPt, 'units_used': 0, 'daily_limit': defaultDailyQuota};
    }

    try {
      final raw = maps.first['value'] as String;
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final recordedDate = parsed['date'] as String? ?? '';

      // If recorded date is not today in PT, quota has reset!
      if (recordedDate != todayPt) {
        return {'date': todayPt, 'units_used': 0, 'daily_limit': defaultDailyQuota};
      }
      return parsed;
    } catch (_) {
      return {'date': todayPt, 'units_used': 0, 'daily_limit': defaultDailyQuota};
    }
  }

  Future<void> _writeUsageMap(Map<String, dynamic> data) async {
    final db = await _database;
    await db.insert(
      'application_settings',
      {
        'key': _settingKey,
        'value': jsonEncode(data),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<QuotaStatus> getStatus() async {
    final usage = await _readUsageMap();
    final used = (usage['units_used'] as num?)?.toInt() ?? 0;
    final limit = (usage['daily_limit'] as num?)?.toInt() ?? defaultDailyQuota;
    final remaining = mathMax(0, limit - used);

    return QuotaStatus(
      dailyLimit: limit,
      usedToday: used,
      remaining: remaining,
      isExceeded: used >= limit,
      resetsAt: _nextResetTime(),
    );
  }

  Future<bool> canConsume(int units) async {
    final status = await getStatus();
    return (status.usedToday + units) <= status.dailyLimit;
  }

  Future<void> recordConsumption(int units) async {
    final usage = await _readUsageMap();
    final used = (usage['units_used'] as num?)?.toInt() ?? 0;
    usage['units_used'] = used + units;
    await _writeUsageMap(usage);
  }

  int mathMax(int a, int b) => a > b ? a : b;
}
