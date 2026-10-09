import 'dart:io';

class MediaItemModel {
  final String id;
  final String appId;
  final String filePath;
  final String mediaType; // icon, screenshot, banner, video, thumbnail
  final String? title;
  final String? tags;
  final DateTime createdAt;

  const MediaItemModel({
    required this.id,
    required this.appId,
    required this.filePath,
    required this.mediaType,
    this.title,
    this.tags,
    required this.createdAt,
  });

  bool get fileExists => File(filePath).existsSync();

  int? get fileSizeBytes {
    try {
      final f = File(filePath);
      if (f.existsSync()) return f.lengthSync();
    } catch (_) {}
    return null;
  }

  String get formattedSize {
    final bytes = fileSizeBytes;
    if (bytes == null) return 'Missing';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'app_id': appId,
      'file_path': filePath,
      'media_type': mediaType,
      'title': title,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MediaItemModel.fromMap(Map<String, dynamic> map) {
    return MediaItemModel(
      id: map['id'] as String,
      appId: map['app_id'] as String,
      filePath: map['file_path'] as String,
      mediaType: map['media_type'] as String,
      title: map['title'] as String?,
      tags: map['tags'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
