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
          }
        ],
        'achievements': [
          {
            'id': 'ach_1',
            'title': 'Primeira Corrida',
            'description': 'Completou 1 treino',
            'iconCode': 58135,
            'earnedDate': DateTime.now().toIso8601String(),
          }
        ],
        'waterIntake': [
          {'amount': 250, 'timestamp': DateTime.now().toIso8601String()},
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
          }
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
          }
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
          }
        ],
        'trainingEnrollments': [
          {
            'planId': 'beginner_5k',
            'startDate': DateTime.now().toIso8601String(),
            'currentWeek': 1,
            'currentDay': 1,
            'isActive': 1,
          }
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
      expect(await db.query('water_intake').then((r) => r.length), 1);
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

      final (success, restoredPhoto) =
          await BackupService().importBackup(backupJson);

      expect(success, isTrue);
      expect(restoredPhoto, isTrue);
      expect(await oldPhoto.exists(), isFalse,
          reason: 'foto antiga deve ser deletada após substituição');

      final newPath =
          (await db.query('user_profile')).first['profilePicturePath'] as String;
      expect(await File(newPath).readAsBytes(), newBytes);
    });
  });
}
