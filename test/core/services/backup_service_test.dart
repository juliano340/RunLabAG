import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late DateTime currentTime;

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
    currentTime = DateTime(2026, 11, 24, 14, 30);
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDir.path,
      docsDir.path,
    );
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

      final (success, restoredPhoto) = await BackupService().importBackup(
        backupJson,
      );
      expect(success, isTrue, reason: 'importBackup deve retornar true');
      expect(
        restoredPhoto,
        isTrue,
        reason: 'a foto embutida deve ser restaurada',
      );

      final rows = await db.query('user_profile', where: "id = 'current_user'");
      expect(rows, isNotEmpty);
      expect(rows.first['name'], 'Restaurado');

      final restoredPath = rows.first['profilePicturePath'] as String?;
      expect(
        restoredPath,
        isNotNull,
        reason: 'profilePicturePath deve apontar para a foto recriada',
      );

      final restoredFile = File(restoredPath!);
      expect(
        await restoredFile.exists(),
        isTrue,
        reason: 'arquivo da foto deve existir no disco',
      );
      expect(await restoredFile.readAsBytes(), originalBytes);
      expect(
        restoredPath.startsWith(docsDir.path),
        isTrue,
        reason: 'foto deve ser criada no diretório de documentos',
      );
    });

    test('v1 backup without photoData keeps import working', () async {
      final db = await DatabaseHelper.database;
      final backupJson = jsonEncode({
        'version': 1,
        'profile': {'id': 'current_user', 'name': 'Sem Foto'},
        'runs': <Map<String, dynamic>>[],
      });

      final (success, restoredPhoto) = await BackupService().importBackup(
        backupJson,
      );
      expect(success, isTrue);
      expect(restoredPhoto, isFalse);

      final rows = await db.query('user_profile');
      expect(rows.first['name'], 'Sem Foto');
    });

    test('v3 backup restores all user data tables', () async {
      final db = await DatabaseHelper.database;

      final backupJson = jsonEncode({
        'version': 3,
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': {
          'id': 'current_user',
          'name': 'Completo',
          'waterGoal': 2500.0,
        },
        'runs': [
          {
            'id': 'run_1',
            'date': DateTime.now().toIso8601String(),
            'distanceKm': 5.0,
            'durationSeconds': 1500,
            'pausedDurationSeconds': 60,
            'pace': '5:00',
            'calories': 350,
            'route': '[]',
            'type': '',
            'mood': '',
            'splits': '[]',
            'autoPauses': '[]',
          },
        ],
        'achievements': [
          {
            'id': 'ach_1',
            'title': 'Primeira Corrida',
            'description': 'Completou 1 treino',
            'iconCode': 58135,
            'earnedDate': DateTime.now().toIso8601String(),
          },
        ],
        'goalHistory': [
          {'periodId': '2026-08', 'goalType': 'weekly', 'goalValue': 25.0},
        ],
        'monitoredDistances': [
          {'distanceKm': 21.0},
        ],
        'strengthWorkouts': [
          {
            'id': 'sw_1',
            'name': 'Treino A',
            'date': DateTime.now().millisecondsSinceEpoch,
            'payload': '{}',
          },
        ],
        'workoutBlocks': [
          {'id': 'block_1', 'name': 'Peito', 'description': ''},
        ],
        'blockExercises': [
          {
            'id': 'ex_1',
            'blockId': 'block_1',
            'name': 'Supino',
            'defaultSets': 3,
            'defaultReps': '10',
            'defaultWeight': 40.0,
            'isTimeBased': 0,
            'orderIndex': 0,
          },
        ],
        'strengthTemplates': [
          {'id': 'tpl_1', 'name': 'Template A'},
        ],
        'templateItems': [
          {
            'id': 'ti_1',
            'templateId': 'tpl_1',
            'type': 'block',
            'itemId': 'block_1',
            'orderIndex': 0,
            'overrides': null,
          },
        ],
        'trainingEnrollments': [
          {
            'planId': 'beginner_5k',
            'startDate': DateTime.now().toIso8601String(),
            'currentWeek': 1,
            'currentDay': 1,
            'isActive': 1,
          },
        ],
      });

      final (success, _) = await BackupService().importBackup(backupJson);
      expect(success, isTrue);

      expect((await db.query('user_profile')).first['name'], 'Completo');
      expect(await db.query('runs').then((r) => r.length), 1);
      expect(
        await db.query('achievements').then((r) => r.first['title']),
        'Primeira Corrida',
      );
      expect(
        await db.query('goal_history').then((r) => r.first['goalValue']),
        25.0,
      );
      expect(
        await db
            .query('monitored_distances')
            .then((r) => r.single['distanceKm']),
        21.0,
        reason: 'distâncias monitoradas devem ser substituídas pelas do backup',
      );
      expect(await db.query('strength_workouts').then((r) => r.length), 1);
      expect(await db.query('workout_blocks').then((r) => r.length), 1);
      expect(await db.query('block_exercises').then((r) => r.length), 1);
      expect(
        await db.query('strength_workout_templates').then((r) => r.length),
        1,
      );
      expect(await db.query('template_items').then((r) => r.length), 1);
      expect(
        await db.query('user_training_enrollments').then((r) => r.length),
        1,
      );
    });

    test('import replaces enrollment without duplicating rows', () async {
      final db = await DatabaseHelper.database;
      final enrollment = {
        'planId': 'beginner_5k',
        'startDate': DateTime.now().toIso8601String(),
        'currentWeek': 2,
        'currentDay': 3,
        'isActive': 1,
      };
      final backupJson = jsonEncode({
        'version': 3,
        'trainingEnrollments': [enrollment],
      });

      await BackupService().importBackup(backupJson);
      await BackupService().importBackup(backupJson);

      expect(
        await db.query('user_training_enrollments').then((r) => r.length),
        1,
        reason: 'import repetido não deve duplicar inscrições',
      );
    });

    test('import deletes orphaned previous photo file', () async {
      final db = await DatabaseHelper.database;

      // Perfil atual apontando para uma foto antiga existente no disco
      final oldPhoto = File('${docsDir.path}/profile_pic_old.jpg');
      await oldPhoto.writeAsBytes(utf8.encode('OLD_PHOTO'));
      await db.insert('user_profile', {
        'id': 'current_user',
        'name': 'Antigo',
        'profilePicturePath': oldPhoto.path,
      });

      final newBytes = utf8.encode('NEW_PHOTO_BYTES');
      final backupJson = jsonEncode({
        'version': 2,
        'profile': {
          'id': 'current_user',
          'name': 'Novo',
          'photoData': base64Encode(newBytes),
        },
        'runs': <Map<String, dynamic>>[],
      });

      final (success, restoredPhoto) = await BackupService().importBackup(
        backupJson,
      );

      expect(success, isTrue);
      expect(restoredPhoto, isTrue);
      expect(
        await oldPhoto.exists(),
        isFalse,
        reason: 'foto antiga deve ser deletada após substituição',
      );

      final newPath =
          (await db.query('user_profile')).first['profilePicturePath']
              as String;
      expect(await File(newPath).readAsBytes(), newBytes);
    });
  });

  group('BackupService auto backup resiliente', () {
    BackupService buildService({
      bool android = true,
      bool storageGranted = true,
      Directory? externalDirectory,
      Future<Directory> Function()? documentsDirectory,
    }) {
      return BackupService(
        documentsDirectory: documentsDirectory,
        externalBackupDirectory:
            externalDirectory ?? Directory('${tempDir.path}/external/RunLab'),
        isAndroid: () => android,
        hasStoragePermission: () async => storageGranted,
        now: () => currentTime,
      );
    }

    List<File> snapshots(Directory dir) {
      if (!dir.existsSync()) return [];
      return dir.listSync().whereType<File>().where((file) {
        final name = file.uri.pathSegments.last;
        return name.startsWith('runlab_backup_') && name.endsWith('.json');
      }).toList();
    }

    test('cópia interna funciona sem permissão de storage', () async {
      final service = buildService(storageGranted: false);

      expect(await service.runAutoBackupIfEnabled(), isTrue);

      final internal = Directory('${docsDir.path}/backups');
      final latest = File('${internal.path}/runlab_auto_backup.json');
      expect(await latest.exists(), isTrue);
      final backup = jsonDecode(await latest.readAsString());
      expect(backup['version'], 4);
      expect(backup, contains('paceZones'));
      expect(backup, contains('trainingPlans'));
      expect(backup, contains('planSessions'));
      expect(backup, contains('exerciseDictionary'));
      expect(snapshots(internal), hasLength(1));
      expect(
        Directory('${tempDir.path}/external/RunLab').existsSync(),
        isFalse,
      );

      final status = await service.getBackupStatus();
      expect(status.hasBackup, isTrue);
      expect(status.lastSuccessfulBackupAt, currentTime);
      expect(status.successfulCopies, 1);
      expect(status.attemptedCopies, 1);
      expect(status.hasError, isFalse);
    });

    test('mantém rotações independentes no app e em Downloads', () async {
      final service = buildService();
      final start = currentTime;

      for (var i = 0; i < 7; i++) {
        currentTime = start.add(Duration(seconds: i));
        expect(await service.runAutoBackupIfEnabled(), isTrue);
      }

      final internal = Directory('${docsDir.path}/backups');
      final external = Directory('${tempDir.path}/external/RunLab');
      expect(snapshots(internal), hasLength(3));
      expect(snapshots(external), hasLength(5));
      expect(
        snapshots(internal).map((file) => file.uri.pathSegments.last),
        contains('runlab_backup_20261124_143006_000.json'),
      );
      expect(
        jsonDecode(
          await File('${external.path}/runlab_auto_backup.json').readAsString(),
        )['version'],
        4,
      );
      expect(
        await Directory(
          internal.path,
        ).list().where((e) => e.path.endsWith('.tmp')).toList(),
        isEmpty,
      );

      final status = await service.getBackupStatus();
      expect(status.successfulCopies, 2);
      expect(status.attemptedCopies, 2);
      expect(status.hasError, isFalse);
    });

    test('substitui latest corrompido por um backup validado', () async {
      final service = buildService(storageGranted: false);
      expect(await service.runAutoBackupIfEnabled(), isTrue);

      final latest = File('${docsDir.path}/backups/runlab_auto_backup.json');
      await latest.writeAsString('{"version":');
      currentTime = currentTime.add(const Duration(minutes: 1));

      expect(await service.runAutoBackupIfEnabled(), isTrue);
      expect(jsonDecode(await latest.readAsString())['version'], 4);
    });

    test('falha externa não invalida a cópia interna e fica visível', () async {
      final blockedPath = File('${tempDir.path}/external_blocked');
      await blockedPath.writeAsString('not a directory');
      final service = buildService(
        externalDirectory: Directory(blockedPath.path),
      );

      expect(await service.runAutoBackupIfEnabled(), isTrue);

      final status = await service.getBackupStatus();
      expect(status.hasBackup, isTrue);
      expect(status.successfulCopies, 1);
      expect(status.attemptedCopies, 2);
      expect(status.isPartialSuccess, isTrue);
      expect(status.lastError, contains('cópia externa'));
    });

    test('falha total registra erro e não inventa sucesso', () async {
      final blocked = File('${tempDir.path}/documents_blocked');
      await blocked.writeAsString('not a directory');
      final service = buildService(
        storageGranted: false,
        documentsDirectory: () async => Directory(blocked.path),
      );

      expect(await service.runAutoBackupIfEnabled(), isFalse);

      final status = await service.getBackupStatus();
      expect(status.hasBackup, isFalse);
      expect(status.successfulCopies, 0);
      expect(status.attemptedCopies, 1);
      expect(status.lastAttemptAt, currentTime);
      expect(status.lastError, contains('cópia interna'));
    });

    test('toggle desligado não grava arquivos', () async {
      SharedPreferences.setMockInitialValues({'auto_backup_enabled': false});
      final service = buildService();

      expect(await service.runAutoBackupIfEnabled(), isFalse);
      expect(Directory('${docsDir.path}/backups').existsSync(), isFalse);
    });

    test('aviso de backup velho ocorre uma vez por dia', () async {
      SharedPreferences.setMockInitialValues({
        'auto_backup_enabled': true,
        'auto_backup_monitoring_since': currentTime
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch,
      });
      final service = buildService();

      expect(await service.shouldWarnStaleBackup(), isTrue);
      await service.markStaleBackupWarningShown();
      expect(await service.shouldWarnStaleBackup(), isFalse);

      currentTime = currentTime.add(const Duration(days: 1));
      expect(await service.shouldWarnStaleBackup(), isTrue);
    });

    test('backup recente não gera aviso de envelhecimento', () async {
      final service = buildService(storageGranted: false);
      expect(await service.runAutoBackupIfEnabled(), isTrue);
      currentTime = currentTime.add(const Duration(days: 6));

      expect(await service.shouldWarnStaleBackup(), isFalse);
    });
  });
}
