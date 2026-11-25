import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'package:runlabag/core/domain/services/pace_zone_service.dart';
import '../data/repositories/active_run_repository.dart';
import '../data/repositories/achievement_repository.dart';
import '../data/repositories/run_repository.dart';
import '../data/repositories/stats_repository.dart';
import '../data/repositories/user_data_reset_repository.dart';
import '../data/repositories/user_repository.dart';
import '../domain/repositories/active_run_repository.dart';
import '../domain/repositories/achievement_repository.dart';
import '../domain/repositories/run_repository.dart';
import '../domain/repositories/stats_repository.dart';
import '../domain/repositories/user_data_reset_repository.dart';
import '../domain/repositories/user_repository.dart';
import 'package:runlabag/core/domain/models/training_plan.dart';
import 'package:runlabag/core/domain/models/strength_workout.dart';
import 'package:runlabag/core/domain/models/workout_block.dart';
import 'package:runlabag/core/domain/models/weekly_evolution_stats.dart';
import 'package:runlabag/core/domain/models/monthly_evolution_stats.dart';
import 'package:runlabag/core/domain/models/consistency_stats.dart';
import 'package:runlabag/core/domain/models/earned_achievement.dart';
import 'package:runlabag/core/domain/models/personal_records.dart';
import 'package:runlabag/core/domain/models/record_history_entry.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';
import 'package:runlabag/core/domain/models/user_stats.dart';
import 'package:runlabag/core/domain/models/user_totals.dart';

/// Fachada de dados do app: CRUD de treinos, treino ativo, perfil,
/// conquistas, metas, planos e força — apoiada em repositórios por
/// domínio. `DatabaseService` continua como compatibilidade, mas as
/// dependências podem ser injetadas pelo composition root.
class DatabaseService {
  final ActiveRunRepository _activeRunRepo;
  final RunRepository _runRepo;
  final UserRepository _userRepo;
  final AchievementRepository _achievementRepo;
  final UserDataResetRepository _resetRepo;
  late final StatsRepository _statsRepo;

  DatabaseService({
    ActiveRunRepository? activeRunRepository,
    RunRepository? runRepository,
    UserRepository? userRepository,
    StatsRepository? statsRepository,
    AchievementRepository? achievementRepository,
    UserDataResetRepository? resetRepository,
  }) : _activeRunRepo = activeRunRepository ?? SqfliteActiveRunRepository(),
       _runRepo = runRepository ?? SqfliteRunRepository(),
       _userRepo = userRepository ?? SqfliteUserRepository(),
       _achievementRepo = achievementRepository ?? SqfliteAchievementRepository(),
       _resetRepo = resetRepository ?? SqfliteUserDataResetRepository() {
    _statsRepo =
        statsRepository ??
        SqfliteStatsRepository(
          runRepository: _runRepo,
          userRepository: _userRepo,
        );
  }

  // Active Run Persistence (for recovery)
  Future<void> saveActiveRun(Map<String, dynamic> data) => _activeRunRepo.saveActiveRunMeta(data);
  Future<void> saveActiveRunMeta(Map<String, dynamic> data) => _activeRunRepo.saveActiveRunMeta(data);
  Future<void> saveActiveRunRoute(String routeJson) => _activeRunRepo.saveActiveRunRoute(routeJson);
  Future<Map<String, dynamic>?> getActiveRun() => _activeRunRepo.getActiveRun();
  Future<Map<String, dynamic>?> getActiveRunMeta() => _activeRunRepo.getActiveRunMeta();
  Future<void> clearActiveRun() => _activeRunRepo.clearActiveRun();

  // --- Run CRUD ---
  Future<void> saveRun(RunModel run) => _runRepo.saveRun(run);
  /// Treinos **sem rota** — use em listas, totais, gráficos e recordes.
  Future<List<RunModel>> getRunSummaries() => _runRepo.getSummaries();
  Future<List<RunModel>> getRunSummariesBetween(DateTime start, DateTime end) =>
      _runRepo.getSummariesBetween(start, end);
  Future<RunModel?> getRunById(String id) => _runRepo.getById(id);
  Future<RunModel?> getLastRun() => _runRepo.getLastRunSummary();
  Future<void> deleteRun(String id) => _runRepo.deleteRun(id);

  // --- Pace zones (pré-calculadas por treino) ---
  Future<void> savePaceZones(String runId, Map<String, double> distanceByZone) =>
      _runRepo.savePaceZones(runId, distanceByZone);
  Future<Map<String, double>> getPaceZoneTotals(DateTime start, DateTime end) =>
      _runRepo.getPaceZoneTotals(start, end);

  /// Calcula as faixas de ritmo que faltam, um treino por vez.
  ///
  /// Roda em segundo plano depois do primeiro frame. Cada iteração carrega a
  /// rota de um único treino, então o custo é limitado mesmo com histórico
  /// grande. Retorna quantos treinos foram processados.
  Future<int> backfillPaceZones({int batchSize = 12}) async {
    var processed = 0;
    final pending = await _runRepo.getRunsMissingPaceZones(limit: batchSize);
    for (final row in pending) {
      final run = RunModel.fromMap({
        'id': row['id'],
        'date': DateTime.now().toIso8601String(),
        'distanceKm': row['distanceKm'],
        'durationSeconds': row['durationSeconds'],
        'pace': '0:00',
        'calories': 0,
        'route': row['route'],
        'splits': row['splits'],
      });
      final result = PaceZoneService.analyze(
        route: run.route,
        routeTimes: run.routeTimes,
        distanceKm: run.distanceKm,
        durationSeconds: run.durationSeconds,
        splits: run.splits,
      );
      await _runRepo.savePaceZones(
        row['id'] as String,
        {for (final e in result.distanceByZoneKm.entries) e.key.name: e.value},
      );
      processed++;
    }
    return processed;
  }

  // --- User Profile ---
  Future<void> saveUserProfile(UserProfile profile) => _userRepo.saveUserProfile(profile);
  Future<UserProfile?> getUserProfile() => _userRepo.getUserProfile();

  // --- Reset ---
  Future<void> resetAllData() => _resetRepo.resetAllData();

  // --- Goal History (delegado ao StatsRepository) ---
  Future<void> saveGoalHistory(String periodId, String goalType, double goalValue) =>
      _statsRepo.saveGoalHistory(periodId, goalType, goalValue);

  Future<double?> getGoalHistory(String periodId, String goalType) =>
      _statsRepo.getGoalHistory(periodId, goalType);

  // Achievement Methods
  Future<void> saveAchievement(String id, String title, String desc, int iconCode) =>
      _achievementRepo.saveAchievement(
        id: id,
        title: title,
        description: desc,
        iconCode: iconCode,
      );

  Future<List<EarnedAchievement>> getEarnedAchievements() =>
      _achievementRepo.getEarnedAchievements();

  Future<EarnedAchievement?> getLastAchievement() =>
      _achievementRepo.getLastAchievement();

  // --- Evolution / estatísticas (delegado ao StatsRepository) ---
  Future<List<WeeklyEvolutionStats>> getWeeklyEvolution(int numberOfWeeks) =>
      _statsRepo.getWeeklyEvolution(numberOfWeeks);

  /// Totais agregados direto no SQLite — nenhum treino é carregado.
  Future<UserTotals> getTotals({DateTime? since}) =>
      _statsRepo.getTotals(since: since);

  Future<UserStats> getUserStats({DateTime? since}) =>
      _statsRepo.getUserStats(since: since);

  // Monitored Distances Management (delegado ao StatsRepository)
  Future<List<double>> getMonitoredDistances() =>
      _statsRepo.getMonitoredDistances();

  Future<void> addMonitoredDistance(double distance) =>
      _statsRepo.addMonitoredDistance(distance);

  Future<void> removeMonitoredDistance(double distance) =>
      _statsRepo.removeMonitoredDistance(distance);

  Future<PersonalRecordsSnapshot> getPersonalRecords() =>
      _statsRepo.getPersonalRecords();

  Future<List<RecordHistoryEntry>> getRecordHistory(double targetDistanceKm) =>
      _statsRepo.getRecordHistory(targetDistanceKm);

  Future<List<LongestDistanceHistoryEntry>> getLongestDistanceHistory() =>
      _statsRepo.getLongestDistanceHistory();

  Future<List<double>> getWeeklyProgress() => _statsRepo.getWeeklyProgress();

  // --- Training Plans Methods ---

  Future<void> saveTrainingPlan(TrainingPlan plan) async {
    final db = await DatabaseHelper.database;
    await db.insert('training_plans', plan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> savePlanSession(PlanSession session) async {
    final db = await DatabaseHelper.database;
    await db.insert('plan_sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TrainingPlan>> getTrainingPlans() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('training_plans');
    return List.generate(maps.length, (i) => TrainingPlan.fromMap(maps[i]));
  }

  Future<List<PlanSession>> getPlanSessions(String planId) async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'plan_sessions',
      where: 'planId = ?',
      whereArgs: [planId],
      orderBy: 'week ASC, day ASC',
    );
    return List.generate(maps.length, (i) => PlanSession.fromMap(maps[i]));
  }

  Future<void> saveEnrollment(UserPlanEnrollment enrollment) async {
    final db = await DatabaseHelper.database;
    // We only support one active plan for now, so deactivate others
    await db.update('user_training_enrollments', {'isActive': 0});
    await db.insert('user_training_enrollments', enrollment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserPlanEnrollment?> getActiveEnrollment() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_training_enrollments',
      where: 'isActive = 1',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserPlanEnrollment.fromMap(maps.first);
  }

  Future<void> updateEnrollmentProgress(String planId, int week, int day) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'user_training_enrollments',
      {'currentWeek': week, 'currentDay': day},
      where: 'planId = ? AND isActive = 1',
      whereArgs: [planId],
    );
  }

  Future<void> deactivateActiveEnrollment() async {
    final db = await DatabaseHelper.database;
    await db.update('user_training_enrollments', {'isActive': 0});
  }

  // --- Strength Training Management ---
  Future<void> saveStrengthWorkout(StrengthWorkout workout) async {
    final db = await DatabaseHelper.database;
    await db.insert('strength_workouts', {
      'id': workout.id,
      'name': workout.name,
      'date': workout.date?.millisecondsSinceEpoch,
      'payload': workout.toJson(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StrengthWorkout>> getStrengthWorkouts() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('strength_workouts', orderBy: 'date DESC');
    return maps.map((map) {
      final payload = map['payload'] as String;
      return StrengthWorkout.fromJson(payload);
    }).toList();
  }

  Future<void> deleteStrengthWorkout(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('strength_workouts', where: 'id = ?', whereArgs: [id]);
  }
  
  // --- Exercise Dictionary ---
  Future<void> saveToDictionary(String id, String name, String muscleGroupId) async {
    final db = await DatabaseHelper.database;
    await db.insert('exercise_dictionary', {
      'id': id,
      'name': name,
      'muscleGroupId': muscleGroupId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  
  Future<List<Map<String, dynamic>>> getExerciseDictionary(String muscleGroupId) async {
    final db = await DatabaseHelper.database;
    return await db.query('exercise_dictionary', where: 'muscleGroupId = ?', whereArgs: [muscleGroupId]);
  }

  // --- Workout Blocks & Modular Templates ---

  Future<void> saveWorkoutBlock(WorkoutBlock block) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert('workout_blocks', block.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      // Remove previous exercises to overwrite
      await txn.delete('block_exercises', where: 'blockId = ?', whereArgs: [block.id]);
      for (var exercise in block.exercises) {
        final map = exercise.toMap();
        map['blockId'] = block.id;
        await txn.insert('block_exercises', map);
      }
    });
  }

  Future<List<WorkoutBlock>> getWorkoutBlocks() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> blockMaps = await db.query('workout_blocks');
    List<WorkoutBlock> blocks = [];
    for (var map in blockMaps) {
      final List<Map<String, dynamic>> exerciseMaps = await db.query(
        'block_exercises',
        where: 'blockId = ?',
        whereArgs: [map['id']],
        orderBy: 'orderIndex ASC',
      );
      blocks.add(WorkoutBlock.fromMap(
        map,
        exercises: exerciseMaps.map((e) => BlockExercise.fromMap(e)).toList(),
      ));
    }
    return blocks;
  }

  Future<void> saveWorkoutTemplate(StrengthWorkoutTemplate template) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert('strength_workout_templates', template.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('template_items', where: 'templateId = ?', whereArgs: [template.id]);
      for (var item in template.items) {
        await txn.insert('template_items', item.toMap(template.id));
      }
    });
  }

  Future<List<StrengthWorkoutTemplate>> getWorkoutTemplates() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> templateMaps = await db.query('strength_workout_templates');
    List<StrengthWorkoutTemplate> templates = [];
    for (var map in templateMaps) {
      final List<Map<String, dynamic>> itemMaps = await db.query(
        'template_items',
        where: 'templateId = ?',
        whereArgs: [map['id']],
        orderBy: 'orderIndex ASC',
      );
      templates.add(StrengthWorkoutTemplate.fromMap(
        map,
        items: itemMaps.map((i) => TemplateItem.fromMap(i)).toList(),
      ));
    }
    return templates;
  }

  Future<void> deleteWorkoutBlock(String id) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.delete('workout_blocks', where: 'id = ?', whereArgs: [id]);
      await txn.delete('block_exercises', where: 'blockId = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteWorkoutTemplate(String id) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.delete('strength_workout_templates', where: 'id = ?', whereArgs: [id]);
      await txn.delete('template_items', where: 'templateId = ?', whereArgs: [id]);
    });
  }

  // --- Analytics (delegado ao StatsRepository) ---

  Future<List<MonthlyEvolutionStats>> getMonthlyEvolution(int numberOfMonths) =>
      _statsRepo.getMonthlyEvolution(numberOfMonths);

  Future<Map<String, int>> getRunsByTypeBetween(DateTime start, DateTime end) =>
      _statsRepo.getRunsByTypeBetween(start, end);

  Future<ConsistencyStats> getConsistencyStats(DateTime since) =>
      _statsRepo.getConsistencyStats(since);

  Future<Map<String, dynamic>> getPerformanceTrend(int weeks) =>
      _statsRepo.getPerformanceTrend(weeks);

  Future<Map<String, dynamic>> comparePeriods(
    DateTime start1, DateTime end1,
    DateTime start2, DateTime end2,
  ) => _statsRepo.comparePeriods(start1, end1, start2, end2);
}
