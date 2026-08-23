import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class BackupService {
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';
  static const int _maxTimestampedBackups = 5;
  static const String _autoBackupFolderName = 'RunLab';
  static const String _autoBackupLatestFile = 'runlab_auto_backup.json';

  final DatabaseService _dbService = DatabaseService();

  /// Retorna (json, incluiuFoto).
  Future<(String, bool)> _buildBackupJson() async {
    final db = await _dbService.database;
    final profileData = await db.query('user_profile');
    final runsData = await db.query('runs');

    Map<String, dynamic>? profile =
        profileData.isNotEmpty ? Map<String, dynamic>.from(profileData.first) : null;

    bool includedPhoto = false;
    final photoPath = profile?['profilePicturePath'] as String?;
    if (photoPath != null && photoPath.isNotEmpty) {
      final photoFile = File(photoPath);
      if (await photoFile.exists()) {
        profile!['photoData'] = base64Encode(await photoFile.readAsBytes());
        includedPhoto = true;
      } else {
        debugPrint('Backup: arquivo de foto não encontrado em $photoPath');
      }
    }

    final Map<String, dynamic> backup = {
      'version': 3,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profile,
      'runs': runsData,
      'achievements': await db.query('achievements'),
      'waterIntake': await db.query('water_intake'),
      'goalHistory': await db.query('goal_history'),
      'monitoredDistances': await db.query('monitored_distances'),
      'strengthWorkouts': await db.query('strength_workouts'),
      'workoutBlocks': await db.query('workout_blocks'),
      'blockExercises': await db.query('block_exercises'),
      'strengthTemplates': await db.query('strength_workout_templates'),
      'templateItems': await db.query('template_items'),
      'trainingEnrollments': await db.query('user_training_enrollments'),
    };

    return (jsonEncode(backup), includedPhoto);
  }

  /// Exporta o backup. Retorna (sucesso, incluiuFoto).
  Future<(bool, bool)> exportBackup() async {
    final (jsonString, includedPhoto) = await _buildBackupJson();

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/runlab_backup_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject:
          'Backup RunLab - ${DateTime.now().day}/${DateTime.now().month}',
    );

    return (true, includedPhoto);
  }

  /// Importa um backup. Retorna (sucesso, restaurouFoto).
  Future<(bool, bool)> importBackup(String jsonContent) async {
    try {
      final Map<String, dynamic> backup = jsonDecode(jsonContent);
      final db = await _dbService.database;

      bool restoredPhoto = false;
      String? newPhotoPath;

      // Guarda o caminho atual para limpeza de foto órfã após o import
      final currentProfile = await db.query('user_profile');
      final oldPhotoPath = currentProfile.isNotEmpty
          ? currentProfile.first['profilePicturePath'] as String?
          : null;

      await db.transaction((txn) async {
        if (backup['profile'] != null) {
          final profile = Map<String, dynamic>.from(backup['profile']);

          final photoData = profile.remove('photoData');
          if (photoData is String && photoData.isNotEmpty) {
            final restoredPath = await _restorePhotoFile(photoData);
            if (restoredPath != null) {
              profile['profilePicturePath'] = restoredPath;
              restoredPhoto = true;
              newPhotoPath = restoredPath;
            } else {
              debugPrint('Import: falha ao recriar foto do backup');
            }
          }

          await txn.insert(
            'user_profile',
            profile,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        if (backup['runs'] != null) {
          await _upsertRows(txn, 'runs', backup['runs']);
        }
        if (backup['achievements'] != null) {
          await _upsertRows(txn, 'achievements', backup['achievements']);
        }
        if (backup['waterIntake'] != null) {
          await _upsertRows(txn, 'water_intake', backup['waterIntake']);
        }
        if (backup['goalHistory'] != null) {
          await _upsertRows(txn, 'goal_history', backup['goalHistory']);
        }
        if (backup['monitoredDistances'] != null) {
          await txn.delete('monitored_distances');
          await _upsertRows(txn, 'monitored_distances', backup['monitoredDistances']);
        }
        if (backup['strengthWorkouts'] != null) {
          await _upsertRows(txn, 'strength_workouts', backup['strengthWorkouts']);
        }
        if (backup['workoutBlocks'] != null) {
          await _upsertRows(txn, 'workout_blocks', backup['workoutBlocks']);
        }
        if (backup['blockExercises'] != null) {
          await _upsertRows(txn, 'block_exercises', backup['blockExercises']);
        }
        if (backup['strengthTemplates'] != null) {
          await _upsertRows(txn, 'strength_workout_templates', backup['strengthTemplates']);
        }
        if (backup['templateItems'] != null) {
          await _upsertRows(txn, 'template_items', backup['templateItems']);
        }
        if (backup['trainingEnrollments'] != null) {
          // Sem PK — replace não deduplica; limpa antes de inserir
          await txn.delete('user_training_enrollments');
          await _upsertRows(txn, 'user_training_enrollments', backup['trainingEnrollments']);
        }
      });

      // Remove a foto antiga se foi substituída por uma nova
      if (oldPhotoPath != null &&
          newPhotoPath != null &&
          oldPhotoPath != newPhotoPath) {
        try {
          final oldFile = File(oldPhotoPath);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (e) {
          debugPrint('Import: falha ao remover foto antiga: $e');
        }
      }

      return (true, restoredPhoto);
    } catch (e) {
      debugPrint('Import backup falhou: $e');
      return (false, false);
    }
  }

  Future<void> _upsertRows(Transaction txn, String table, List<dynamic> rows) async {
    for (final row in rows) {
      await txn.insert(
        table,
        Map<String, dynamic>.from(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Recria o arquivo de foto localmente a partir do base64 do backup.
  /// Retorna null se falhar — perfil é restaurado sem foto, sem quebrar.
  Future<String?> _restorePhotoFile(String base64Data) async {
    try {
      final bytes = base64Decode(base64Data);
      final appDir = await getApplicationDocumentsDirectory();
      final file = File(
        '${appDir.path}/profile_pic_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Falha ao restaurar foto do backup: $e');
      return null;
    }
  }

  // ---------- Auto backup ----------

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? false;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
  }

  /// Pede permissão para escrever em Downloads. Retorna true se concedida.
  /// Em Android 11+ precisa de MANAGE_EXTERNAL_STORAGE (tela especial).
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    if (await Permission.manageExternalStorage.isGranted) return true;

    final result = await Permission.manageExternalStorage.request();
    return result.isGranted;
  }

  /// Diretório alvo para backup automático: /storage/emulated/0/Download/RunLab
  Directory _autoBackupDirectory() {
    return Directory('/storage/emulated/0/Download/$_autoBackupFolderName');
  }

  String get autoBackupFolderPath =>
      '/Download/$_autoBackupFolderName';

  /// Executa backup automático se toggle ativo + permissão concedida.
  /// Retorna true se salvou; false se pulou ou falhou silenciosamente.
  Future<bool> runAutoBackupIfEnabled() async {
    if (!await isAutoBackupEnabled()) return false;
    if (!Platform.isAndroid) return false;

    if (!await Permission.manageExternalStorage.isGranted) {
      debugPrint('Auto backup: sem permissão de storage, pulando.');
      return false;
    }

    try {
      final dir = _autoBackupDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final (jsonString, _) = await _buildBackupJson();

      // 1) Arquivo "latest" sempre sobrescrito — ponto de restauração rápida.
      final latestFile = File('${dir.path}/$_autoBackupLatestFile');
      await latestFile.writeAsString(jsonString);

      // 2) Snapshot timestamped — margem contra corrupção do latest.
      final now = DateTime.now();
      final timestamp =
          '${now.year}${_pad(now.month)}${_pad(now.day)}_'
          '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
      final snapshotFile = File('${dir.path}/runlab_backup_$timestamp.json');
      await snapshotFile.writeAsString(jsonString);

      // 3) Rolling buffer: mantém só os N mais recentes timestamped.
      await _pruneOldBackups(dir);

      return true;
    } catch (e) {
      debugPrint('Auto backup falhou: $e');
      return false;
    }
  }

  Future<void> _pruneOldBackups(Directory dir) async {
    final files = await dir
        .list()
        .where(
          (e) =>
              e is File &&
              e.path.contains('runlab_backup_') &&
              e.path.endsWith('.json'),
        )
        .cast<File>()
        .toList();

    if (files.length <= _maxTimestampedBackups) return;

    files.sort((a, b) => b.path.compareTo(a.path)); // mais recente primeiro
    for (var i = _maxTimestampedBackups; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (_) {
        // arquivo pode ter sumido entre listar e deletar; tudo bem.
      }
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
