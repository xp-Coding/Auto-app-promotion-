import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/features/campaigns/models/campaign_model.dart';

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('Campaign SQLite Integration Tests', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onCreate: DatabaseMigrations.onCreate,
        ),
      );

      // Create a dummy app to satisfy foreign key
      await db.insert('apps', {
        'id': 'app-camp-1',
        'name': 'Test App',
        'package_name': 'com.test.camp',
        'play_store_url': 'https://play.google.com/store/apps/details?id=com.test.camp',
        'category': 'Productivity',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Campaign and platforms insert and query correctly', () async {
      final now = DateTime.now().toUtc();
      final campaign = CampaignModel(
        id: 'camp-1',
        appId: 'app-camp-1',
        name: 'Summer Growth Push',
        objective: 'New App Launch',
        targetAudience: 'Productivity seekers',
        targetCountry: 'US',
        language: 'en',
        startDate: '2026-06-01',
        endDate: '2026-06-30',
        status: 'active',
        postingFrequency: 'Daily',
        platforms: ['YouTube', 'TikTok', 'Instagram'],
        contentThemes: ['Quick Tips', 'Feature Showcase'],
        notes: 'Priority campaign for summer',
        createdAt: now,
        updatedAt: now,
      );

      // Insert campaign
      await db.insert('campaigns', campaign.toMap());

      // Insert platforms
      for (final p in campaign.platforms) {
        await db.insert('campaign_platforms', {
          'id': 'cp-$p',
          'campaign_id': campaign.id,
          'platform': p,
        });
      }

      // Query campaign
      final campQuery = await db.query('campaigns', where: 'id = ?', whereArgs: ['camp-1']);
      expect(campQuery.length, 1);
      expect(campQuery.first['name'], 'Summer Growth Push');

      // Query linked platforms
      final platformsQuery = await db.query('campaign_platforms', where: 'campaign_id = ?', whereArgs: ['camp-1']);
      expect(platformsQuery.length, 3);
      final platforms = platformsQuery.map((r) => r['platform'] as String).toSet();
      expect(platforms.contains('YouTube'), isTrue);
      expect(platforms.contains('TikTok'), isTrue);
      expect(platforms.contains('Instagram'), isTrue);
    });

    test('Status update and deletion test', () async {
      final now = DateTime.now().toUtc();
      final camp = CampaignModel(
        id: 'camp-2',
        appId: 'app-camp-1',
        name: 'Draft Sprint',
        objective: 'Feature Showcase',
        createdAt: now,
        updatedAt: now,
      );

      await db.insert('campaigns', camp.toMap());

      // Update status
      await db.update('campaigns', {'status': 'paused'}, where: 'id = ?', whereArgs: ['camp-2']);
      final res = await db.query('campaigns', where: 'id = ?', whereArgs: ['camp-2']);
      expect(res.first['status'], 'paused');

      // Delete
      await db.delete('campaigns', where: 'id = ?', whereArgs: ['camp-2']);
      final afterDelete = await db.query('campaigns', where: 'id = ?', whereArgs: ['camp-2']);
      expect(afterDelete.isEmpty, isTrue);
    });
  });
}
