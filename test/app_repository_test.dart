import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/features/apps/models/app_model.dart';

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('SQLite Database and App Repository Integration Tests', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onCreate: DatabaseMigrations.onCreate,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('All 16 tables are created in SQLite schema', () async {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames.contains('apps'), isTrue);
      expect(tableNames.contains('app_media'), isTrue);
      expect(tableNames.contains('social_accounts'), isTrue);
      expect(tableNames.contains('campaigns'), isTrue);
      expect(tableNames.contains('campaign_platforms'), isTrue);
      expect(tableNames.contains('keywords'), isTrue);
      expect(tableNames.contains('research_sources'), isTrue);
      expect(tableNames.contains('content_posts'), isTrue);
      expect(tableNames.contains('post_media'), isTrue);
      expect(tableNames.contains('post_jobs'), isTrue);
      expect(tableNames.contains('post_attempts'), isTrue);
      expect(tableNames.contains('published_posts'), isTrue);
      expect(tableNames.contains('metric_snapshots'), isTrue);
      expect(tableNames.contains('automation_rules'), isTrue);
      expect(tableNames.contains('activity_logs'), isTrue);
      expect(tableNames.contains('application_settings'), isTrue);
    });

    test('AppModel insert, query, and duplicate package prevention', () async {
      final now = DateTime.now().toUtc();
      final app = AppModel(
        id: 'app-1',
        name: 'Habit Flow',
        packageName: 'com.studio.habitflow',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.studio.habitflow',
        category: 'Productivity',
        shortDescription: 'Build lasting daily habits',
        fullDescription: 'Comprehensive habit tracking app with streak graphs and reminders.',
        mainFeatures: ['Streak Counter', 'Offline Sync'],
        uniqueSellingPoints: ['Zero ads and privacy first'],
        targetAudience: 'Self-improvement enthusiasts',
        targetCountries: ['US', 'CA', 'GB'],
        supportedLanguages: ['en'],
        brandTone: 'Informative & Helpful',
        preferredCta: 'Install now on Google Play',
        websiteUrl: 'https://example.com',
        privacyPolicyUrl: 'https://example.com/privacy',
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      // Insert app
      await db.insert('apps', app.toMap());

      // Query app
      final results = await db.query('apps', where: 'id = ?', whereArgs: ['app-1']);
      expect(results.length, 1);
      final retrieved = AppModel.fromMap(results.first);
      expect(retrieved.name, 'Habit Flow');
      expect(retrieved.packageName, 'com.studio.habitflow');
      expect(retrieved.mainFeatures.length, 2);
      expect(retrieved.uniqueSellingPoints.first, 'Zero ads and privacy first');

      // Attempt duplicate package name insert (should fail on UNIQUE constraint)
      final duplicateApp = app.copyWith(id: 'app-2');
      expect(
        () async => await db.insert('apps', duplicateApp.toMap()),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('App search and filter queries execute accurately', () async {
      final now = DateTime.now().toUtc();
      final app1 = AppModel(
        id: 'app-1',
        name: 'Productivity Matrix',
        packageName: 'com.studio.prodmatrix',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.studio.prodmatrix',
        category: 'Productivity',
        createdAt: now,
        updatedAt: now,
      );
      final app2 = AppModel(
        id: 'app-2',
        name: 'Budget Master',
        packageName: 'com.studio.budgetmaster',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.studio.budgetmaster',
        category: 'Finance',
        isArchived: true,
        createdAt: now,
        updatedAt: now,
      );

      await db.insert('apps', app1.toMap());
      await db.insert('apps', app2.toMap());

      // Query active only
      final active = await db.query('apps', where: 'is_archived = 0');
      expect(active.length, 1);
      expect(active.first['name'], 'Productivity Matrix');

      // Search by term
      final searched = await db.query(
        'apps',
        where: 'name LIKE ? OR package_name LIKE ?',
        whereArgs: ['%Budget%', '%Budget%'],
      );
      expect(searched.length, 1);
      expect(searched.first['name'], 'Budget Master');
    });

    test('App update and archiving update records correctly', () async {
      final now = DateTime.now().toUtc();
      final app = AppModel(
        id: 'app-edit',
        name: 'Initial Name',
        packageName: 'com.studio.test',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.studio.test',
        category: 'Tools & Utilities',
        createdAt: now,
        updatedAt: now,
      );

      await db.insert('apps', app.toMap());

      // Update name and archive
      final updated = app.copyWith(
        name: 'Updated Name',
        isArchived: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await db.update('apps', updated.toMap(), where: 'id = ?', whereArgs: [app.id]);

      final query = await db.query('apps', where: 'id = ?', whereArgs: [app.id]);
      final fetched = AppModel.fromMap(query.first);
      expect(fetched.name, 'Updated Name');
      expect(fetched.isArchived, isTrue);
    });

    test('Deletion removes record cleanly', () async {
      final now = DateTime.now().toUtc();
      final app = AppModel(
        id: 'app-del',
        name: 'Delete Me',
        packageName: 'com.studio.delete',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.studio.delete',
        category: 'Games',
        createdAt: now,
        updatedAt: now,
      );

      await db.insert('apps', app.toMap());
      expect((await db.query('apps')).length, 1);

      await db.delete('apps', where: 'id = ?', whereArgs: [app.id]);
      expect((await db.query('apps')).length, 0);
    });
  });
}
