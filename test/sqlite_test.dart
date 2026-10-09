import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

void main() {
  test('SQLite FFI initialization and basic query test', () async {
    // Check if winsqlite3 or sqlite3.dll can be loaded
    final pythonSqlite = r'C:\Users\Rehan Mughal\AppData\Local\Programs\Python\Python314\DLLs\sqlite3.dll';
    if (File(pythonSqlite).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(pythonSqlite));
    } else if (File(r'C:\Windows\System32\winsqlite3.dll').existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(r'C:\Windows\System32\winsqlite3.dll'));
    }

    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    await db.execute('CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT)');
    await db.insert('test_table', {'id': 1, 'name': 'AppGrowth Studio'});

    final results = await db.query('test_table');
    expect(results.length, 1);
    expect(results.first['name'], 'AppGrowth Studio');

    await db.close();
  });
}
