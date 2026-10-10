import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';

class FfmpegStatus {
  final bool isAvailable;
  final String? executablePath;
  final String? versionInfo;
  final String setupInstructions;

  const FfmpegStatus({
    required this.isAvailable,
    this.executablePath,
    this.versionInfo,
    required this.setupInstructions,
  });
}

class FfmpegRenderProgress {
  final double progressPercent; // 0.0 to 1.0
  final String currentPhase;
  final String? detailMessage;

  const FfmpegRenderProgress({
    required this.progressPercent,
    required this.currentPhase,
    this.detailMessage,
  });
}

class FfmpegService {
  static const String settingKeyFfmpegPath = 'ffmpeg_path';
  static const String settingKeyDefaultExportFolder = 'default_export_folder';

  /// Resolves the FFmpeg binary on the host machine
  Future<FfmpegStatus> checkAvailability() async {
    final customPath = await getCustomFfmpegPath();
    final candidates = <String>[];

    if (customPath != null && customPath.trim().isNotEmpty) {
      candidates.add(customPath.trim());
    }

    // App Directory
    candidates.add(p.join(Directory.current.path, 'ffmpeg.exe'));
    candidates.add(p.join(AppDatabase.getDatabaseDirectoryPath(), 'ffmpeg.exe'));

    // Common Windows install paths
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      candidates.add(p.join(localAppData, 'Microsoft', 'WinGet', 'Links', 'ffmpeg.exe'));
    }
    candidates.add(r'C:\ffmpeg\bin\ffmpeg.exe');
    candidates.add(r'C:\ProgramData\chocolatey\bin\ffmpeg.exe');

    // System PATH via where.exe
    try {
      final whereResult = await Process.run('where.exe', ['ffmpeg']);
      if (whereResult.exitCode == 0) {
        final lines = whereResult.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.toLowerCase().endsWith('.exe'));
        candidates.addAll(lines);
      }
    } catch (_) {}

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        try {
          final res = await Process.run(candidate, ['-version']);
          if (res.exitCode == 0) {
            final output = res.stdout.toString();
            final firstLine = output.split('\n').firstOrNull ?? 'FFmpeg detected';
            return FfmpegStatus(
              isAvailable: true,
              executablePath: candidate,
              versionInfo: firstLine.trim(),
              setupInstructions: 'FFmpeg is installed and ready for hardware-accelerated video rendering.',
            );
          }
        } catch (_) {}
      }
    }

    return const FfmpegStatus(
      isAvailable: false,
      setupInstructions: '''
FFmpeg is required to compile high-definition MP4 videos directly on Windows.

Installation Options (Free & Open Source):
1. Quick Install (Recommended):
   Open Windows Terminal or PowerShell and run:
   winget install Gyan.FFmpeg

2. Manual Download:
   • Download from https://www.gyan.dev/ffmpeg/builds/ (ffmpeg-release-essentials.zip)
   • Extract ffmpeg.exe to C:\\ffmpeg\\bin\\ or into your AppGrowth Studio application folder.

3. Custom Path:
   Specify your custom ffmpeg.exe path in AppGrowth Studio Settings.

* Note: Even without FFmpeg, AppGrowth Studio generates high-resolution Canvas slide frames, timed SRT subtitles, narration scripts, interactive HTML5 video players, and a one-click .bat compiler.
''',
    );
  }

  /// Retrieves custom FFmpeg path from SQLite settings
  Future<String?> getCustomFfmpegPath() async {
    try {
      final db = await AppDatabase.instance.database;
      final res = await db.query(
        'application_settings',
        where: 'key = ?',
        whereArgs: [settingKeyFfmpegPath],
        limit: 1,
      );
      if (res.isNotEmpty) {
        return res.first['value'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Saves custom FFmpeg path to SQLite settings
  Future<void> setCustomFfmpegPath(String path) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert(
        'application_settings',
        {'key': settingKeyFfmpegPath, 'value': path.trim()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  /// Retrieves default export folder from SQLite settings
  Future<String> getDefaultExportFolder() async {
    try {
      final db = await AppDatabase.instance.database;
      final res = await db.query(
        'application_settings',
        where: 'key = ?',
        whereArgs: [settingKeyDefaultExportFolder],
        limit: 1,
      );
      if (res.isNotEmpty) {
        final saved = res.first['value'] as String?;
        if (saved != null && saved.isNotEmpty && Directory(saved).existsSync()) {
          return saved;
        }
      }
    } catch (_) {}

    // Default fallback: ~/Videos/AppGrowthStudio or AppData/video_exports
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      final defaultVideos = Directory(p.join(userProfile, 'Videos', 'AppGrowthStudio'));
      if (!defaultVideos.existsSync()) defaultVideos.createSync(recursive: true);
      return defaultVideos.path;
    }

    final fallback = Directory(p.join(AppDatabase.getDatabaseDirectoryPath(), 'video_exports'));
    if (!fallback.existsSync()) fallback.createSync(recursive: true);
    return fallback.path;
  }

  /// Saves default export folder to SQLite settings
  Future<void> setDefaultExportFolder(String folderPath) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert(
        'application_settings',
        {'key': settingKeyDefaultExportFolder, 'value': folderPath.trim()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  /// Renders scene image slides and trimmed video clips into a single MP4 file.
  Future<bool> renderVideo({
    required List<String> sceneFramePaths,
    required List<double> sceneDurations,
    required String outputMp4Path,
    required int width,
    required int height,
    String? backgroundMusicPath,
    double backgroundMusicVolume = 0.2,
    List<String?>? sceneVideoClipPaths,
    List<double?>? clipStartTimes,
    List<double?>? clipEndTimes,
    void Function(FfmpegRenderProgress progress)? onProgress,
  }) async {
    final status = await checkAvailability();
    if (!status.isAvailable || status.executablePath == null) {
      throw Exception('FFmpeg is not available on this system. Please check settings or install FFmpeg.');
    }

    final ffmpegBin = status.executablePath!;
    final tempDir = Directory.systemTemp.createTempSync('ffmpeg_render_');

    try {
      onProgress?.call(const FfmpegRenderProgress(
        progressPercent: 0.1,
        currentPhase: 'Preparing scene sequence and timeline...',
      ));

      // 1. Build FFmpeg concat demuxer file for slides
      final concatListFile = File(p.join(tempDir.path, 'concat_list.txt'));
      final concatBuffer = StringBuffer();

      final sceneCount = sceneFramePaths.length;
      final segmentOutputs = <String>[];

      for (int i = 0; i < sceneCount; i++) {
        final framePath = sceneFramePaths[i];
        final duration = (i < sceneDurations.length) ? sceneDurations[i] : 3.5;
        final clipPath = (sceneVideoClipPaths != null && i < sceneVideoClipPaths.length) ? sceneVideoClipPaths[i] : null;

        // If scene has an existing video clip, encode the clip segment
        if (clipPath != null && File(clipPath).existsSync()) {
          onProgress?.call(FfmpegRenderProgress(
            progressPercent: 0.2 + (0.5 * (i / sceneCount)),
            currentPhase: 'Processing video clip for Scene ${i + 1}...',
          ));

          final segMp4 = p.join(tempDir.path, 'segment_$i.mp4');
          final startTime = (clipStartTimes != null && i < clipStartTimes.length) ? clipStartTimes[i] ?? 0.0 : 0.0;
          final endTime = (clipEndTimes != null && i < clipEndTimes.length) ? clipEndTimes[i] : null;

          final clipArgs = <String>['-y'];
          if (startTime > 0) {
            clipArgs.addAll(['-ss', startTime.toStringAsFixed(2)]);
          }
          if (endTime != null && endTime > startTime) {
            clipArgs.addAll(['-to', endTime.toStringAsFixed(2)]);
          } else {
            clipArgs.addAll(['-t', duration.toStringAsFixed(2)]);
          }

          clipArgs.addAll([
            '-i', clipPath,
            '-vf', 'scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=black',
            '-c:v', 'libx264',
            '-pix_fmt', 'yuv420p',
            '-r', '30',
            '-c:a', 'aac',
            segMp4,
          ]);

          final clipRes = await Process.run(ffmpegBin, clipArgs);
          if (clipRes.exitCode == 0 && File(segMp4).existsSync()) {
            segmentOutputs.add(segMp4);
            continue;
          }
        }

        // Standard image frame slide segment
        final segMp4 = p.join(tempDir.path, 'segment_$i.mp4');
        final slideArgs = [
          '-y',
          '-loop', '1',
          '-t', duration.toStringAsFixed(2),
          '-i', framePath,
          '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
          '-vf', 'scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=black',
          '-c:v', 'libx264',
          '-t', duration.toStringAsFixed(2),
          '-pix_fmt', 'yuv420p',
          '-r', '30',
          '-c:a', 'aac',
          '-shortest',
          segMp4,
        ];

        final slideRes = await Process.run(ffmpegBin, slideArgs);
        if (slideRes.exitCode == 0 && File(segMp4).existsSync()) {
          segmentOutputs.add(segMp4);
        } else {
          // Fallback to demuxer line
          final escapedPath = framePath.replaceAll('\\', '/');
          concatBuffer.writeln("file '$escapedPath'");
          concatBuffer.writeln('duration ${duration.toStringAsFixed(2)}');
        }
      }

      onProgress?.call(const FfmpegRenderProgress(
        progressPercent: 0.75,
        currentPhase: 'Assembling and encoding multi-scene timeline...',
      ));

      // Concatenate segments
      if (segmentOutputs.isNotEmpty && segmentOutputs.length == sceneCount) {
        final segListFile = File(p.join(tempDir.path, 'segments_list.txt'));
        final segBuffer = StringBuffer();
        for (final seg in segmentOutputs) {
          final escaped = seg.replaceAll('\\', '/');
          segBuffer.writeln("file '$escaped'");
        }
        await segListFile.writeAsString(segBuffer.toString());

        final concatArgs = <String>[
          '-y',
          '-f', 'concat',
          '-safe', '0',
          '-i', segListFile.path,
        ];

        // Background music mixing if present
        if (backgroundMusicPath != null && File(backgroundMusicPath).existsSync()) {
          concatArgs.addAll([
            '-stream_loop', '-1',
            '-i', backgroundMusicPath,
            '-filter_complex', '[1:a]volume=${backgroundMusicVolume.toStringAsFixed(2)}[bgm];[0:a][bgm]amix=inputs=2:duration=first[aout]',
            '-map', '0:v',
            '-map', '[aout]',
          ]);
        } else {
          concatArgs.addAll([
            '-c:a', 'aac',
          ]);
        }

        concatArgs.addAll([
          '-c:v', 'libx264',
          '-pix_fmt', 'yuv420p',
          '-r', '30',
          outputMp4Path,
        ]);

        final renderResult = await Process.run(ffmpegBin, concatArgs);
        if (renderResult.exitCode == 0 && File(outputMp4Path).existsSync() && File(outputMp4Path).lengthSync() > 0) {
          onProgress?.call(const FfmpegRenderProgress(
            progressPercent: 1.0,
            currentPhase: 'Render complete!',
          ));
          await AppLogger.success('video_render', 'Rendered video successfully: $outputMp4Path');
          return true;
        }
      }

      // Concat Demuxer fallback
      if (concatBuffer.isNotEmpty) {
        // Last image entry repeat required by concat demuxer
        final lastEscaped = sceneFramePaths.last.replaceAll('\\', '/');
        concatBuffer.writeln("file '$lastEscaped'");
        await concatListFile.writeAsString(concatBuffer.toString());

        final fallbackArgs = <String>[
          '-y',
          '-f', 'concat',
          '-safe', '0',
          '-i', concatListFile.path,
          '-vf', 'scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=black',
          '-c:v', 'libx264',
          '-r', '30',
          '-pix_fmt', 'yuv420p',
        ];

        if (backgroundMusicPath != null && File(backgroundMusicPath).existsSync()) {
          fallbackArgs.addAll([
            '-stream_loop', '-1',
            '-i', backgroundMusicPath,
            '-filter_complex', '[1:a]volume=${backgroundMusicVolume.toStringAsFixed(2)}[aout]',
            '-map', '0:v',
            '-map', '[aout]',
            '-shortest',
          ]);
        }

        fallbackArgs.add(outputMp4Path);

        final res = await Process.run(ffmpegBin, fallbackArgs);
        if (res.exitCode == 0 && File(outputMp4Path).existsSync() && File(outputMp4Path).lengthSync() > 0) {
          onProgress?.call(const FfmpegRenderProgress(
            progressPercent: 1.0,
            currentPhase: 'Render complete!',
          ));
          await AppLogger.success('video_render', 'Rendered video successfully via demuxer: $outputMp4Path');
          return true;
        }
      }

      return false;
    } catch (e) {
      await AppLogger.error('video_render', 'FFmpeg rendering error: $e');
      return false;
    } finally {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    }
  }
}
