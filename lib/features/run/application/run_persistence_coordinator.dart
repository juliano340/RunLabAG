import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/data/repositories/sqflite_run_completion_store.dart';
import '../../../core/domain/repositories/run_completion_store.dart';
import '../../../core/services/achievement_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/backup_service.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/run_split.dart';
import 'package:runlabag/core/domain/models/auto_pause_event.dart';
import 'package:runlabag/core/domain/services/pace_zone_service.dart';
import '../../training/services/training_service.dart';

class RunPersistenceResult {
  final RunModel run;
  final bool isPlanSuccessful;
  final List<Map<String, dynamic>> newAwards;

  const RunPersistenceResult({
    required this.run,
    required this.isPlanSuccessful,
    required this.newAwards,
  });
}

class RunPersistenceCoordinator {
  final AchievementService _achievementService;
  final BackupService _backupService;
  final AnalyticsService _analyticsService;
  final RunCompletionStore _completionStore;
  final TrainingService? _trainingService;
  final VoidCallback? _onRunCommitted;

  RunPersistenceCoordinator({
    AchievementService? achievementService,
    BackupService? backupService,
    AnalyticsService? analyticsService,
    RunCompletionStore? completionStore,
    TrainingService? trainingService,
    VoidCallback? onRunCommitted,
  }) : _achievementService = achievementService ?? AchievementService(),
       _backupService = backupService ?? BackupService(),
       _analyticsService = analyticsService ?? AnalyticsService(),
       _completionStore = completionStore ?? SqfliteRunCompletionStore(),
       _trainingService = trainingService,
       _onRunCommitted = onRunCommitted;

  Future<RunPersistenceResult> saveCompletedRun({
    DateTime? startTime,
    required double distanceKm,
    required int durationSeconds,
    required int pausedDurationSeconds,
    required String pace,
    required int calories,
    required List<List<LatLng>> route,
    List<List<int>> routeTimes = const [],
    required String type,
    required String mood,
    required List<RunSplit> splits,
    List<AutoPauseEvent> autoPauses = const [],
  }) async {
    final run = RunModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: startTime ?? DateTime.now(),
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      pausedDurationSeconds: pausedDurationSeconds,
      pace: pace,
      calories: calories,
      route: route,
      routeTimes: routeTimes,
      type: type,
      mood: mood,
      splits: splits,
      autoPauses: autoPauses,
    );

    final distanceByZone = <String, double>{};
    try {
      final paceZones = PaceZoneService.analyze(
        route: run.route,
        routeTimes: run.routeTimes,
        distanceKm: run.distanceKm,
        durationSeconds: run.durationSeconds,
        splits: run.splits,
      );
      distanceByZone.addAll({
        for (final entry in paceZones.distanceByZoneKm.entries)
          entry.key.name: entry.value,
      });
    } catch (e) {
      debugPrint('Falha ao calcular faixas de ritmo: $e');
    }

    // Commit atômico: ou o treino e seus derivados ficam prontos e o rascunho
    // é removido, ou nada muda.
    await _completionStore.saveCompletedRun(
      run: run,
      distanceByZone: distanceByZone,
    );
    try {
      _onRunCommitted?.call();
    } catch (e) {
      debugPrint('Falha ao invalidar cache após confirmar treino: $e');
    }

    // Tudo abaixo é pós-commit. Falha aqui não pode transformar um treino
    // confirmado em "não foi possível salvar" para o usuário.
    unawaited(
      _backupService.runAutoBackupIfEnabled().catchError((Object error) {
        debugPrint('Falha no backup após salvar treino: $error');
        return false;
      }),
    );

    try {
      await _analyticsService.logRunCompleted(
        distanceKm: run.distanceKm,
        durationSeconds: run.durationSeconds,
        pace: run.pace,
        calories: run.calories,
        runType: run.type,
        mood: run.mood,
      );
    } catch (e) {
      debugPrint('Falha no analytics após salvar treino: $e');
    }

    var isPlanSuccessful = false;
    final trainingService = _trainingService;
    if (trainingService != null) {
      try {
        isPlanSuccessful = await trainingService.matchRunToPlan(run);
      } catch (e) {
        debugPrint('Falha ao vincular treino ao plano: $e');
      }
    }

    var newAwards = <Map<String, dynamic>>[];
    try {
      newAwards = await _achievementService.checkAwards(run);
      for (final award in newAwards) {
        try {
          await _analyticsService.logAchievementUnlocked(
            achievementId: award['id'],
          );
        } catch (e) {
          debugPrint('Falha no analytics da conquista: $e');
        }
      }
    } catch (e) {
      debugPrint('Falha ao verificar conquistas: $e');
    }

    return RunPersistenceResult(
      run: run,
      isPlanSuccessful: isPlanSuccessful,
      newAwards: newAwards,
    );
  }
}
