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
import '../models/video_project_model.dart';

class VideoExportResult {
  final bool success;
  final String exportDirectoryPath;
  final List<String> renderedFramePaths;
  final String htmlPreviewPath;
  final String? mp4FilePath;
  final String? batchScriptPath;
  final int? fileSizeBytes;
  final String? errorMessage;

  const VideoExportResult({
    required this.success,
    required this.exportDirectoryPath,
    this.renderedFramePaths = const [],
    required this.htmlPreviewPath,
    this.mp4FilePath,
    this.batchScriptPath,
    this.fileSizeBytes,
    this.errorMessage,
  });
}

/// Standalone local video project export and rendering engine.
/// Renders high-res scene slide frames with genuine assets,
/// generates timed SRT subtitle tracks, narration scripts, interactive HTML5 video preview player,
/// and compiles genuine MP4 videos using FFmpeg when available.
class VideoProjectExporter {
  final FfmpegService _ffmpegService;

  VideoProjectExporter([FfmpegService? ffmpegService])
      : _ffmpegService = ffmpegService ?? FfmpegService();

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
      final dims = _getDimensions(project.aspectRatio, project.resolution);
      final width = dims.width;
      final height = dims.height;

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
${project.scenes.map((s) => 'Scene ${s.sceneNumber} (${s.durationSeconds}s) [${s.badgeText}]:\nTitle: "${s.title}"\nNarration: "${s.narrationText}"\nVisual: ${s.visualDescription}\n').join('\n')}
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
        srtBuffer.writeln(scene.captionText ?? scene.narrationText);
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

      // 6. Check if FFmpeg is available and attempt automatic background MP4 compilation
      String? mp4Path;
      int? fileSize;
      try {
        final ffmpegStatus = await _ffmpegService.checkAvailability();
        if (ffmpegStatus.isAvailable && renderedFrames.isNotEmpty) {
          final targetMp4 = p.join(baseDir.path, 'video_${project.id}.mp4');
          final success = await _ffmpegService.renderVideo(
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

          if (success && File(targetMp4).existsSync() && File(targetMp4).lengthSync() > 0) {
            mp4Path = targetMp4;
            fileSize = File(targetMp4).lengthSync();
            await AppLogger.success('video_export', 'Exported MP4 video: $mp4Path (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)');
          }
        }
      } catch (err) {
        await AppLogger.warn('video_export', 'FFmpeg render attempt: $err');
      }

      await AppLogger.success(
        'video_export',
        'Video project exported: ${renderedFrames.length} scene frames rendered to ${baseDir.path}.',
      );

      return VideoExportResult(
        success: true,
        exportDirectoryPath: baseDir.path,
        renderedFramePaths: renderedFrames,
        htmlPreviewPath: htmlFile.path,
        mp4FilePath: mp4Path,
        batchScriptPath: batFile.path,
        fileSizeBytes: fileSize,
      );
    } catch (e) {
      await AppLogger.error('video_export', 'Failed to export video project: $e');
      return VideoExportResult(
        success: false,
        exportDirectoryPath: '',
        htmlPreviewPath: '',
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

    // First ensure project is rendered locally
    final localResult = await exportProject(
      project: project,
      app: app,
    );

    if (!localResult.success) {
      return localResult;
    }

    // If MP4 was rendered, copy it to the user's destination
    if (localResult.mp4FilePath != null && File(localResult.mp4FilePath!).existsSync()) {
      final srcFile = File(localResult.mp4FilePath!);
      await srcFile.copy(destinationFilePath);
      final size = File(destinationFilePath).lengthSync();
      return VideoExportResult(
        success: true,
        exportDirectoryPath: destDir.path,
        renderedFramePaths: localResult.renderedFramePaths,
        htmlPreviewPath: localResult.htmlPreviewPath,
        mp4FilePath: destinationFilePath,
        fileSizeBytes: size,
      );
    }

    return localResult;
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

      // 1. Background Gradient
      final bgPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(width.toDouble(), height.toDouble()),
          [
            const Color(0xFF070B14),
            const Color(0xFF131131),
            const Color(0xFF0B132B),
          ],
        );
      canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

      // Subtle ambient background ring
      final ambientPaint = Paint()
        ..color = const Color(0x1A6366F1)
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
          text: scene.title,
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

      // 4. Narration Hook Banner / Overlay Caption
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

      final narrationPainter = TextPainter(
        text: TextSpan(
          text: '“${scene.narrationText}”',
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

      // If no actual image was painted, draw visual placeholder with icon & typography
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
            text: scene.visualDescription,
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

      // 6. Bottom Callout
      final ctaY = height - margin - 40;
      final ctaPainter = TextPainter(
        text: TextSpan(
          text: '▶ $appTitle • Available on Google Play',
          style: const TextStyle(
            color: Color(0xFF34D399),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ctaPainter.paint(canvas, Offset((width - ctaPainter.width) / 2, ctaY));

      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final paddedIndex = sceneIndex.toString().padLeft(2, '0');
        final file = File(p.join(outputDir.path, 'scene_$paddedIndex.png'));
        await file.writeAsBytes(byteData.buffer.asUint8List());
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  Future<ui.Image?> _loadLocalImage(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  VideoDimensions _getDimensions(String aspectRatio, String resolution) {
    return getDimensions(aspectRatio, resolution);
  }

  String _formatSrtTimestamp(double totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds.toInt() % 60;
    final int milliseconds = ((totalSeconds - totalSeconds.toInt()) * 1000).toInt();

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')},${milliseconds.toString().padLeft(3, '0')}';
  }

  String _generateHtmlPlayer({
    required VideoProjectModel project,
    required String appName,
    required List<String> framePaths,
    required String aspectRatio,
  }) {
    final relativeFrames = framePaths.map((f) => 'frames/${p.basename(f)}').toList();
    final framesJson = jsonEncode(relativeFrames);
    final scenesJson = jsonEncode(project.scenes.map((s) => s.toMap()).toList());

    final isVertical = aspectRatio == '9:16';
    final isSquare = aspectRatio == '1:1';
    final stageWidth = isVertical ? '360px' : (isSquare ? '480px' : '640px');
    final stageHeight = isVertical ? '640px' : (isSquare ? '480px' : '360px');

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${project.title} - Video Project Preview</title>
  <style>
    body {
      margin: 0;
      background: #0b1120;
      color: #f8fafc;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      min-height: 100vh;
      padding: 24px;
      box-sizing: border-box;
    }
    .header { text-align: center; margin-bottom: 20px; }
    .header h1 { margin: 0 0 6px 0; font-size: 22px; color: #fff; }
    .header p { margin: 0; font-size: 13px; color: #94a3b8; }
    .stage {
      position: relative;
      width: $stageWidth;
      height: $stageHeight;
      background: #000;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 20px 40px rgba(0,0,0,0.7);
      border: 2px solid #334155;
    }
    .stage img {
      width: 100%;
      height: 100%;
      object-fit: contain;
      transition: opacity 0.35s ease-in-out;
    }
    .controls {
      margin-top: 18px;
      display: flex;
      align-items: center;
      gap: 12px;
      background: #1e293b;
      padding: 10px 20px;
      border-radius: 30px;
      border: 1px solid #334155;
    }
    .btn {
      background: #6366f1;
      border: none;
      color: white;
      padding: 8px 18px;
      border-radius: 20px;
      font-weight: 600;
      cursor: pointer;
      font-size: 13px;
    }
    .btn:hover { background: #4f46e5; }
    .info { font-size: 13px; color: #94a3b8; }
  </style>
</head>
<body>
  <div class="header">
    <h1>${project.title}</h1>
    <p>Aspect Ratio: $aspectRatio | Duration: ${project.totalDurationSeconds}s | Scenes: ${project.scenes.length}</p>
  </div>

  <div class="stage">
    <img id="currentFrame" src="${relativeFrames.isNotEmpty ? relativeFrames.first : ''}" alt="Scene Preview" />
  </div>

  <div class="controls">
    <button class="btn" id="playBtn" onclick="togglePlay()">▶ Play Preview</button>
    <button class="btn" onclick="prevScene()">◀ Prev</button>
    <button class="btn" onclick="nextScene()">Next ▶</button>
    <span class="info" id="sceneIndicator">Scene 1 / ${relativeFrames.length}</span>
  </div>

  <script>
    const frames = $framesJson;
    const scenes = $scenesJson;
    let currentIndex = 0;
    let isPlaying = false;
    let timer = null;

    function showScene(idx) {
      if (idx < 0) idx = 0;
      if (idx >= frames.length) idx = frames.length - 1;
      currentIndex = idx;
      document.getElementById('currentFrame').src = frames[currentIndex];
      document.getElementById('sceneIndicator').innerText = `Scene \${currentIndex + 1} / \${frames.length}`;
    }

    function nextScene() {
      if (currentIndex < frames.length - 1) {
        showScene(currentIndex + 1);
      } else {
        showScene(0);
      }
    }

    function prevScene() {
      if (currentIndex > 0) showScene(currentIndex - 1);
    }

    function togglePlay() {
      isPlaying = !isPlaying;
      document.getElementById('playBtn').innerText = isPlaying ? '⏸ Pause' : '▶ Play Preview';
      if (isPlaying) {
        timer = setInterval(nextScene, 3500);
      } else {
        clearInterval(timer);
      }
    }
  </script>
</body>
</html>''';
  }

  /// Calculates video pixel dimensions based on aspect ratio and resolution
  static VideoDimensions getDimensions(String aspectRatio, String resolution) {
    final is720p = resolution.toLowerCase().contains('720');
    switch (aspectRatio) {
      case '9:16':
        return is720p ? const VideoDimensions(720, 1280) : const VideoDimensions(1080, 1920);
      case '1:1':
        return is720p ? const VideoDimensions(720, 720) : const VideoDimensions(1080, 1080);
      case '16:9':
      default:
        return is720p ? const VideoDimensions(1280, 720) : const VideoDimensions(1920, 1080);
    }
  }
}

class VideoDimensions {
  final int width;
  final int height;
  const VideoDimensions(this.width, this.height);
}
