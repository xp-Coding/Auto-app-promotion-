import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/app_database.dart';
import '../models/media_item_model.dart';

class MediaRepository {
  final AppDatabase _dbProvider;
  final Database? _rawDb;

  MediaRepository({AppDatabase? dbProvider, Database? db})
      : _dbProvider = dbProvider ?? AppDatabase.instance,
        _rawDb = db;

  Future<Database> get _db async => _rawDb ?? await _dbProvider.database;

  Future<List<MediaItemModel>> getAllMedia({
    String? appId,
    String? mediaType,
    String? searchQuery,
  }) async {
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (appId != null && appId.trim().isNotEmpty) {
      whereClauses.add('app_id = ?');
      whereArgs.add(appId.trim());
    }

    if (mediaType != null && mediaType.trim().isNotEmpty && mediaType != 'All') {
      whereClauses.add('media_type = ?');
      whereArgs.add(mediaType.trim().toLowerCase());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(title LIKE ? OR file_path LIKE ? OR tags LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      whereArgs.addAll([term, term, term]);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'app_media',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );

    return results.map((m) => MediaItemModel.fromMap(m)).toList();
  }

  Future<MediaItemModel> addMedia(MediaItemModel item) async {
    final db = await _db;
    await db.insert('app_media', item.toMap());
    return item;
  }

  Future<List<MediaItemModel>> getMediaForApp(String appId) => getAllMedia(appId: appId);

  Future<void> deleteMedia(String id) async {
    final db = await _db;
    await db.delete('app_media', where: 'id = ?', whereArgs: [id]);
  }
}
