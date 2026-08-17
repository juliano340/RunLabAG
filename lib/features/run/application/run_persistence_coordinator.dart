import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/achievement_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/database_service.dart' show DatabaseService;
import '../../history/domain/models/run_model.dart';
import '../../history/domain/models/run_split.dart';
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
  final DatabaseService _dbService;
  final AchievementService _achievementService;
  final BackupService _backupService;
  final AnalyticsService _analyticsService;

  RunPersistenceCoordinator({
    DatabaseService? dbService,
    AchievementService? achievementService,
    BackupService? backupService,
    AnalyticsService? analyticsService,
  }) : _dbService = dbService ?? DatabaseService(),
       _achievementService = achievementService ?? AchievementService(),
       _backupService = backupService ?? BackupService(),
       _analyticsService = analyticsService ?? AnalyticsService();

  Future<RunPersistenceResult> saveCompletedRun({
    DateTime? startTime,
    required double distanceKm,
    required int durationSeconds,
    required int pausedDurationSeconds,
    required String pace,
    required int calories,
    required List<List<LatLng>> route,
    required String type,
    required String mood,
    required List<RunSplit> splits,
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
      type: type,
      mood: mood,
      splits: splits,
    );

    await _dbService.saveRun(run);
    await _dbService.clearActiveRun();

    unawaited(_backupService.runAutoBackupIfEnabled());

    await _analyticsService.logRunCompleted(
      distanceKm: run.distanceKm,
      durationSeconds: run.durationSeconds,
      pace: run.pace,
      calories: run.calories,
      runType: run.type,
      mood: run.mood,
    );

    final trainingService = TrainingService(_dbService);
    final isPlanSuccessful = await trainingService.matchRunToPlan(run);

    final newAwards = await _achievementService.checkAwards(run);
    for (final award in newAwards) {
      _analyticsService.logAchievementUnlocked(achievementId: award['id']);
    }

    return RunPersistenceResult(
      run: run,
      isPlanSuccessful: isPlanSuccessful,
      newAwards: newAwards,
    );
  }
}
