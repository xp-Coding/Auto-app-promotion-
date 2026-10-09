import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

/// Initializes SQLite for Windows Desktop using FFI.
///
/// Looks for sqlite3.dll in:
/// 1. Project / executable directory
/// 2. Windows system built-in winsqlite3.dll
/// 3. Python or local runtime fallbacks
class SqliteInitializer {
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;

    if (Platform.isWindows) {
      _configureWindowsSqlite();
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _initialized = true;
  }

  static void _configureWindowsSqlite() {
    final possibleDllPaths = [
      // 1. Next to the running executable or project root
      p.join(Directory.current.path, 'sqlite3.dll'),
      p.join(p.dirname(Platform.resolvedExecutable), 'sqlite3.dll'),
      // 2. Python standard DLL directory if present
      p.join(Platform.environment['LOCALAPPDATA'] ?? '', 'Programs', 'Python', 'Python314', 'DLLs', 'sqlite3.dll'),
      p.join(Platform.environment['LOCALAPPDATA'] ?? '', 'Programs', 'Python', 'Python312', 'DLLs', 'sqlite3.dll'),
      p.join(Platform.environment['LOCALAPPDATA'] ?? '', 'Programs', 'Python', 'Python311', 'DLLs', 'sqlite3.dll'),
      // 3. Built-in Windows SQLite DLL (present on Windows 10 & 11)
      r'C:\Windows\System32\winsqlite3.dll',
    ];

    for (final dllPath in possibleDllPaths) {
      if (File(dllPath).existsSync()) {
        try {
          open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(dllPath));
          debugPrint('SQLite dynamic library loaded from: $dllPath');
          return;
        } catch (e) {
          debugPrint('Failed to load SQLite DLL from $dllPath: $e');
        }
      }
    }

    debugPrint('Using default system SQLite resolution');
  }
}
