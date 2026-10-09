import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/app_database.dart';
import '../models/social_account_model.dart';

class SocialAccountsRepository {
  final Database? _db;

  SocialAccountsRepository([this._db]);

  Future<Database> get _database async => _db ?? await AppDatabase.instance.database;

  /// Retrieve all social accounts
  Future<List<SocialAccountModel>> getAccounts() async {
    final db = await _database;
    final maps = await db.query('social_accounts', orderBy: 'connected_at DESC');
    return maps.map(SocialAccountModel.fromMap).toList();
  }

  /// Retrieve specific account by platform (youtube, facebook, instagram, tiktok)
  Future<SocialAccountModel?> getAccountByPlatform(String platform) async {
    final db = await _database;
    final maps = await db.query(
      'social_accounts',
      where: 'platform = ?',
      whereArgs: [platform],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SocialAccountModel.fromMap(maps.first);
  }

  /// Insert or update social account
  Future<void> saveAccount(SocialAccountModel account) async {
    final db = await _database;
    await db.insert(
      'social_accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update account connection status
  Future<void> updateAccountStatus(String platform, String status) async {
    final db = await _database;
    final now = DateTime.now().toUtc();
    await db.update(
      'social_accounts',
      {
        'status': status,
        'last_synced_at': now.toIso8601String(),
      },
      where: 'platform = ?',
      whereArgs: [platform],
    );
  }

  /// Disconnect account
  Future<void> disconnectAccount(String platform) async {
    final db = await _database;
    await db.update(
      'social_accounts',
      {'status': 'disconnected'},
      where: 'platform = ?',
      whereArgs: [platform],
    );
  }

  /// Remove account completely
  Future<void> deleteAccount(String id) async {
    final db = await _database;
    await db.delete('social_accounts', where: 'id = ?', whereArgs: [id]);
  }
}
