import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:runlabag/core/services/backup_service.dart';
import 'package:runlabag/core/services/database_helper.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  final String tempPath;
  final String docsPath;
  _FakePathProviderPlatform(this.tempPath, this.docsPath);

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  late Directory tempDir;
  late Directory docsDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Garante um banco limpo — o ffi persiste o arquivo entre execuções
    final dbPath =
        '${await databaseFactory.getDatabasesPath()}/runlab_database.db';
    await databaseFactory.deleteDatabase(dbPath);

    tempDir = await Directory.systemTemp.createTemp('runlab_backup_test');
    docsDir = await Directory.systemTemp.createTemp('runlab_docs_test');
    PathProviderPlatform.instance =
        _FakePathProviderPlatform(tempDir.path, docsDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
    await docsDir.delete(recursive: true);
    DatabaseHelper.resetForTest();
  });

  group('BackupService.importBackup photo restore', () {
    test('restores profile photo from base64 photoData', () async {
      final db = await DatabaseHelper.database;
      await db.insert('user_profile', {
        'id': 'current_user',
        'name': 'Antigo',
        'profilePicturePath': null,
      });

      // Simula o arquivo de foto original e o backup v2 (com photoData)
      final originalBytes = utf8.encode('FAKE_JPEG_BYTES_123');
      final backupJson = jsonEncode({
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': {
          'id': 'current_user',
          'name': 'Restaurado',
          'age': 30,
          'weight': 75.0,
          'height': 180.0,
          'profilePicturePath':
              '/data/user/0/old/app_flutter/profile_pic_123.jpg',
          'weeklyGoal': 20.0,
          'monthlyGoal': 80.0,
          'waterGoal': 2000.0,
          'kmNotificationsEnabled': 1,
          'photoData': base64Encode(originalBytes),
        },
        'runs': <Map<String, dynamic>>[],
      });

      final (success, restoredPhoto) =
          await BackupService().importBackup(backupJson);
      expect(success, isTrue, reason: 'importBackup deve retornar true');
      expect(restoredPhoto, isTrue,
          reason: 'a foto embutida deve ser restaurada');

      final rows = await db.query(
        'user_profile',
        where: "id = 'current_user'",
      );
      expect(rows, isNotEmpty);
      expect(rows.first['name'], 'Restaurado');

      final restoredPath = rows.first['profilePicturePath'] as String?;
      expect(restoredPath, isNotNull,
          reason: 'profilePicturePath deve apontar para a foto recriada');

      final restoredFile = File(restoredPath!);
      expect(await restoredFile.exists(), isTrue,
          reason: 'arquivo da foto deve existir no disco');
      expect(await restoredFile.readAsBytes(), originalBytes);
      expect(restoredPath.startsWith(docsDir.path), isTrue,
          reason: 'foto deve ser criada no diretório de documentos');
    });

    test('v1 backup without photoData keeps import working', () async {
      final db = await DatabaseHelper.database;
      final backupJson = jsonEncode({
        'version': 1,
        'profile': {'id': 'current_user', 'name': 'Sem Foto'},
        'runs': <Map<String, dynamic>>[],
      });

      final (success, restoredPhoto) =
          await BackupService().importBackup(backupJson);
      expect(success, isTrue);
      expect(restoredPhoto, isFalse);

      final rows = await db.query('user_profile');
      expect(rows.first['name'], 'Sem Foto');
    });
  });
}
