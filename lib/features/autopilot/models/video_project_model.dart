import 'dart:convert';

class VideoSceneModel {
  final int sceneNumber;
  final String title;
  final String narrationText;
  final String visualDescription;
  final double durationSeconds;
  final String? imageAssetPath;
  final String badgeText;

  const VideoSceneModel({
    required this.sceneNumber,
    required this.title,
    required this.narrationText,
    required this.visualDescription,
    required this.durationSeconds,
    this.imageAssetPath,
    this.badgeText = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'scene_number': sceneNumber,
      'title': title,
      'narration_text': narrationText,
      'visual_description': visualDescription,
      'duration_seconds': durationSeconds,
      'image_asset_path': imageAssetPath,
      'badge_text': badgeText,
    };
  }

  factory VideoSceneModel.fromMap(Map<String, dynamic> map) {
    return VideoSceneModel(
      sceneNumber: (map['scene_number'] as num?)?.toInt() ?? 1,
      title: map['title'] as String? ?? '',
      narrationText: map['narration_text'] as String? ?? '',
      visualDescription: map['visual_description'] as String? ?? '',
      durationSeconds: (map['duration_seconds'] as num?)?.toDouble() ?? 3.0,
      imageAssetPath: map['image_asset_path'] as String?,
      badgeText: map['badge_text'] as String? ?? '',
    );
  }
}

class VideoProjectModel {
  final String id;
  final String appId;
  final String templateType; // feature_showcase, problem_solution, quick_tutorial, launch_announcement, before_after, installation_guide, highlight_reel
  final String title;
  final String aspectRatio; // 9:16, 16:9
  final double totalDurationSeconds;
  final List<VideoSceneModel> scenes;
  final String audioNarrationScript;
  final String exportStatus; // draft, rendered, exported
  final String? exportedFilePath;
  final DateTime createdAt;

  const VideoProjectModel({
    required this.id,
    required this.appId,
    required this.templateType,
    required this.title,
    this.aspectRatio = '9:16',
    required this.totalDurationSeconds,
    required this.scenes,
    required this.audioNarrationScript,
    this.exportStatus = 'draft',
    this.exportedFilePath,
    required this.createdAt,
  });

  VideoProjectModel copyWith({
    String? id,
    String? appId,
    String? templateType,
    String? title,
    String? aspectRatio,
    double? totalDurationSeconds,
    List<VideoSceneModel>? scenes,
    String? audioNarrationScript,
    String? exportStatus,
    String? exportedFilePath,
    DateTime? createdAt,
  }) {
    return VideoProjectModel(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      templateType: templateType ?? this.templateType,
      title: title ?? this.title,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      scenes: scenes ?? this.scenes,
      audioNarrationScript: audioNarrationScript ?? this.audioNarrationScript,
      exportStatus: exportStatus ?? this.exportStatus,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'app_id': appId,
      'template_type': templateType,
      'title': title,
      'aspect_ratio': aspectRatio,
      'total_duration_seconds': totalDurationSeconds,
      'scenes': jsonEncode(scenes.map((s) => s.toMap()).toList()),
      'audio_narration_script': audioNarrationScript,
      'export_status': exportStatus,
      'exported_file_path': exportedFilePath,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory VideoProjectModel.fromMap(Map<String, dynamic> map) {
    List<VideoSceneModel> parseScenes(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        try {
          final list = jsonDecode(raw) as List;
          return list.map((e) => VideoSceneModel.fromMap(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }
      return [];
    }

    return VideoProjectModel(
      id: map['id'] as String,
      appId: map['app_id'] as String,
      templateType: map['template_type'] as String? ?? 'feature_showcase',
      title: map['title'] as String? ?? '',
      aspectRatio: map['aspect_ratio'] as String? ?? '9:16',
      totalDurationSeconds: (map['total_duration_seconds'] as num?)?.toDouble() ?? 15.0,
      scenes: parseScenes(map['scenes']),
      audioNarrationScript: map['audio_narration_script'] as String? ?? '',
      exportStatus: map['export_status'] as String? ?? 'draft',
      exportedFilePath: map['exported_file_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
