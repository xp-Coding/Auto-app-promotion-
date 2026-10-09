import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/csv_helper.dart';
import '../models/keyword_model.dart';

class KeywordRepository {
  final AppDatabase _dbProvider;

  KeywordRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<Database> get _db => _dbProvider.database;

  Future<List<KeywordModel>> getAllKeywords({
    String? appId,
    String? topicCluster,
    String? intent,
    String? searchQuery,
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (appId != null && appId.trim().isNotEmpty) {
      whereClauses.add('app_id = ?');
      whereArgs.add(appId.trim());
    }

    if (topicCluster != null && topicCluster.trim().isNotEmpty && topicCluster != 'All') {
      whereClauses.add('topic_cluster = ?');
      whereArgs.add(topicCluster.trim());
    }

    if (intent != null && intent.trim().isNotEmpty && intent != 'All') {
      whereClauses.add('intent = ?');
      whereArgs.add(intent.trim().toLowerCase());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(keyword LIKE ? OR topic_cluster LIKE ? OR notes LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      whereArgs.addAll([term, term, term]);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'keywords',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'relevance_score DESC, created_at DESC',
    );

    return results.map((m) => KeywordModel.fromMap(m)).toList();
  }

  Future<KeywordModel> addKeyword(KeywordModel keyword) async {
    final db = await _db;
    await db.insert('keywords', keyword.toMap());
    return keyword;
  }

  Future<KeywordModel> updateKeyword(KeywordModel keyword) async {
    final db = await _db;
    await db.update(
      'keywords',
      keyword.toMap(),
      where: 'id = ?',
      whereArgs: [keyword.id],
    );
    return keyword;
  }

  Future<void> deleteKeyword(String id) async {
    final db = await _db;
    await db.delete('keywords', where: 'id = ?', whereArgs: [id]);
  }

  /// Exports stored keywords for an app into standard RFC 4180 CSV format.
  Future<String> exportKeywordsToCsv(String appId) async {
    final keywords = await getAllKeywords(appId: appId);
    final rows = <List<dynamic>>[];

    // CSV Headers
    rows.add([
      'Keyword',
      'Topic Cluster',
      'Intent',
      'Qualitative Relevance Score',
      'Source',
      'Retrieval Date',
      'Notes',
    ]);

    for (final kw in keywords) {
      rows.add([
        kw.keyword,
        kw.topicCluster ?? '',
        kw.intent,
        kw.relevanceScore.toStringAsFixed(1),
        kw.source,
        kw.retrievalDate,
        kw.notes ?? '',
      ]);
    }

    return CsvHelper.encode(rows);
  }

  /// Imports keywords from a CSV string into the local SQLite database.
  Future<int> importKeywordsFromCsv(String appId, String csvContent) async {
    final rows = CsvHelper.decode(csvContent);
    if (rows.length <= 1) return 0; // Header only or empty

    final db = await _db;
    final now = DateTime.now().toUtc();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    int importedCount = 0;

    await db.transaction((txn) async {
      // First row is assumed to be header: Keyword, Topic Cluster, Intent, Score, Source, Date, Notes
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row[0].trim().isEmpty) continue;

        final keywordText = row[0].trim();
        final cluster = row.length > 1 && row[1].trim().isNotEmpty ? row[1].trim() : null;
        final intent = row.length > 2 && row[2].trim().isNotEmpty ? row[2].trim().toLowerCase() : 'informational';
        final score = row.length > 3 ? (double.tryParse(row[3]) ?? 50.0) : 50.0;
        final notes = row.length > 6 && row[6].trim().isNotEmpty ? row[6].trim() : null;

        final kw = KeywordModel(
          id: const Uuid().v4(),
          appId: appId,
          keyword: keywordText,
          topicCluster: cluster,
          intent: intent,
          relevanceScore: score,
          source: 'imported_csv',
          retrievalDate: todayStr,
          notes: notes,
          createdAt: now,
        );

        await txn.insert('keywords', kw.toMap());
        importedCount++;
      }
    });

    return importedCount;
  }
}
