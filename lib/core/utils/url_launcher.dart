import 'dart:io';
import 'package:flutter/foundation.dart';

/// Opens URLs in the user's default browser on Windows and other desktop platforms
/// using native system execution without external plugins.
class AppUrlLauncher {
  static Future<bool> openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    try {
      if (Platform.isWindows) {
        // Use cmd.exe /c start "" "url" to launch the default registered web browser
        final result = await Process.run('cmd', ['/c', 'start', '', trimmed]);
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        final result = await Process.run('open', [trimmed]);
        return result.exitCode == 0;
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [trimmed]);
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
    return false;
  }
}
