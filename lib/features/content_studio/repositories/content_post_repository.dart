import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/app_database.dart';
import '../models/content_post_model.dart';

class ContentPostRepository {
  final AppDatabase _dbProvider;
  final Database? _rawDb;

  ContentPostRepository({AppDatabase? dbProvider, Database? db})
      : _dbProvider = dbProvider ?? AppDatabase.instance,
        _rawDb = db;

  Future<Database> get _db async => _rawDb ?? await _dbProvider.database;

  Future<List<ContentPostModel>> getAllPosts({
    String? appId,
    String? campaignId,
    String? platform,
    String? status,
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (appId != null && appId.trim().isNotEmpty) {
      whereClauses.add('app_id = ?');
      whereArgs.add(appId.trim());
    }

    if (campaignId != null && campaignId.trim().isNotEmpty) {
      whereClauses.add('campaign_id = ?');
      whereArgs.add(campaignId.trim());
    }

    if (platform != null && platform.trim().isNotEmpty && platform != 'All') {
      whereClauses.add('target_platform = ?');
      whereArgs.add(platform.trim());
    }

    if (status != null && status.trim().isNotEmpty && status != 'All') {
      whereClauses.add('status = ?');
      whereArgs.add(status.trim().toLowerCase());
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'content_posts',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'updated_at DESC',
    );

    return results.map((m) => ContentPostModel.fromMap(m)).toList();
  }

  Future<ContentPostModel?> getPostById(String id) async {
    final db = await _db;
    final results = await db.query('content_posts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return ContentPostModel.fromMap(results.first);
  }

  Future<ContentPostModel> createPost(ContentPostModel post) async {
    final db = await _db;
    await db.insert('content_posts', post.toMap());
    return post;
  }

  Future<ContentPostModel> updatePost(ContentPostModel post) async {
    final db = await _db;
    final updated = post.copyWith(updatedAt: DateTime.now().toUtc());
    await db.update(
      'content_posts',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [post.id],
    );
    return updated;
  }

  Future<List<String>> getPostMediaPaths(String postId) async {
    final db = await _db;
    final results = await db.query(
      'post_media',
      where: 'post_id = ?',
      whereArgs: [postId],
      orderBy: 'sort_order ASC',
    );
    return results.map((m) => m['media_path'] as String).toList();
  }

  Future<void> deletePost(String id) async {
    final db = await _db;
    await db.delete('content_posts', where: 'id = ?', whereArgs: [id]);
  }
}
