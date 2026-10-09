import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:appgrowth_studio/core/backup/backup_service.dart';

void main() {
  group('Backup & Restore Service Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('validateBackupFile verifies SQLite magic header', () async {
      // 1. Valid SQLite file header
      final validFile = File('${tempDir.path}/valid.sqlite');
      final validHeader = 'SQLite format 3\x00'.codeUnits;
      final dummyBody = List<int>.filled(120, 0);
      await validFile.writeAsBytes([...validHeader, ...dummyBody]);

      final isValid = await BackupService.instance.validateBackupFile(validFile);
      expect(isValid, isTrue);

      // 2. Corrupt / invalid file header
      final invalidFile = File('${tempDir.path}/invalid.sqlite');
      await invalidFile.writeAsString('This is not an SQLite database file at all!');

      final isInvalid = await BackupService.instance.validateBackupFile(invalidFile);
      expect(isInvalid, isFalse);

      // 3. Non-existent file
      final missingFile = File('${tempDir.path}/missing.sqlite');
      expect(await BackupService.instance.validateBackupFile(missingFile), isFalse);
    });

    test('BackupManifest serializes and deserializes accurately', () {
      final now = DateTime.now().toUtc();
      final manifest = BackupManifest(
        appName: 'AppGrowth Studio',
        backupVersion: 1,
        timestamp: now,
        databaseFileName: 'AppGrowth_Backup_20261009.sqlite',
        fileSize: 40960,
      );

      final map = manifest.toMap();
      final reconstructed = BackupManifest.fromMap(map);

      expect(reconstructed.appName, equals('AppGrowth Studio'));
      expect(reconstructed.backupVersion, equals(1));
      expect(reconstructed.databaseFileName, equals('AppGrowth_Backup_20261009.sqlite'));
      expect(reconstructed.fileSize, equals(40960));
    });
  });
}
