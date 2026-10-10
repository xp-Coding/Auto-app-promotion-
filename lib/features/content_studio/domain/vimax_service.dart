import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Status model for the ViMax Python AI Video Engine.
class ViMaxStatus {
  final bool isAvailable;
  final String framework;
  final String status;
  final bool offlineModeAvailable;
  final bool ffmpegAvailable;
  final String speechSynthesis;
  final Map<String, dynamic> llm;
  final Map<String, dynamic> imageGeneration;
  final Map<String, dynamic> videoGeneration;
  final String dailyTarget;
  final int jobsCount;
  final String? errorMessage;

  const ViMaxStatus({
    required this.isAvailable,
    this.framework = 'ViMax Agentic Video Framework 1.2.0',
    this.status = 'unknown',
    this.offlineModeAvailable = true,
    this.ffmpegAvailable = true,
    this.speechSynthesis = 'Native Windows SAPI & Edge-TTS',
    this.llm = const {},
    this.imageGeneration = const {},
    this.videoGeneration = const {},
    this.dailyTarget = '5 videos/day (Quota-Safe Hybrid)',
    this.jobsCount = 0,
    this.errorMessage,
  });

  factory ViMaxStatus.unavailable(String error) {
    return ViMaxStatus(
      isAvailable: false,
      status: 'offline',
      errorMessage: error,
    );
  }

  factory ViMaxStatus.fromJson(Map<String, dynamic> json) {
    return ViMaxStatus(
      isAvailable: true,
      framework: json['framework'] as String? ?? 'ViMax Agentic Video Framework 1.2.0',
      status: json['status'] as String? ?? 'ready',
      offlineModeAvailable: json['offline_mode_available'] as bool? ?? true,
      ffmpegAvailable: json['ffmpeg_available'] as bool? ?? true,
      speechSynthesis: json['speech_synthesis'] as String? ?? 'Native SAPI & Edge-TTS',
      llm: json['llm'] as Map<String, dynamic>? ?? {},
      imageGeneration: json['image_generation'] as Map<String, dynamic>? ?? {},
      videoGeneration: json['video_generation'] as Map<String, dynamic>? ?? {},
      dailyTarget: json['daily_target'] as String? ?? '5 videos/day',
      jobsCount: json['jobs_count'] as int? ?? 0,
    );
  }
}

/// Website extraction metadata.
class WebsiteExtractedMetadata {
  final String url;
  final String domain;
  final String brandName;
  final String title;
  final String description;
  final List<String> features;
  final String callToAction;
  final String logoUrl;
  final String heroImageUrl;
  final String brandColor;
  final List<String> localImages;
  final bool isAccessible;
  final String? error;

  const WebsiteExtractedMetadata({
    required this.url,
    required this.domain,
    required this.brandName,
    required this.title,
    required this.description,
    required this.features,
    required this.callToAction,
    required this.logoUrl,
    required this.heroImageUrl,
    required this.brandColor,
    required this.localImages,
    required this.isAccessible,
    this.error,
  });

  factory WebsiteExtractedMetadata.fromJson(Map<String, dynamic> json) {
    return WebsiteExtractedMetadata(
      url: json['url'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      brandName: json['brand_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      callToAction: json['call_to_action'] as String? ?? 'Get Started Today',
      logoUrl: json['logo_url'] as String? ?? '',
      heroImageUrl: json['hero_image_url'] as String? ?? '',
      brandColor: json['brand_color'] as String? ?? '#2563EB',
      localImages: (json['local_images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isAccessible: json['is_accessible'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

/// Background job progress details.
class ViMaxJobState {
  final String jobId;
  final String status; // queued, preparing_inputs, generating_storyboard, generating_video_clips, assembling_video, validating_output, completed, failed, cancelled
  final String stage;
  final String stageMessage;
  final double progress; // 0.0 to 1.0
  final double elapsedSeconds;
  final String? mp4Path;
  final Map<String, dynamic>? validation;
  final String? error;
  final List<String> logs;

  const ViMaxJobState({
    required this.jobId,
    required this.status,
    required this.stage,
    required this.stageMessage,
    required this.progress,
    required this.elapsedSeconds,
    this.mp4Path,
    this.validation,
    this.error,
    this.logs = const [],
  });

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isRunning => !isCompleted && !isFailed && !isCancelled;

  factory ViMaxJobState.fromJson(Map<String, dynamic> json) {
    return ViMaxJobState(
      jobId: json['job_id'] as String? ?? '',
      status: json['status'] as String? ?? 'queued',
      stage: json['stage'] as String? ?? 'queued',
      stageMessage: json['stage_message'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      elapsedSeconds: (json['elapsed_seconds'] as num?)?.toDouble() ?? 0.0,
      mp4Path: json['mp4_path'] as String?,
      validation: json['validation'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      logs: (json['logs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Client service connecting AppGrowth Studio with the local ViMax Python API.
class ViMaxService {
  final String baseUrl;
  final HttpClient _client = HttpClient();
  Process? _backendProcess;

  ViMaxService({this.baseUrl = 'http://127.0.0.1:8765'});

  /// Checks whether the local Python backend is running and healthy.
  Future<ViMaxStatus> checkStatus() async {
    try {
      final request = await _client.getUrl(Uri.parse('$baseUrl/api/status')).timeout(const Duration(milliseconds: 1500));
      final response = await request.close().timeout(const Duration(milliseconds: 1500));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(body) as Map<String, dynamic>;
        return ViMaxStatus.fromJson(jsonMap);
      }
      return ViMaxStatus.unavailable('HTTP ${response.statusCode}');
    } catch (e) {
      return ViMaxStatus.unavailable(e.toString());
    }
  }

  /// Automatically launches the local Python backend process if it is not currently running.
  Future<bool> ensureBackendRunning() async {
    final status = await checkStatus();
    if (status.isAvailable) {
      return true;
    }

    try {
      final pyExe = 'py';
      final appPath = 'backend/app.py';
      if (!File(appPath).existsSync()) {
        debugPrint('[ViMax] backend/app.py not found in current working directory');
        return false;
      }

      debugPrint('[ViMax] Launching background ViMax service...');
      _backendProcess = await Process.start(
        pyExe,
        [appPath],
        mode: ProcessStartMode.detached,
      );

      // Poll up to 6 seconds for server readiness
      for (int i = 0; i < 12; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        final check = await checkStatus();
        if (check.isAvailable) {
          debugPrint('[ViMax] Local backend successfully connected!');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[ViMax] Error starting backend: $e');
    }
    return false;
  }

  /// Extracts rich website brand metadata, title, description, features, and images.
  Future<WebsiteExtractedMetadata?> extractWebsite(String url) async {
    try {
      final request = await _client.postUrl(Uri.parse('$baseUrl/api/web/extract')).timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'url': url}));
      final response = await request.close().timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(body) as Map<String, dynamic>;
        return WebsiteExtractedMetadata.fromJson(jsonMap);
      }
    } catch (e) {
      debugPrint('[ViMax] Website extraction error: $e');
    }
    return null;
  }

  /// Invokes ViMax narrative planning to generate structured scenes.
  Future<List<Map<String, dynamic>>?> planStoryboard({
    required String archetype,
    required String aspectRatio,
    required String resolution,
    required String brandName,
    String? productName,
    String? tagline,
    String? description,
    List<String>? features,
    String? callToAction,
    String? brandColor,
    String? userScript,
    List<String>? imagePaths,
    List<String>? videoClipPaths,
    int targetScenes = 5,
  }) async {
    try {
      final request = await _client.postUrl(Uri.parse('$baseUrl/api/video/plan')).timeout(const Duration(seconds: 20));
      request.headers.contentType = ContentType.json;
      final payload = {
        'archetype': archetype,
        'aspect_ratio': aspectRatio,
        'resolution': resolution,
        'brand_name': brandName,
        'product_name': productName,
        'tagline': tagline,
        'description': description,
        'features': features ?? [],
        'call_to_action': callToAction ?? 'Get Started Today',
        'brand_color': brandColor ?? '#2563EB',
        'user_script': userScript,
        'image_paths': imagePaths ?? [],
        'video_clip_paths': videoClipPaths ?? [],
        'target_scenes': targetScenes,
      };
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(body) as Map<String, dynamic>;
        final list = jsonMap['scenes'] as List<dynamic>?;
        if (list != null) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('[ViMax] Storyboard planning error: $e');
    }
    return null;
  }

  /// Granular scene field regeneration.
  Future<Map<String, dynamic>?> regenerateField({
    required Map<String, dynamic> scene,
    required String fieldType, // visual_only, narration_only, on_screen_text_only, scene_only
    String? brandName,
    String? brandColor,
  }) async {
    try {
      final request = await _client.postUrl(Uri.parse('$baseUrl/api/video/regenerate-field')).timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'scene': scene,
        'field_type': fieldType,
        'brand_name': brandName ?? '',
        'brand_color': brandColor ?? '#2563EB',
      }));
      final response = await request.close().timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(body) as Map<String, dynamic>;
        return jsonMap['scene'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('[ViMax] Field regeneration error: $e');
    }
    return null;
  }

  /// Submits an asynchronous video generation background job.
  Future<String?> submitGenerationJob({
    required List<Map<String, dynamic>> scenes,
    required String archetype,
    required String aspectRatio,
    required String resolution,
    required String brandColor,
    String? brandName,
    String? description,
    List<String>? features,
    String? userScript,
    List<String>? imagePaths,
    List<String>? videoClipPaths,
  }) async {
    try {
      final request = await _client.postUrl(Uri.parse('$baseUrl/api/video/generate')).timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'scenes': scenes,
        'archetype': archetype,
        'aspect_ratio': aspectRatio,
        'resolution': resolution,
        'brand_color': brandColor,
        'brand_name': brandName ?? '',
        'description': description ?? '',
        'features': features ?? [],
        'user_script': userScript,
        'image_paths': imagePaths ?? [],
        'video_clip_paths': videoClipPaths ?? [],
      }));
      final response = await request.close().timeout(const Duration(seconds: 15));

      if (response.statusCode == 202) {
        final body = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(body) as Map<String, dynamic>;
        return jsonMap['job_id'] as String?;
      }
    } catch (e) {
      debugPrint('[ViMax] Job submission error: $e');
    }
    return null;
  }

  /// Polls the live status of an asynchronous video generation job.
  Future<ViMaxJobState?> pollJob(String jobId) async {
    try {
      final request = await _client.getUrl(Uri.parse('$baseUrl/api/jobs/$jobId')).timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(body) as Map<String, dynamic>;
        return ViMaxJobState.fromJson(jsonMap);
      }
    } catch (e) {
      debugPrint('[ViMax] Poll job error: $e');
    }
    return null;
  }

  /// Cancels an in-progress generation job.
  Future<bool> cancelJob(String jobId) async {
    try {
      final request = await _client.postUrl(Uri.parse('$baseUrl/api/jobs/$jobId/cancel')).timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ViMax] Cancel job error: $e');
    }
    return false;
  }

  /// Exports the generated MP4 video to a destination path and verifies its stream integrity.
  Future<Map<String, dynamic>?> exportVideo({
    required String sourceMp4Path,
    required String destinationPath,
  }) async {
    try {
      final request = await _client.postUrl(Uri.parse('$baseUrl/api/video/export')).timeout(const Duration(seconds: 20));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'source_mp4_path': sourceMp4Path,
        'destination_path': destinationPath,
      }));
      final response = await request.close().timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[ViMax] Export error: $e');
    }
    return null;
  }

  void dispose() {
    _client.close(force: true);
    _backendProcess?.kill();
    _backendProcess = null;
  }
}
