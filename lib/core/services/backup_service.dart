import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/models/backup_status.dart';
import 'database_service.dart';

class BackupService {
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';
  static const int _maxExternalBackups = 5;
  static const int _maxInternalBackups = 3;
  static const String _autoBackupFolderName = 'RunLab';
  static const String _autoBackupLatestFile = 'runlab_auto_backup.json';
  static const String _internalBackupFolderName = 'backups';
  static const Duration _staleBackupAge = Duration(days: 7);

  static const String _lastBackupSuccessKey = 'auto_backup_last_success_at';
  static const String _lastBackupAttemptKey = 'auto_backup_last_attempt_at';
  static const String _lastBackupErrorKey = 'auto_backup_last_error';
  static const String _lastBackupCopiesKey = 'auto_backup_successful_copies';
  static const String _lastBackupAttemptCopiesKey =
      'auto_backup_attempted_copies';
  static const String _backupMonitoringSinceKey =
      'auto_backup_monitoring_since';
  static const String _lastStaleWarningKey = 'auto_backup_last_stale_warning';

  final DatabaseService _dbService;
  final Future<Directory> Function() _documentsDirectory;
  final Directory? _externalBackupDirectoryOverride;
  final bool Function() _isAndroid;
  final Future<bool> Function() _hasStoragePermission;
  final DateTime Function() _now;
  static Future<bool>? _backupInFlight;

  BackupService({
    DatabaseService? databaseService,
    Future<Directory> Function()? documentsDirectory,
    Directory? externalBackupDirectory,
    bool Function()? isAndroid,
    Future<bool> Function()? hasStoragePermission,
    DateTime Function()? now,
  }) : _dbService = databaseService ?? DatabaseService(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _externalBackupDirectoryOverride = externalBackupDirectory,
       _isAndroid = isAndroid ?? (() => Platform.isAndroid),
       _hasStoragePermission =
           hasStoragePermission ??
           (() async => Permission.manageExternalStorage.isGranted),
       _now = now ?? DateTime.now;

  /// Retorna (json, incluiuFoto).
  Future<(String, bool)> _buildBackupJson() async {
    final db = await _dbService.database;
    final profileData = await db.query('user_profile');
    final runsData = await db.query('runs');

    Map<String, dynamic>? profile = profileData.isNotEmpty
        ? Map<String, dynamic>.from(profileData.first)
        : null;

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
      subject: 'Backup RunLab - ${DateTime.now().day}/${DateTime.now().month}',
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
        if (backup['goalHistory'] != null) {
          await _upsertRows(txn, 'goal_history', backup['goalHistory']);
        }
        if (backup['monitoredDistances'] != null) {
          await txn.delete('monitored_distances');
          await _upsertRows(
            txn,
            'monitored_distances',
            backup['monitoredDistances'],
          );
        }
        if (backup['strengthWorkouts'] != null) {
          await _upsertRows(
            txn,
            'strength_workouts',
            backup['strengthWorkouts'],
          );
        }
        if (backup['workoutBlocks'] != null) {
          await _upsertRows(txn, 'workout_blocks', backup['workoutBlocks']);
        }
        if (backup['blockExercises'] != null) {
          await _upsertRows(txn, 'block_exercises', backup['blockExercises']);
        }
        if (backup['strengthTemplates'] != null) {
          await _upsertRows(
            txn,
            'strength_workout_templates',
            backup['strengthTemplates'],
          );
        }
        if (backup['templateItems'] != null) {
          await _upsertRows(txn, 'template_items', backup['templateItems']);
        }
        if (backup['trainingEnrollments'] != null) {
          // Sem PK — replace não deduplica; limpa antes de inserir
          await txn.delete('user_training_enrollments');
          await _upsertRows(
            txn,
            'user_training_enrollments',
            backup['trainingEnrollments'],
          );
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

  Future<void> _upsertRows(
    Transaction txn,
    String table,
    List<dynamic> rows,
  ) async {
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
    // Padrão ATIVO: instalação limpa (ou depois de restaurar um backup)
    // já nasce com auto-backup ligado; quem desligou mantém a escolha.
    return prefs.getBool(_autoBackupEnabledKey) ?? true;
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

  /// Diretório alvo para a cópia externa em Android.
  Directory _autoBackupDirectory() {
    return _externalBackupDirectoryOverride ??
        Directory('/storage/emulated/0/Download/$_autoBackupFolderName');
  }

  String get autoBackupFolderPath => '/Download/$_autoBackupFolderName';

  Future<Directory> _internalBackupDirectory() async {
    final documents = await _documentsDirectory();
    return Directory('${documents.path}/$_internalBackupFolderName');
  }

  /// Executa o backup automático quando o toggle está ativo.
  ///
  /// A cópia interna é independente de permissões e sempre tentada. No Android,
  /// a cópia externa é adicional quando "Acesso a todos os arquivos" foi
  /// concedido. Falha em um local não impede o outro; o retorno indica se ao
  /// menos uma cópia validada foi concluída.
  ///
  /// Chamadas concorrentes compartilham a mesma operação para evitar duas
  /// gravações disputando os mesmos arquivos.
  Future<bool> runAutoBackupIfEnabled() {
    return _backupInFlight ??= _runAutoBackup().whenComplete(() {
      _backupInFlight = null;
    });
  }

  Future<bool> _runAutoBackup() async {
    if (!await isAutoBackupEnabled()) return false;

    final now = _now();
    final prefs = await SharedPreferences.getInstance();
    await _ensureMonitoringStarted(prefs, now);

    final String jsonString;
    try {
      final backup = await _withRetry(_buildBackupJson);
      jsonString = backup.$1;
    } catch (error) {
      await _recordBackupOutcomeSafe(
        prefs: prefs,
        now: now,
        successful: false,
        successfulCopies: 0,
        attemptedCopies: 0,
        error: _cleanError(error),
      );
      return false;
    }

    final errors = <String>[];
    var attemptedCopies = 1;
    var successfulCopies = 0;

    final internalError = await _tryWriteLocation(
      name: 'cópia interna',
      directory: _internalBackupDirectory,
      jsonString: jsonString,
      now: now,
      maxSnapshots: _maxInternalBackups,
    );
    if (internalError == null) {
      successfulCopies++;
    } else {
      errors.add(internalError);
    }

    if (_isAndroid()) {
      var hasPermission = false;
      try {
        hasPermission = await _hasStoragePermission();
      } catch (error) {
        errors.add('permissão externa: ${_cleanError(error)}');
      }

      if (hasPermission) {
        attemptedCopies++;
        final externalError = await _tryWriteLocation(
          name: 'cópia externa',
          directory: () async => _autoBackupDirectory(),
          jsonString: jsonString,
          now: now,
          maxSnapshots: _maxExternalBackups,
        );
        if (externalError == null) {
          successfulCopies++;
        } else {
          errors.add(externalError);
        }
      }
    }

    final successful = successfulCopies > 0;
    await _recordBackupOutcomeSafe(
      prefs: prefs,
      now: now,
      successful: successful,
      successfulCopies: successfulCopies,
      attemptedCopies: attemptedCopies,
      error: errors.isEmpty ? null : errors.join(' | '),
    );
    return successful;
  }

  Future<String?> _tryWriteLocation({
    required String name,
    required Future<Directory> Function() directory,
    required String jsonString,
    required DateTime now,
    required int maxSnapshots,
  }) async {
    try {
      await _withRetry(() async {
        final dir = await directory();
        await _writeBackupSet(
          dir,
          jsonString: jsonString,
          now: now,
          maxSnapshots: maxSnapshots,
        );
      });
      return null;
    } catch (error) {
      return '$name: ${_cleanError(error)}';
    }
  }

  /// Grava `latest` + um snapshot, relendo e validando cada arquivo antes de
  /// considerá-lo pronto. Um arquivo temporário evita publicar JSON truncado.
  Future<void> _writeBackupSet(
    Directory dir, {
    required String jsonString,
    required DateTime now,
    required int maxSnapshots,
  }) async {
    await dir.create(recursive: true);

    final latestFile = File('${dir.path}/$_autoBackupLatestFile');
    final latestTemp = File('${latestFile.path}.tmp');
    await _writeValidatedFile(latestTemp, jsonString);
    await _replaceFile(latestTemp, latestFile);
    await _validateBackupFile(latestFile, jsonString);

    final timestamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}_'
        '${now.millisecond.toString().padLeft(3, '0')}';
    final snapshotFile = File('${dir.path}/runlab_backup_$timestamp.json');
    final snapshotTemp = File('${snapshotFile.path}.tmp');
    await _writeValidatedFile(snapshotTemp, jsonString);
    await _replaceFile(snapshotTemp, snapshotFile);
    await _validateBackupFile(snapshotFile, jsonString);

    await _pruneOldBackups(dir, maxSnapshots);
  }

  Future<void> _writeValidatedFile(File file, String jsonString) async {
    try {
      await file.writeAsString(jsonString, flush: true);
      await _validateBackupFile(file, jsonString);
    } catch (_) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // A próxima tentativa sobrescreve o temporário.
      }
      rethrow;
    }
  }

  Future<void> _validateBackupFile(File file, String expected) async {
    final content = await file.readAsString();
    if (content != expected) {
      throw const FormatException('Backup gravado difere do conteúdo original');
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> || decoded['version'] is! int) {
      throw const FormatException('Backup gravado é inválido');
    }
  }

  Future<void> _replaceFile(File source, File target) async {
    // No Windows, rename não substitui um destino existente de forma
    // consistente. O app roda em Android/iOS, mas os testes rodam no Windows.
    if (Platform.isWindows && await target.exists()) {
      await target.delete();
    }
    try {
      await source.rename(target.path);
    } on FileSystemException {
      // Fallback para plataformas que não substituem o destino no rename.
      if (!await target.exists()) rethrow;
      await target.delete();
      await source.rename(target.path);
    }
  }

  Future<void> _pruneOldBackups(Directory dir, int maxSnapshots) async {
    final files = await dir
        .list()
        .where((e) {
          if (e is! File) return false;
          final name = e.uri.pathSegments.last;
          return name.startsWith('runlab_backup_') && name.endsWith('.json');
        })
        .cast<File>()
        .toList();

    if (files.length <= maxSnapshots) return;

    files.sort((a, b) => b.path.compareTo(a.path));
    for (var i = maxSnapshots; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (_) {
        // Um backup a mais é preferível a falhar a operação por limpeza.
      }
    }
  }

  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await operation();
      } catch (_) {
        if (attempt >= 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// Status tipado do último backup, usado pelo Perfil.
  Future<BackupStatus> getBackupStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final now = _now();
    await _ensureMonitoringStarted(prefs, now);
    return _statusFromPrefs(prefs);
  }

  BackupStatus _statusFromPrefs(SharedPreferences prefs) {
    return BackupStatus(
      lastSuccessfulBackupAt: _readTimestamp(prefs, _lastBackupSuccessKey),
      lastAttemptAt: _readTimestamp(prefs, _lastBackupAttemptKey),
      lastError: prefs.getString(_lastBackupErrorKey),
      successfulCopies: prefs.getInt(_lastBackupCopiesKey) ?? 0,
      attemptedCopies: prefs.getInt(_lastBackupAttemptCopiesKey) ?? 0,
    );
  }

  /// Aviso único por dia quando não há backup concluído há mais de 7 dias.
  /// Sem sucesso anterior, a janela começa no primeiro monitoramento para não
  /// avisar um usuário novo antes mesmo da primeira corrida.
  Future<bool> shouldWarnStaleBackup({DateTime? now}) async {
    if (!await isAutoBackupEnabled()) return false;

    final effectiveNow = now ?? _now();
    final prefs = await SharedPreferences.getInstance();
    await _ensureMonitoringStarted(prefs, effectiveNow);

    final lastSuccess = _readTimestamp(prefs, _lastBackupSuccessKey);
    final monitoringSince = _readTimestamp(prefs, _backupMonitoringSinceKey)!;
    final reference = lastSuccess ?? monitoringSince;
    if (effectiveNow.difference(reference) < _staleBackupAge) return false;

    final lastWarning = _readTimestamp(prefs, _lastStaleWarningKey);
    return lastWarning == null || !_isSameDay(lastWarning, effectiveNow);
  }

  Future<void> markStaleBackupWarningShown([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastStaleWarningKey,
      (now ?? _now()).millisecondsSinceEpoch,
    );
  }

  Future<void> _ensureMonitoringStarted(
    SharedPreferences prefs,
    DateTime now,
  ) async {
    if (prefs.getInt(_backupMonitoringSinceKey) != null) return;
    await prefs.setInt(_backupMonitoringSinceKey, now.millisecondsSinceEpoch);
  }

  Future<void> _recordBackupOutcome({
    required SharedPreferences prefs,
    required DateTime now,
    required bool successful,
    required int successfulCopies,
    required int attemptedCopies,
    required Object? error,
  }) async {
    await prefs.setInt(_lastBackupAttemptKey, now.millisecondsSinceEpoch);
    await prefs.setInt(_lastBackupAttemptCopiesKey, attemptedCopies);
    await prefs.setInt(_lastBackupCopiesKey, successfulCopies);
    if (successful) {
      await prefs.setInt(_lastBackupSuccessKey, now.millisecondsSinceEpoch);
    }
    if (error == null) {
      await prefs.remove(_lastBackupErrorKey);
    } else {
      await prefs.setString(_lastBackupErrorKey, _cleanError(error));
    }
  }

  Future<void> _recordBackupOutcomeSafe({
    required SharedPreferences prefs,
    required DateTime now,
    required bool successful,
    required int successfulCopies,
    required int attemptedCopies,
    required String? error,
  }) async {
    try {
      await _recordBackupOutcome(
        prefs: prefs,
        now: now,
        successful: successful,
        successfulCopies: successfulCopies,
        attemptedCopies: attemptedCopies,
        error: error,
      );
    } catch (e) {
      // O arquivo já foi salvo; falha ao registrar metadados não deve virar
      // falsa falha de backup para quem dispara a operação.
      debugPrint('Auto backup: falha ao registrar status: $e');
    }
  }

  DateTime? _readTimestamp(SharedPreferences prefs, String key) {
    final milliseconds = prefs.getInt(key);
    if (milliseconds == null || milliseconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _cleanError(Object error) {
    final message = error.toString().replaceAll('\n', ' ').trim();
    return message.length <= 400 ? message : '${message.substring(0, 397)}...';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
