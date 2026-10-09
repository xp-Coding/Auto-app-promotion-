import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:appgrowth_studio/core/database/migrations.dart';
import 'package:appgrowth_studio/core/utils/csv_helper.dart';
import 'package:appgrowth_studio/features/apps/models/app_model.dart';
import 'package:appgrowth_studio/features/keywords/domain/keyword_relevance_scorer.dart';
import 'package:appgrowth_studio/features/keywords/models/keyword_model.dart';

void main() {
  setUpAll(() {
    final localDll = 'sqlite3.dll';
    if (File(localDll).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(localDll));
    }
    sqfliteFfiInit();
  });

  group('Keyword Explorer & Scorer Tests', () {
    late AppModel testApp;
    late Database db;

    setUp(() async {
      final now = DateTime.now().toUtc();
      testApp = AppModel(
        id: 'app-kw-1',
        name: 'Budget Master',
        packageName: 'com.studio.budgetmaster',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.studio.budgetmaster',
        category: 'Finance',
        mainFeatures: ['Expense Tracker', 'Budget Graphs', 'Bank Sync'],
        uniqueSellingPoints: ['100% Offline and Private'],
        createdAt: now,
        updatedAt: now,
      );

      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onCreate: DatabaseMigrations.onCreate,
        ),
      );

      await db.insert('apps', testApp.toMap());
    });

    tearDown(() async {
      await db.close();
    });

    test('KeywordRelevanceScorer computes qualitative score with transparency', () {
      final highMatch = KeywordRelevanceScorer.calculateScore(
        keyword: 'best Budget Master expense tracker app',
        app: testApp,
        intent: 'commercial',
        source: 'manual',
      );

      expect(highMatch.score >= 70, isTrue);
      expect(highMatch.contributingFactors.isNotEmpty, isTrue);

      final suggestions = KeywordRelevanceScorer.generateSuggestedKeywords(testApp);
      expect(suggestions.isNotEmpty, isTrue);
      expect(suggestions.any((s) => s.contains('finance')), isTrue);
    });

    test('Keyword SQLite insertion, CSV export, and CSV import roundtrip', () async {
      final kw1 = KeywordModel(
        id: 'kw-1',
        appId: testApp.id,
        keyword: 'free budget app android',
        topicCluster: 'Discovery',
        intent: 'commercial',
        relevanceScore: 85.0,
        source: 'manual',
        retrievalDate: '2026-10-09',
        notes: 'Target launch term',
        createdAt: DateTime.now().toUtc(),
      );

      await db.insert('keywords', kw1.toMap());

      final results = await db.query('keywords', where: 'app_id = ?', whereArgs: [testApp.id]);
      expect(results.length, 1);
      expect(results.first['keyword'], 'free budget app android');

      // Export to CSV
      final csv = CsvHelper.encode([
        ['Keyword', 'Topic Cluster', 'Intent', 'Score', 'Source', 'Date', 'Notes'],
        [kw1.keyword, kw1.topicCluster, kw1.intent, kw1.relevanceScore, kw1.source, kw1.retrievalDate, kw1.notes],
        ['expense tracker offline', 'Features', 'informational', 90.0, 'imported_csv', '2026-10-09', 'High value'],
      ]);

      expect(csv.contains('free budget app android'), isTrue);
      expect(csv.contains('expense tracker offline'), isTrue);

      // Import CSV rows
      final parsedRows = CsvHelper.decode(csv);
      expect(parsedRows.length, 3);
    });
  });
}
