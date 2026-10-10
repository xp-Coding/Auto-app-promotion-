import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../autopilot/models/video_project_model.dart';

class VideoProjectRepository {
  final AppDatabase _db;

  VideoProjectRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<void> saveProject(VideoProjectModel project) async {
    final database = await _db.database;
    await database.insert(
      'video_projects',
      project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await AppLogger.info(
      'video_studio',
      'Video project "${project.title}" saved successfully (ID: ${project.id}).',
    );
  }

  Future<VideoProjectModel?> getProjectById(String id) async {
    final database = await _db.database;
    final results = await database.query(
      'video_projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return VideoProjectModel.fromMap(results.first);
  }

  Future<List<VideoProjectModel>> getAllProjects({String? appId}) async {
    final database = await _db.database;
    final List<Map<String, dynamic>> results;
    if (appId != null && appId.isNotEmpty) {
      results = await database.query(
        'video_projects',
        where: 'app_id = ?',
        whereArgs: [appId],
        orderBy: 'updated_at DESC',
      );
    } else {
      results = await database.query(
        'video_projects',
        orderBy: 'updated_at DESC',
      );
    }
    return results.map((m) => VideoProjectModel.fromMap(m)).toList();
  }

  Future<void> deleteProject(String id) async {
    final database = await _db.database;
    await database.delete(
      'video_projects',
      where: 'id = ?',
      whereArgs: [id],
    );
    await AppLogger.info('video_studio', 'Deleted video project (ID: $id).');
  }

  Future<void> updateExportStatus({
    required String id,
    required String status,
    String? renderingPhaseStatus,
    String? exportedPath,
    int? fileSizeBytes,
  }) async {
    final database = await _db.database;
    final updateData = <String, dynamic>{
      'export_status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (renderingPhaseStatus != null) updateData['rendering_phase_status'] = renderingPhaseStatus;
    if (exportedPath != null) updateData['exported_file_path'] = exportedPath;
    if (fileSizeBytes != null) updateData['file_size_bytes'] = fileSizeBytes;

    await database.update(
      'video_projects',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
