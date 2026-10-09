import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../models/campaign_model.dart';

class CampaignRepository {
  final AppDatabase _dbProvider;

  CampaignRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<Database> get _db => _dbProvider.database;

  Future<List<CampaignModel>> getAllCampaigns({String? appId, String? status}) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (appId != null && appId.trim().isNotEmpty) {
      whereClauses.add('app_id = ?');
      whereArgs.add(appId.trim());
    }

    if (status != null && status.trim().isNotEmpty && status != 'All') {
      whereClauses.add('status = ?');
      whereArgs.add(status.trim().toLowerCase());
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'campaigns',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'updated_at DESC',
    );

    final campaigns = <CampaignModel>[];
    for (final map in results) {
      final campId = map['id'] as String;
      final platformRows = await db.query(
        'campaign_platforms',
        where: 'campaign_id = ?',
        whereArgs: [campId],
      );
      final platforms = platformRows.map((r) => r['platform'] as String).toList();
      campaigns.add(CampaignModel.fromMap(map, platforms: platforms));
    }

    return campaigns;
  }

  Future<CampaignModel?> getCampaignById(String id) async {
    final db = await _db;
    final results = await db.query('campaigns', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;

    final platformRows = await db.query(
      'campaign_platforms',
      where: 'campaign_id = ?',
      whereArgs: [id],
    );
    final platforms = platformRows.map((r) => r['platform'] as String).toList();
    return CampaignModel.fromMap(results.first, platforms: platforms);
  }

  Future<CampaignModel> createCampaign(CampaignModel campaign) async {
    final db = await _db;

    await db.transaction((txn) async {
      await txn.insert('campaigns', campaign.toMap());
      for (final platform in campaign.platforms) {
        await txn.insert('campaign_platforms', {
          'id': const Uuid().v4(),
          'campaign_id': campaign.id,
          'platform': platform,
        });
      }
    });

    return campaign;
  }

  Future<CampaignModel> updateCampaign(CampaignModel campaign) async {
    final db = await _db;
    final updated = campaign.copyWith(updatedAt: DateTime.now().toUtc());

    await db.transaction((txn) async {
      await txn.update(
        'campaigns',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [campaign.id],
      );

      // Re-link platforms
      await txn.delete(
        'campaign_platforms',
        where: 'campaign_id = ?',
        whereArgs: [campaign.id],
      );

      for (final platform in campaign.platforms) {
        await txn.insert('campaign_platforms', {
          'id': const Uuid().v4(),
          'campaign_id': campaign.id,
          'platform': platform,
        });
      }
    });

    return updated;
  }

  Future<void> updateCampaignStatus(String id, String status) async {
    final db = await _db;
    await db.update(
      'campaigns',
      {
        'status': status.toLowerCase(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCampaign(String id) async {
    final db = await _db;
    await db.delete('campaigns', where: 'id = ?', whereArgs: [id]);
  }
}
