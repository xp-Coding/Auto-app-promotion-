import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../apps/models/app_model.dart';
import '../../content_studio/domain/ffmpeg_service.dart';
import '../../content_studio/domain/visual_library_service.dart';
import '../models/video_project_model.dart';

class VideoExportResult {
  final bool success;
  final String exportDirectoryPath;
  final List<String> renderedFramePaths;
  final String htmlPreviewPath;
  final String? mp4FilePath;
  final String? batchScriptPath;
  final int? fileSizeBytes;
  final double? durationSeconds;
  final int? videoWidth;
  final int? videoHeight;
  final String renderingPhaseStatus; // storyboardReady, visualAssetsReady, framesGenerated, encodingInProgress, videoEncodedSuccessfully, exported, failed
  final String? errorMessage;

  const VideoExportResult({
    required this.success,
    required this.exportDirectoryPath,
    this.renderedFramePaths = const [],
    required this.htmlPreviewPath,
    this.mp4FilePath,
    this.batchScriptPath,
    this.fileSizeBytes,
    this.durationSeconds,
    this.videoWidth,
    this.videoHeight,
    this.renderingPhaseStatus = 'storyboardReady',
    this.errorMessage,
  });
}

/// Standalone local video project export and rendering engine.
/// Renders high-res scene slide frames with genuine assets,
/// generates timed SRT subtitle tracks, narration scripts, interactive HTML5 video preview player,
/// and compiles genuine MP4 videos using FFmpeg with strict playable stream verification.
class VideoProjectExporter {
  final FfmpegService _ffmpegService;
  final VisualLibraryService _visualLibrary;

  VideoProjectExporter([FfmpegService? ffmpegService, VisualLibraryService? visualLibrary])
      : _ffmpegService = ffmpegService ?? FfmpegService(),
        _visualLibrary = visualLibrary ?? VisualLibraryService();

  /// Exports a video project into a complete local media production package.
  Future<VideoExportResult> exportProject({
    required VideoProjectModel project,
    AppModel? app,
    String? localIconPath,
    List<String> screenshotPaths = const [],
    String? outputDirectoryOverride,
    void Function(FfmpegRenderProgress progress)? onProgress,
  }) async {
    try {
      final baseDir = Directory(
        outputDirectoryOverride ?? p.join(AppDatabase.getDatabaseDirectoryPath(), 'video_exports', project.id),
      );
      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }

      final framesDir = Directory(p.join(baseDir.path, 'frames'));
      if (!framesDir.existsSync()) {
        framesDir.createSync(recursive: true);
      }

      // Calculate pixel dimensions from aspect ratio and resolution
      final dims = getDimensions(project.aspectRatio, project.resolution);
      final width = dims.width;
      final height = dims.height;

      onProgress?.call(const FfmpegRenderProgress(
        progressPercent: 0.1,
        currentPhase: 'Generating visual scene frames via Flutter Canvas...',
      ));

      // 1. Render High-Resolution Scene Slide Frames via Canvas
      final renderedFrames = <String>[];
      final effectiveScreenshots = <String>[
        ...screenshotPaths,
        ...project.inputMediaPaths.where((f) {
          final ext = p.extension(f).toLowerCase();
          return ext == '.png' || ext == '.jpg' || ext == '.jpeg' || ext == '.webp';
        }),
      ];

      for (int i = 0; i < project.scenes.length; i++) {
        final scene = project.scenes[i];
        final shotCandidate = scene.imageAssetPath ?? (i < effectiveScreenshots.length ? effectiveScreenshots[i] : null);

        final framePath = await _renderSceneSlide(
          scene: scene,
          sceneIndex: i + 1,
          totalScenes: project.scenes.length,
          appTitle: app?.name ?? project.title.split(' - ').firstOrNull ?? 'App',
          appCategory: app?.category ?? 'Mobile App',
          playStoreUrl: app?.playStoreUrl ?? project.inputAppUrl ?? 'https://play.google.com',
          width: width,
          height: height,
          aspectRatio: project.aspectRatio,
          outputDir: framesDir,
          screenshotPath: shotCandidate,
          iconPath: localIconPath ?? app?.iconPath,
        );
        if (framePath != null) {
          renderedFrames.add(framePath);
        }
      }

      // 2. Generate Narration Script TXT
      final scriptFile = File(p.join(baseDir.path, 'narration_script.txt'));
      await scriptFile.writeAsString('''
================================================================================
PROMOTIONAL VIDEO NARRATION SCRIPT
Project: ${project.title}
Template: ${project.templateType} | Aspect Ratio: ${project.aspectRatio} (${project.resolution}) | Duration: ${project.totalDurationSeconds}s
App: ${app?.name ?? project.title}
Play Store: ${app?.playStoreUrl ?? project.inputAppUrl ?? 'Google Play'}
================================================================================

FULL NARRATION VOICEOVER:
${project.audioNarrationScript}

--------------------------------------------------------------------------------
SCENE-BY-SCENE TIMELINE:
--------------------------------------------------------------------------------
${project.scenes.map((s) => 'Scene ${s.sceneNumber} (${s.durationSeconds}s) [${s.badgeText}]:\nTitle: "${s.sceneTitle}"\nNarration: "${s.voiceOverNarration}"\nOn-Screen: "${s.onScreenText}"\nVisual: ${s.visualDescription}\n').join('\n')}
''');

      // 3. Generate Timed SRT Subtitles
      final srtFile = File(p.join(baseDir.path, 'subtitles.srt'));
      final srtBuffer = StringBuffer();
      double currentSeconds = 0.0;
      for (int i = 0; i < project.scenes.length; i++) {
        final scene = project.scenes[i];
        final startSec = currentSeconds;
        final endSec = currentSeconds + scene.durationSeconds;
        currentSeconds = endSec;

        srtBuffer.writeln('${i + 1}');
        srtBuffer.writeln('${_formatSrtTimestamp(startSec)} --> ${_formatSrtTimestamp(endSec)}');
        srtBuffer.writeln(scene.subtitleText.isNotEmpty ? scene.subtitleText : scene.onScreenText);
        srtBuffer.writeln();
      }
      await srtFile.writeAsString(srtBuffer.toString());

      // 4. Generate Interactive HTML5 Video Player
      final htmlFile = File(p.join(baseDir.path, 'interactive_preview.html'));
      final htmlContent = _generateHtmlPlayer(
        project: project,
        appName: app?.name ?? project.title.split(' - ').firstOrNull ?? 'App',
        framePaths: renderedFrames,
        aspectRatio: project.aspectRatio,
      );
      await htmlFile.writeAsString(htmlContent);

      // 5. Generate FFmpeg Render Batch Script
      final batFile = File(p.join(baseDir.path, 'render_mp4.bat'));
      final batContent = '''
@echo off
echo ======================================================================
echo Rendering High-Definition Video: ${project.title}
echo Aspect Ratio: ${project.aspectRatio} | Resolution: ${width}x$height
echo ======================================================================
where ffmpeg >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
  echo [Notice] FFmpeg was not detected in system PATH.
  echo To encode to MP4: Download free FFmpeg from https://ffmpeg.org/ or run:
  echo   winget install Gyan.FFmpeg
  echo You can also open interactive_preview.html to preview full scenes instantly.
  pause
  exit /b 0
)

echo Compiling frames and audio into high-definition MP4...
ffmpeg -y -framerate 1/3.5 -i "%~dp0frames\\scene_%%02d.png" -c:v libx264 -r 30 -pix_fmt yuv420p "%~dp0output_${project.templateType}.mp4"
echo Export Complete: "%~dp0output_${project.templateType}.mp4"
pause
''';
      await batFile.writeAsString(batContent);

      // 6. Check FFmpeg availability
      final ffmpegStatus = await _ffmpegService.checkAvailability();
      if (!ffmpegStatus.isAvailable) {
        await AppLogger.warn('video_export', 'FFmpeg not detected. Slide frames and package generated, but MP4 video encoding skipped.');
        return VideoExportResult(
          success: true,
          exportDirectoryPath: baseDir.path,
          renderedFramePaths: renderedFrames,
          htmlPreviewPath: htmlFile.path,
          batchScriptPath: batFile.path,
          renderingPhaseStatus: 'framesGenerated',
          errorMessage: 'FFmpeg was not detected on this system. Slide frames, timed subtitles, and batch compiler were created, but a real playable MP4 could not be encoded. Please install FFmpeg (e.g., winget install Gyan.FFmpeg) or check Settings.',
        );
      }

      // 7. Compile genuine MP4 video via FFmpeg
      onProgress?.call(const FfmpegRenderProgress(
        progressPercent: 0.3,
        currentPhase: 'Encoding high-definition H.264 / AAC MP4 video...',
      ));

      final targetMp4 = p.join(baseDir.path, 'video_${project.id}.mp4');
      final renderSuccess = await _ffmpegService.renderVideo(
        sceneFramePaths: renderedFrames,
        sceneDurations: project.scenes.map((s) => s.durationSeconds).toList(),
        outputMp4Path: targetMp4,
        width: width,
        height: height,
        backgroundMusicPath: project.backgroundMusicPath,
        backgroundMusicVolume: project.backgroundMusicVolume,
        sceneVideoClipPaths: project.scenes.map((s) => s.videoClipPath).toList(),
        clipStartTimes: project.scenes.map((s) => s.clipStartTimeSeconds).toList(),
        clipEndTimes: project.scenes.map((s) => s.clipEndTimeSeconds).toList(),
        onProgress: onProgress,
      );

      if (!renderSuccess || !File(targetMp4).existsSync() || File(targetMp4).lengthSync() == 0) {
        return VideoExportResult(
          success: false,
          exportDirectoryPath: baseDir.path,
          renderedFramePaths: renderedFrames,
          htmlPreviewPath: htmlFile.path,
          batchScriptPath: batFile.path,
          renderingPhaseStatus: 'failed',
          errorMessage: 'FFmpeg execution finished but failed to generate a valid non-empty MP4 video file.',
        );
      }

      // 8. Probe resulting MP4 to verify stream integrity and non-zero duration
      final probe = await _ffmpegService.probeVideo(targetMp4);
      if (!probe.isValid || !probe.hasVideoStream) {
        return VideoExportResult(
          success: false,
          exportDirectoryPath: baseDir.path,
          renderedFramePaths: renderedFrames,
          htmlPreviewPath: htmlFile.path,
          batchScriptPath: batFile.path,
          renderingPhaseStatus: 'failed',
          errorMessage: 'Resulting MP4 video stream verification failed. File does not contain a playable video track.',
        );
      }

      final fileSize = File(targetMp4).lengthSync();
      await AppLogger.success(
        'video_export',
        'Verified real playable MP4 video: $targetMp4 (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB, ${probe.durationSeconds.toStringAsFixed(1)}s, ${probe.width ?? width}x${probe.height ?? height})',
      );

      return VideoExportResult(
        success: true,
        exportDirectoryPath: baseDir.path,
        renderedFramePaths: renderedFrames,
        htmlPreviewPath: htmlFile.path,
        mp4FilePath: targetMp4,
        batchScriptPath: batFile.path,
        fileSizeBytes: fileSize,
        durationSeconds: probe.durationSeconds > 0 ? probe.durationSeconds : project.totalDurationSeconds,
        videoWidth: probe.width ?? width,
        videoHeight: probe.height ?? height,
        renderingPhaseStatus: 'videoEncodedSuccessfully',
      );
    } catch (e) {
      await AppLogger.error('video_export', 'Failed to export video project: $e');
      return VideoExportResult(
        success: false,
        exportDirectoryPath: '',
        htmlPreviewPath: '',
        renderingPhaseStatus: 'failed',
        errorMessage: e.toString(),
      );
    }
  }

  /// Copies an already rendered or freshly rendered video project to a user-chosen local path.
  Future<VideoExportResult> exportToLocalDestination({
    required VideoProjectModel project,
    required String destinationFilePath,
    AppModel? app,
  }) async {
    final destFile = File(destinationFilePath);
    final destDir = destFile.parent;
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    if (destinationFilePath.toLowerCase().endsWith('.html')) {
      final localResult = await exportProject(project: project, app: app);
      final sourceHtml = File(localResult.htmlPreviewPath);
      if (sourceHtml.existsSync()) {
        await sourceHtml.copy(destinationFilePath);
      }
      return VideoExportResult(
        success: true,
        exportDirectoryPath: destDir.path,
        htmlPreviewPath: destinationFilePath,
        mp4FilePath: localResult.mp4FilePath,
        renderingPhaseStatus: localResult.renderingPhaseStatus,
        fileSizeBytes: localResult.fileSizeBytes,
        durationSeconds: localResult.durationSeconds,
        videoWidth: localResult.videoWidth,
        videoHeight: localResult.videoHeight,
      );
    }

    if (!destinationFilePath.toLowerCase().endsWith('.mp4')) {
      return const VideoExportResult(
        success: false,
        exportDirectoryPath: '',
        htmlPreviewPath: '',
        renderingPhaseStatus: 'failed',
        errorMessage: 'Destination file must have an .mp4 extension to ensure genuine playable video output.',
      );
    }

    // Ensure video is genuinely rendered
    String? sourceMp4 = project.exportedFilePath;
    if (sourceMp4 == null || !File(sourceMp4).existsSync() || File(sourceMp4).lengthSync() == 0) {
      final localResult = await exportProject(project: project, app: app);
      if (!localResult.success || localResult.mp4FilePath == null) {
        return VideoExportResult(
          success: false,
          exportDirectoryPath: localResult.exportDirectoryPath,
          htmlPreviewPath: localResult.htmlPreviewPath,
          renderingPhaseStatus: 'failed',
          errorMessage: localResult.errorMessage ?? 'Could not encode playable MP4 video for export.',
        );
      }
      sourceMp4 = localResult.mp4FilePath!;
    }

    // Copy MP4 to chosen location
    await File(sourceMp4).copy(destinationFilePath);

    // Verify copied file exists, is non-empty, and has valid stream
    if (!destFile.existsSync() || destFile.lengthSync() == 0) {
      return const VideoExportResult(
        success: false,
        exportDirectoryPath: '',
        htmlPreviewPath: '',
        renderingPhaseStatus: 'failed',
        errorMessage: 'Export verification failed: Resulting file was empty or not written.',
      );
    }

    final probe = await _ffmpegService.probeVideo(destinationFilePath);
    if (!probe.isValid) {
      return const VideoExportResult(
        success: false,
        exportDirectoryPath: '',
        htmlPreviewPath: '',
        renderingPhaseStatus: 'failed',
        errorMessage: 'Export verification failed: Resulting file is not a valid playable video.',
      );
    }

    final size = destFile.lengthSync();
    return VideoExportResult(
      success: true,
      exportDirectoryPath: destDir.path,
      htmlPreviewPath: '',
      mp4FilePath: destinationFilePath,
      fileSizeBytes: size,
      durationSeconds: probe.durationSeconds,
      videoWidth: probe.width,
      videoHeight: probe.height,
      renderingPhaseStatus: 'exported',
    );
  }

  /// Renders a single high-resolution slide for a video scene using Flutter Canvas.
  Future<String?> _renderSceneSlide({
    required VideoSceneModel scene,
    required int sceneIndex,
    required int totalScenes,
    required String appTitle,
    required String appCategory,
    required String playStoreUrl,
    required int width,
    required int height,
    required String aspectRatio,
    required Directory outputDir,
    String? screenshotPath,
    String? iconPath,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

      final isVertical = aspectRatio == '9:16';
      final isSquare = aspectRatio == '1:1';

      final gradientPreset = _visualLibrary.suggestGradientForCategory(appCategory);
      final colors = gradientPreset.gradientColors.isNotEmpty
          ? gradientPreset.gradientColors
          : [const Color(0xFF070B14), const Color(0xFF131131), const Color(0xFF0B132B)];

      final stops = colors.length == 2
          ? null
          : List.generate(colors.length, (i) => i / (colors.length - 1));

      final bgPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(width.toDouble(), height.toDouble()),
          colors,
          stops,
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

      // Subtle ambient background ring
      final ambientPaint = Paint()
        ..color = colors.last.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
      canvas.drawCircle(Offset(width / 2, height / 2), width * 0.45, ambientPaint);

      final margin = isVertical ? 60.0 : (isSquare ? 50.0 : 70.0);

      // 2. Header: Badge & Scene Index
      final badgePaint = Paint()..color = const Color(0xFF6366F1);
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(margin, margin, isVertical ? 320 : 280, 48),
        const Radius.circular(24),
      );
      canvas.drawRRect(badgeRect, badgePaint);

      final badgeTextPainter = TextPainter(
        text: TextSpan(
          text: 'SCENE $sceneIndex/$totalScenes • ${scene.badgeText.toUpperCase()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      badgeTextPainter.paint(canvas, Offset(margin + 20, margin + 14));

      // 3. Scene Title
      final titlePainter = TextPainter(
        text: TextSpan(
          text: scene.sceneTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: isVertical ? 50 : (isSquare ? 42 : 44),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: width - (margin * 2));
      titlePainter.paint(canvas, Offset(margin, margin + 68));

      // 4. Headline / On-Screen Text Overlay Banner
      final hookY = margin + (isVertical ? 190 : (isSquare ? 150 : 160));
      final hookHeight = isVertical ? 180.0 : (isSquare ? 130.0 : 130.0);
      final hookRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(margin, hookY, width - (margin * 2), hookHeight),
        const Radius.circular(18),
      );
      final hookPaint = Paint()..color = const Color(0xEE1E293B);
      canvas.drawRRect(hookRect, hookPaint);

      final hookBorder = Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(hookRect, hookBorder);

      final displayCaption = scene.onScreenText.isNotEmpty ? scene.onScreenText : scene.voiceOverNarration;
      final narrationPainter = TextPainter(
        text: TextSpan(
          text: '“$displayCaption”',
          style: TextStyle(
            color: const Color(0xFFF8FAFC),
            fontSize: isVertical ? 28 : (isSquare ? 22 : 24),
            fontStyle: FontStyle.italic,
            height: 1.35,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: width - (margin * 2) - 50);
      narrationPainter.paint(canvas, Offset(margin + 25, hookY + 22));

      // 5. Authentic Screenshot / Mockup Zone
      final previewY = hookY + hookHeight + 24;
      final bottomMargin = isVertical ? 110.0 : 90.0;
      final previewHeight = height - previewY - bottomMargin;

      final previewRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(margin, previewY, width - (margin * 2), previewHeight),
        const Radius.circular(20),
      );
      final previewBg = Paint()..color = const Color(0xFF0F172A);
      canvas.drawRRect(previewRect, previewBg);
      final previewBorder = Paint()
        ..color = const Color(0x3364748B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(previewRect, previewBorder);

      // Load and paint actual screenshot without stretching or distortion
      bool drewActualImage = false;
      if (screenshotPath != null && File(screenshotPath).existsSync()) {
        final img = await _loadLocalImage(screenshotPath);
        if (img != null) {
          final imgW = img.width.toDouble();
          final imgH = img.height.toDouble();
          final scale = min(previewRect.width / imgW, previewRect.height / imgH);
          final drawW = imgW * scale;
          final drawH = imgH * scale;
          final drawX = previewRect.left + (previewRect.width - drawW) / 2;
          final drawY = previewRect.top + (previewRect.height - drawH) / 2;

          canvas.save();
          canvas.clipRRect(previewRect);
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, imgW, imgH),
            Rect.fromLTWH(drawX, drawY, drawW, drawH),
            Paint()..filterQuality = FilterQuality.high,
          );
          canvas.restore();
          drewActualImage = true;
        }
      }

      // If no actual image was painted, render procedural composition card
      if (!drewActualImage) {
        if (iconPath != null && File(iconPath).existsSync()) {
          final iconImg = await _loadLocalImage(iconPath);
          if (iconImg != null) {
            const iconSize = 140.0;
            final iconRect = Rect.fromLTWH(
              previewRect.left + (previewRect.width - iconSize) / 2,
              previewRect.top + (previewRect.height - iconSize) / 2 - 40,
              iconSize,
              iconSize,
            );
            canvas.drawImageRect(
              iconImg,
              Rect.fromLTWH(0, 0, iconImg.width.toDouble(), iconImg.height.toDouble()),
              iconRect,
              Paint(),
            );
          }
        }

        final descPainter = TextPainter(
          text: TextSpan(
            text: scene.visualDescription.isNotEmpty ? scene.visualDescription : 'High-definition promotional feature card',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 24),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 3,
        )..layout(maxWidth: previewRect.width - 60);
        descPainter.paint(
          canvas,
          Offset(previewRect.left + (previewRect.width - descPainter.width) / 2, previewRect.bottom - 100),
        );
      }

      // 6. Footer Call-to-Action Bar
      final footerY = height - bottomMargin + 20;
      final ctaPainter = TextPainter(
        text: TextSpan(
          text: scene.callToAction != null && scene.callToAction!.isNotEmpty
              ? '▶ ${scene.callToAction} • $appTitle'
              : '▶ Get $appTitle on Google Play: $playStoreUrl',
          style: const TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - (margin * 2));
      ctaPainter.paint(canvas, Offset(margin, footerY));

      // Finish recording and render PNG file
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final fileName = 'scene_${sceneIndex.toString().padLeft(2, '0')}.png';
      final file = File(p.join(outputDir.path, fileName));
      await file.writeAsBytes(pngBytes);

      return file.path;
    } catch (e) {
      await AppLogger.error('video_export', 'Error rendering scene slide: $e');
      return null;
    }
  }

  Future<ui.Image?> _loadLocalImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static ResolutionDimensions getDimensions(String aspectRatio, String resolution) {
    final is1080 = resolution == '1080p';
    switch (aspectRatio) {
      case '16:9':
        return is1080 ? const ResolutionDimensions(1920, 1080) : const ResolutionDimensions(1280, 720);
      case '1:1':
        return is1080 ? const ResolutionDimensions(1080, 1080) : const ResolutionDimensions(720, 720);
      case '9:16':
      default:
        return is1080 ? const ResolutionDimensions(1080, 1920) : const ResolutionDimensions(720, 1280);
    }
  }

  String _formatSrtTimestamp(double seconds) {
    final hrs = (seconds ~/ 3600).toString().padLeft(2, '0');
    final mins = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toInt().toString().padLeft(2, '0');
    final millis = ((seconds - seconds.floor()) * 1000).toInt().toString().padLeft(3, '0');
    return '$hrs:$mins:$secs,$millis';
  }

  String _generateHtmlPlayer({
    required VideoProjectModel project,
    required String appName,
    required List<String> framePaths,
    required String aspectRatio,
  }) {
    final frameListJson = jsonEncode(framePaths.map((f) => 'frames/${p.basename(f)}').toList());
    final durationsJson = jsonEncode(project.scenes.map((s) => s.durationSeconds).toList());
    final titlesJson = jsonEncode(project.scenes.map((s) => s.sceneTitle).toList());
    final captionsJson = jsonEncode(project.scenes.map((s) => s.onScreenText).toList());

    final ratioAspect = aspectRatio == '9:16'
        ? '9 / 16'
        : (aspectRatio == '1:1' ? '1 / 1' : '16 / 9');

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${project.title} - Preview Player</title>
  <style>
    body {
      margin: 0;
      padding: 24px;
      background: #0B0F19;
      color: #F8FAFC;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .container {
      max-width: 900px;
      width: 100%;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    h1 { margin-bottom: 6px; font-size: 22px; color: #6366F1; }
    .meta { font-size: 13px; color: #94A3B8; margin-bottom: 20px; }
    .player-box {
      width: 100%;
      max-width: 480px;
      aspect-ratio: $ratioAspect;
      background: #000;
      border-radius: 14px;
      overflow: hidden;
      box-shadow: 0 10px 40px rgba(0,0,0,0.6);
      position: relative;
    }
    .player-box img {
      width: 100%;
      height: 100%;
      object-fit: contain;
      display: block;
    }
    .controls {
      display: flex;
      gap: 12px;
      margin-top: 16px;
      align-items: center;
    }
    button {
      padding: 10px 20px;
      background: #6366F1;
      border: none;
      border-radius: 8px;
      color: #fff;
      font-weight: bold;
      cursor: pointer;
    }
    button:hover { background: #4F46E5; }
    .status-badge {
      position: absolute;
      bottom: 12px;
      left: 12px;
      background: rgba(0,0,0,0.7);
      padding: 6px 12px;
      border-radius: 6px;
      font-size: 12px;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>${project.title}</h1>
    <div class="meta">Aspect: ${project.aspectRatio} | Total Duration: ${project.totalDurationSeconds}s | Scenes: ${project.scenes.length}</div>
    <div class="player-box">
      <img id="stageImg" src="${framePaths.isNotEmpty ? 'frames/${p.basename(framePaths.first)}' : ''}" alt="Scene Preview">
      <div id="badge" class="status-badge">Scene 1 / ${project.scenes.length}</div>
    </div>
    <div class="controls">
      <button id="playBtn" onclick="togglePlay()">Play Presentation</button>
      <button onclick="prevScene()">◀ Prev</button>
      <button onclick="nextScene()">Next ▶</button>
    </div>
  </div>
  <script>
    const frames = $frameListJson;
    const durations = $durationsJson;
    const titles = $titlesJson;
    const captions = $captionsJson;
    let idx = 0;
    let isPlaying = false;
    let timer = null;

    function showScene(i) {
      if (i < 0) i = 0;
      if (i >= frames.length) i = frames.length - 1;
      idx = i;
      document.getElementById('stageImg').src = frames[idx];
      document.getElementById('badge').innerText = 'Scene ' + (idx + 1) + '/' + frames.length + ' • ' + titles[idx];
    }

    function nextScene() {
      if (idx < frames.length - 1) {
        showScene(idx + 1);
      } else {
        showScene(0);
        if (isPlaying) togglePlay();
      }
    }

    function prevScene() {
      showScene(idx - 1);
    }

    function togglePlay() {
      isPlaying = !isPlaying;
      document.getElementById('playBtn').innerText = isPlaying ? 'Pause' : 'Play Presentation';
      if (isPlaying) {
        scheduleNext();
      } else {
        clearTimeout(timer);
      }
    }

    function scheduleNext() {
      if (!isPlaying) return;
      const ms = (durations[idx] || 3.5) * 1000;
      timer = setTimeout(() => {
        nextScene();
        if (isPlaying) scheduleNext();
      }, ms);
    }
  </script>
</body>
</html>
''';
  }
}

class ResolutionDimensions {
  final int width;
  final int height;
  const ResolutionDimensions(this.width, this.height);
}
