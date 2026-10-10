import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Native Windows file and folder dialog helper.
/// Uses standard System.Windows.Forms on Windows without requiring
/// external native plugins or Windows Developer Mode symlinks.
class NativeFileDialogHelper {
  /// Opens a native Windows file open dialog to select one or more media files.
  static Future<List<String>> pickFiles({
    String title = 'Select Media Files',
    String filter = 'Media Files (*.png;*.jpg;*.jpeg;*.mp4;*.mov)|*.png;*.jpg;*.jpeg;*.mp4;*.mov|Images (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg|Videos (*.mp4;*.mov)|*.mp4;*.mov|All Files (*.*)|*.*',
    bool allowMultiple = true,
    String? initialDirectory,
  }) async {
    if (!Platform.isWindows) return [];

    try {
      final tempDir = Directory.systemTemp.createTempSync('picker_');
      final scriptFile = File(p.join(tempDir.path, 'open_dialog.ps1'));

      final scriptContent = StringBuffer()
        ..writeln('Add-Type -AssemblyName System.Windows.Forms')
        ..writeln('\$dialog = New-Object System.Windows.Forms.OpenFileDialog')
        ..writeln('\$dialog.Title = "$title"')
        ..writeln('\$dialog.Filter = "$filter"')
        ..writeln('\$dialog.Multiselect = \$${allowMultiple ? "True" : "False"}');

      if (initialDirectory != null && Directory(initialDirectory).existsSync()) {
        final escapedInit = initialDirectory.replaceAll('\\', '\\\\');
        scriptContent.writeln('\$dialog.InitialDirectory = "$escapedInit"');
      }

      scriptContent
        ..writeln('if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {')
        ..writeln('    \$dialog.FileNames | ForEach-Object { Write-Output \$_ }')
        ..writeln('}');

      await scriptFile.writeAsString(scriptContent.toString());

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
      ]);

      try {
        scriptFile.deleteSync();
        tempDir.deleteSync(recursive: true);
      } catch (_) {}

      if (result.exitCode == 0) {
        final lines = result.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && File(s).existsSync())
            .toList();
        return lines;
      }
    } catch (e) {
      debugPrint('NativeFileDialogHelper.pickFiles error: $e');
    }
    return [];
  }

  /// Opens a native Windows save file dialog to choose output destination and filename.
  static Future<String?> saveFile({
    String title = 'Save Video to Computer',
    String defaultFileName = 'promotional_video.mp4',
    String filter = 'MP4 Video (*.mp4)|*.mp4|All Files (*.*)|*.*',
    String? initialDirectory,
  }) async {
    if (!Platform.isWindows) return null;

    try {
      final tempDir = Directory.systemTemp.createTempSync('saver_');
      final scriptFile = File(p.join(tempDir.path, 'save_dialog.ps1'));

      final scriptContent = StringBuffer()
        ..writeln('Add-Type -AssemblyName System.Windows.Forms')
        ..writeln('\$dialog = New-Object System.Windows.Forms.SaveFileDialog')
        ..writeln('\$dialog.Title = "$title"')
        ..writeln('\$dialog.FileName = "$defaultFileName"')
        ..writeln('\$dialog.Filter = "$filter"');

      if (initialDirectory != null && Directory(initialDirectory).existsSync()) {
        final escapedInit = initialDirectory.replaceAll('\\', '\\\\');
        scriptContent.writeln('\$dialog.InitialDirectory = "$escapedInit"');
      }

      scriptContent
        ..writeln('if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {')
        ..writeln('    Write-Output \$dialog.FileName')
        ..writeln('}');

      await scriptFile.writeAsString(scriptContent.toString());

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
      ]);

      try {
        scriptFile.deleteSync();
        tempDir.deleteSync(recursive: true);
      } catch (_) {}

      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty) {
          return path;
        }
      }
    } catch (e) {
      debugPrint('NativeFileDialogHelper.saveFile error: $e');
    }
    return null;
  }

  /// Opens a native Windows folder browser dialog to select an export directory.
  static Future<String?> pickFolder({
    String title = 'Select Export Folder',
    String? initialDirectory,
  }) async {
    if (!Platform.isWindows) return null;

    try {
      final tempDir = Directory.systemTemp.createTempSync('folder_');
      final scriptFile = File(p.join(tempDir.path, 'folder_dialog.ps1'));

      final scriptContent = StringBuffer()
        ..writeln('Add-Type -AssemblyName System.Windows.Forms')
        ..writeln('\$dialog = New-Object System.Windows.Forms.FolderBrowserDialog')
        ..writeln('\$dialog.Description = "$title"');

      if (initialDirectory != null && Directory(initialDirectory).existsSync()) {
        final escapedInit = initialDirectory.replaceAll('\\', '\\\\');
        scriptContent.writeln('\$dialog.SelectedPath = "$escapedInit"');
      }

      scriptContent
        ..writeln('if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {')
        ..writeln('    Write-Output \$dialog.SelectedPath')
        ..writeln('}');

      await scriptFile.writeAsString(scriptContent.toString());

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
      ]);

      try {
        scriptFile.deleteSync();
        tempDir.deleteSync(recursive: true);
      } catch (_) {}

      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty && Directory(path).existsSync()) {
          return path;
        }
      }
    } catch (e) {
      debugPrint('NativeFileDialogHelper.pickFolder error: $e');
    }
    return null;
  }

  /// Opens the directory in Windows File Explorer.
  static Future<bool> openDirectory(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final result = await Process.run('explorer.exe', [dir.path]);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('NativeFileDialogHelper.openDirectory error: $e');
      return false;
    }
  }

  /// Convenience alias for pickFolder
  static Future<String?> pickDirectory({
    String title = 'Select Export Folder',
    String? initialDirectory,
  }) => pickFolder(title: title, initialDirectory: initialDirectory);

  /// Convenience method to pick a single file
  static Future<String?> pickSingleFile({
    String title = 'Select File',
    String filter = 'All Files (*.*)|*.*',
    String? initialDirectory,
  }) async {
    final list = await pickFiles(
      title: title,
      filter: filter,
      allowMultiple: false,
      initialDirectory: initialDirectory,
    );
    return list.firstOrNull;
  }
}
