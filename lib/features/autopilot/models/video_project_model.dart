import 'dart:convert';

class VideoSceneModel {
  final int sceneNumber;
  final String title;
  final String narrationText;
  final String visualDescription;
  final double durationSeconds;
  final String? imageAssetPath;
  final String? videoClipPath;
  final double? clipStartTimeSeconds;
  final double? clipEndTimeSeconds;
  final String badgeText;
  final String? captionText;
  final String transition; // fade, slide, dissolve, cut
  final String fitMode; // contain, cover, fit

  const VideoSceneModel({
    required this.sceneNumber,
    required this.title,
    required this.narrationText,
    required this.visualDescription,
    required this.durationSeconds,
    this.imageAssetPath,
    this.videoClipPath,
    this.clipStartTimeSeconds,
    this.clipEndTimeSeconds,
    this.badgeText = '',
    this.captionText,
    this.transition = 'fade',
    this.fitMode = 'contain',
  });

  VideoSceneModel copyWith({
    int? sceneNumber,
    String? title,
    String? narrationText,
    String? visualDescription,
    double? durationSeconds,
    String? imageAssetPath,
    String? videoClipPath,
    double? clipStartTimeSeconds,
    double? clipEndTimeSeconds,
    String? badgeText,
    String? captionText,
    String? transition,
    String? fitMode,
  }) {
    return VideoSceneModel(
      sceneNumber: sceneNumber ?? this.sceneNumber,
      title: title ?? this.title,
      narrationText: narrationText ?? this.narrationText,
      visualDescription: visualDescription ?? this.visualDescription,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      imageAssetPath: imageAssetPath ?? this.imageAssetPath,
      videoClipPath: videoClipPath ?? this.videoClipPath,
      clipStartTimeSeconds: clipStartTimeSeconds ?? this.clipStartTimeSeconds,
      clipEndTimeSeconds: clipEndTimeSeconds ?? this.clipEndTimeSeconds,
      badgeText: badgeText ?? this.badgeText,
      captionText: captionText ?? this.captionText,
      transition: transition ?? this.transition,
      fitMode: fitMode ?? this.fitMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scene_number': sceneNumber,
      'title': title,
      'narration_text': narrationText,
      'visual_description': visualDescription,
      'duration_seconds': durationSeconds,
      'image_asset_path': imageAssetPath,
      'video_clip_path': videoClipPath,
      'clip_start_time_seconds': clipStartTimeSeconds,
      'clip_end_time_seconds': clipEndTimeSeconds,
      'badge_text': badgeText,
      'caption_text': captionText,
      'transition': transition,
      'fit_mode': fitMode,
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
      videoClipPath: map['video_clip_path'] as String?,
      clipStartTimeSeconds: (map['clip_start_time_seconds'] as num?)?.toDouble(),
      clipEndTimeSeconds: (map['clip_end_time_seconds'] as num?)?.toDouble(),
      badgeText: map['badge_text'] as String? ?? '',
      captionText: map['caption_text'] as String?,
      transition: map['transition'] as String? ?? 'fade',
      fitMode: map['fit_mode'] as String? ?? 'contain',
    );
  }
}

class VideoProjectModel {
  final String id;
  final String? appId;
  final String templateType; // feature_showcase, problem_solution, quick_tutorial, launch_announcement, before_after, installation_guide, promotional_slideshow, existing_video_enhancement, text_to_video
  final String sourceType; // url, screenshots, video_clips, text, mixed
  final String title;
  final String aspectRatio; // 9:16, 16:9, 1:1
  final String resolution; // 1080p, 720p
  final double totalDurationSeconds;
  final List<VideoSceneModel> scenes;
  final String audioNarrationScript;
  final String? inputAppUrl;
  final String? inputTextPrompt;
  final List<String> inputMediaPaths;
  final String captionStyle; // modern, bold, minimal
  final String transitionStyle; // fade, slide, cut
  final String? backgroundMusicPath;
  final double backgroundMusicVolume;
  final bool enableVoiceNarration;
  final String exportStatus; // draft, rendering, rendered, exported, failed
  final String? exportedFilePath;
  final int? fileSizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VideoProjectModel({
    required this.id,
    this.appId,
    this.templateType = 'feature_showcase',
    this.sourceType = 'mixed',
    required this.title,
    this.aspectRatio = '9:16',
    this.resolution = '1080p',
    required this.totalDurationSeconds,
    required this.scenes,
    required this.audioNarrationScript,
    this.inputAppUrl,
    this.inputTextPrompt,
    this.inputMediaPaths = const [],
    this.captionStyle = 'modern',
    this.transitionStyle = 'fade',
    this.backgroundMusicPath,
    this.backgroundMusicVolume = 0.2,
    this.enableVoiceNarration = false,
    this.exportStatus = 'draft',
    this.exportedFilePath,
    this.fileSizeBytes,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  VideoProjectModel copyWith({
    String? id,
    String? appId,
    String? templateType,
    String? sourceType,
    String? title,
    String? aspectRatio,
    String? resolution,
    double? totalDurationSeconds,
    List<VideoSceneModel>? scenes,
    String? audioNarrationScript,
    String? inputAppUrl,
    String? inputTextPrompt,
    List<String>? inputMediaPaths,
    String? captionStyle,
    String? transitionStyle,
    String? backgroundMusicPath,
    double? backgroundMusicVolume,
    bool? enableVoiceNarration,
    String? exportStatus,
    String? exportedFilePath,
    int? fileSizeBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoProjectModel(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      templateType: templateType ?? this.templateType,
      sourceType: sourceType ?? this.sourceType,
      title: title ?? this.title,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      resolution: resolution ?? this.resolution,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      scenes: scenes ?? this.scenes,
      audioNarrationScript: audioNarrationScript ?? this.audioNarrationScript,
      inputAppUrl: inputAppUrl ?? this.inputAppUrl,
      inputTextPrompt: inputTextPrompt ?? this.inputTextPrompt,
      inputMediaPaths: inputMediaPaths ?? this.inputMediaPaths,
      captionStyle: captionStyle ?? this.captionStyle,
      transitionStyle: transitionStyle ?? this.transitionStyle,
      backgroundMusicPath: backgroundMusicPath ?? this.backgroundMusicPath,
      backgroundMusicVolume: backgroundMusicVolume ?? this.backgroundMusicVolume,
      enableVoiceNarration: enableVoiceNarration ?? this.enableVoiceNarration,
      exportStatus: exportStatus ?? this.exportStatus,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'app_id': appId,
      'template_type': templateType,
      'source_type': sourceType,
      'title': title,
      'aspect_ratio': aspectRatio,
      'resolution': resolution,
      'total_duration_seconds': totalDurationSeconds,
      'scenes': jsonEncode(scenes.map((s) => s.toMap()).toList()),
      'audio_narration_script': audioNarrationScript,
      'input_app_url': inputAppUrl,
      'input_text_prompt': inputTextPrompt,
      'input_media_paths': jsonEncode(inputMediaPaths),
      'caption_style': captionStyle,
      'transition_style': transitionStyle,
      'background_music_path': backgroundMusicPath,
      'background_music_volume': backgroundMusicVolume,
      'enable_voice_narration': enableVoiceNarration ? 1 : 0,
      'export_status': exportStatus,
      'exported_file_path': exportedFilePath,
      'file_size_bytes': fileSizeBytes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
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

    List<String> parseMediaPaths(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        try {
          final list = jsonDecode(raw) as List;
          return list.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    return VideoProjectModel(
      id: map['id'] as String,
      appId: map['app_id'] as String?,
      templateType: map['template_type'] as String? ?? 'feature_showcase',
      sourceType: map['source_type'] as String? ?? 'mixed',
      title: map['title'] as String? ?? '',
      aspectRatio: map['aspect_ratio'] as String? ?? '9:16',
      resolution: map['resolution'] as String? ?? '1080p',
      totalDurationSeconds: (map['total_duration_seconds'] as num?)?.toDouble() ?? 15.0,
      scenes: parseScenes(map['scenes']),
      audioNarrationScript: map['audio_narration_script'] as String? ?? '',
      inputAppUrl: map['input_app_url'] as String?,
      inputTextPrompt: map['input_text_prompt'] as String?,
      inputMediaPaths: parseMediaPaths(map['input_media_paths']),
      captionStyle: map['caption_style'] as String? ?? 'modern',
      transitionStyle: map['transition_style'] as String? ?? 'fade',
      backgroundMusicPath: map['background_music_path'] as String?,
      backgroundMusicVolume: (map['background_music_volume'] as num?)?.toDouble() ?? 0.2,
      enableVoiceNarration: (map['enable_voice_narration'] as int? ?? 0) == 1,
      exportStatus: map['export_status'] as String? ?? 'draft',
      exportedFilePath: map['exported_file_path'] as String?,
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }
}
