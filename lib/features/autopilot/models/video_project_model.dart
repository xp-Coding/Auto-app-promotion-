import 'dart:convert';
import 'package:uuid/uuid.dart';

class VideoSceneModel {
  final String id;
  final int sceneNumber;
  final String sceneTitle;
  final String onScreenText;
  final String voiceOverNarration;
  final String subtitleText;
  final String visualDescription;
  final String? callToAction;
  final double durationSeconds;
  final String? imageAssetPath;
  final String? videoClipPath;
  final double? clipStartTimeSeconds;
  final double? clipEndTimeSeconds;
  final String badgeText;
  final String transition; // fade, slide, dissolve, cut
  final String fitMode; // contain, cover, fit
  final String visualSourceType; // user_screenshot, user_clip, store_listing, built_in_library, procedural_graphics, stock_media, plain_color
  final List<String> visualAssetPaths;

  const VideoSceneModel({
    this.id = '',
    required this.sceneNumber,
    String? sceneTitle,
    String? title,
    String? onScreenText,
    String? voiceOverNarration,
    String? narrationText,
    String? subtitleText,
    String? captionText,
    required this.visualDescription,
    this.callToAction,
    required this.durationSeconds,
    this.imageAssetPath,
    this.videoClipPath,
    this.clipStartTimeSeconds,
    this.clipEndTimeSeconds,
    this.badgeText = '',
    this.transition = 'fade',
    this.fitMode = 'contain',
    this.visualSourceType = 'user_screenshot',
    this.visualAssetPaths = const [],
  })  : sceneTitle = sceneTitle ?? title ?? '',
        onScreenText = onScreenText ?? captionText ?? title ?? '',
        voiceOverNarration = voiceOverNarration ?? narrationText ?? '',
        subtitleText = subtitleText ?? captionText ?? narrationText ?? '';

  // Backward compatibility getters
  String get title => sceneTitle;
  String get narrationText => voiceOverNarration;
  String? get captionText => subtitleText.isNotEmpty ? subtitleText : onScreenText;

  VideoSceneModel copyWith({
    String? id,
    int? sceneNumber,
    String? sceneTitle,
    String? title,
    String? onScreenText,
    String? voiceOverNarration,
    String? narrationText,
    String? subtitleText,
    String? captionText,
    String? visualDescription,
    String? callToAction,
    double? durationSeconds,
    String? imageAssetPath,
    String? videoClipPath,
    double? clipStartTimeSeconds,
    double? clipEndTimeSeconds,
    String? badgeText,
    String? transition,
    String? fitMode,
    String? visualSourceType,
    List<String>? visualAssetPaths,
  }) {
    return VideoSceneModel(
      id: id ?? this.id,
      sceneNumber: sceneNumber ?? this.sceneNumber,
      sceneTitle: sceneTitle ?? title ?? this.sceneTitle,
      onScreenText: onScreenText ?? captionText ?? this.onScreenText,
      voiceOverNarration: voiceOverNarration ?? narrationText ?? this.voiceOverNarration,
      subtitleText: subtitleText ?? captionText ?? this.subtitleText,
      visualDescription: visualDescription ?? this.visualDescription,
      callToAction: callToAction ?? this.callToAction,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      imageAssetPath: imageAssetPath ?? this.imageAssetPath,
      videoClipPath: videoClipPath ?? this.videoClipPath,
      clipStartTimeSeconds: clipStartTimeSeconds ?? this.clipStartTimeSeconds,
      clipEndTimeSeconds: clipEndTimeSeconds ?? this.clipEndTimeSeconds,
      badgeText: badgeText ?? this.badgeText,
      transition: transition ?? this.transition,
      fitMode: fitMode ?? this.fitMode,
      visualSourceType: visualSourceType ?? this.visualSourceType,
      visualAssetPaths: visualAssetPaths ?? this.visualAssetPaths,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scene_number': sceneNumber,
      'scene_title': sceneTitle,
      'title': sceneTitle, // backward compatibility
      'on_screen_text': onScreenText,
      'voice_over_narration': voiceOverNarration,
      'narration_text': voiceOverNarration, // backward compatibility
      'subtitle_text': subtitleText,
      'caption_text': subtitleText, // backward compatibility
      'visual_description': visualDescription,
      'call_to_action': callToAction,
      'duration_seconds': durationSeconds,
      'image_asset_path': imageAssetPath,
      'video_clip_path': videoClipPath,
      'clip_start_time_seconds': clipStartTimeSeconds,
      'clip_end_time_seconds': clipEndTimeSeconds,
      'badge_text': badgeText,
      'transition': transition,
      'fit_mode': fitMode,
      'visual_source_type': visualSourceType,
      'visual_asset_paths': visualAssetPaths,
    };
  }

  factory VideoSceneModel.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as List;
          return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    final sceneNumber = (map['scene_number'] as num?)?.toInt() ?? 1;
    final id = map['id'] as String? ?? 'scene_${sceneNumber}_${const Uuid().v4().substring(0, 8)}';
    final sceneTitle = map['scene_title'] as String? ?? map['title'] as String? ?? '';
    final onScreenText = map['on_screen_text'] as String? ?? map['caption_text'] as String? ?? sceneTitle;
    final voiceOverNarration = map['voice_over_narration'] as String? ?? map['narration_text'] as String? ?? '';
    final subtitleText = map['subtitle_text'] as String? ?? map['caption_text'] as String? ?? voiceOverNarration;

    return VideoSceneModel(
      id: id,
      sceneNumber: sceneNumber,
      sceneTitle: sceneTitle,
      onScreenText: onScreenText,
      voiceOverNarration: voiceOverNarration,
      subtitleText: subtitleText,
      visualDescription: map['visual_description'] as String? ?? '',
      callToAction: map['call_to_action'] as String?,
      durationSeconds: (map['duration_seconds'] as num?)?.toDouble() ?? 3.0,
      imageAssetPath: map['image_asset_path'] as String?,
      videoClipPath: map['video_clip_path'] as String?,
      clipStartTimeSeconds: (map['clip_start_time_seconds'] as num?)?.toDouble(),
      clipEndTimeSeconds: (map['clip_end_time_seconds'] as num?)?.toDouble(),
      badgeText: map['badge_text'] as String? ?? '',
      transition: map['transition'] as String? ?? 'fade',
      fitMode: map['fit_mode'] as String? ?? 'contain',
      visualSourceType: map['visual_source_type'] as String? ?? 'user_screenshot',
      visualAssetPaths: parseList(map['visual_asset_paths']),
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
  final String originalInputText;
  final String generatedMarketingScript;
  final String renderingPhaseStatus; // storyboardReady, visualAssetsReady, framesGenerated, encodingInProgress, videoEncodedSuccessfully, exported, failed
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
    this.originalInputText = '',
    this.generatedMarketingScript = '',
    this.renderingPhaseStatus = 'storyboardReady',
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
    String? originalInputText,
    String? generatedMarketingScript,
    String? renderingPhaseStatus,
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
      originalInputText: originalInputText ?? this.originalInputText,
      generatedMarketingScript: generatedMarketingScript ?? this.generatedMarketingScript,
      renderingPhaseStatus: renderingPhaseStatus ?? this.renderingPhaseStatus,
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
      'original_input_text': originalInputText,
      'generated_marketing_script': generatedMarketingScript,
      'rendering_phase_status': renderingPhaseStatus,
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

    final exportStatus = map['export_status'] as String? ?? 'draft';
    final phaseStatus = map['rendering_phase_status'] as String? ??
        (exportStatus == 'rendered'
            ? 'videoEncodedSuccessfully'
            : (exportStatus == 'exported' ? 'exported' : 'storyboardReady'));

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
      originalInputText: map['original_input_text'] as String? ?? map['input_text_prompt'] as String? ?? '',
      generatedMarketingScript: map['generated_marketing_script'] as String? ?? map['audio_narration_script'] as String? ?? '',
      renderingPhaseStatus: phaseStatus,
      inputAppUrl: map['input_app_url'] as String?,
      inputTextPrompt: map['input_text_prompt'] as String?,
      inputMediaPaths: parseMediaPaths(map['input_media_paths']),
      captionStyle: map['caption_style'] as String? ?? 'modern',
      transitionStyle: map['transition_style'] as String? ?? 'fade',
      backgroundMusicPath: map['background_music_path'] as String?,
      backgroundMusicVolume: (map['background_music_volume'] as num?)?.toDouble() ?? 0.2,
      enableVoiceNarration: (map['enable_voice_narration'] as int? ?? 0) == 1,
      exportStatus: exportStatus,
      exportedFilePath: map['exported_file_path'] as String?,
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
    );
  }
}
