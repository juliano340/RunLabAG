import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../../features/run/data/repositories/active_run_repository.dart';
import '../../features/history/data/repositories/run_repository.dart';
import '../../features/profile/data/repositories/user_repository.dart';
import '../../features/training/data/models/training_plan.dart';
import '../../features/strength_training/domain/models/strength_workout.dart';
import '../../features/strength_training/domain/models/workout_block.dart';
import '../../features/dashboard/domain/models/weekly_evolution_stats.dart';
import '../../features/history/domain/models/run_model.dart';
import '../../features/history/domain/models/run_split.dart';
import '../../features/profile/domain/models/user_profile.dart';

export '../../features/history/domain/models/run_model.dart';
export '../../features/history/domain/models/run_split.dart';
export '../../features/profile/domain/models/user_profile.dart';

class DatabaseService {
  Future<Database> get database => DatabaseHelper.database;

  final _activeRunRepo = ActiveRunRepository();
  final _runRepo = RunRepository();
  final _userRepo = UserRepository();

  // Active Run Persistence (for recovery)
  Future<void> saveActiveRun(Map<String, dynamic> data) => _activeRunRepo.saveActiveRun(data);
  Future<Map<String, dynamic>?> getActiveRun() => _activeRunRepo.getActiveRun();
  Future<void> clearActiveRun() => _activeRunRepo.clearActiveRun();

  // --- Run CRUD ---
  Future<void> saveRun(RunModel run) => _runRepo.saveRun(run);
  Future<List<RunModel>> getRuns() => _runRepo.getRuns();
  Future<List<RunModel>> getRunsBetween(DateTime start, DateTime end) => _runRepo.getRunsBetween(start, end);
  Future<RunModel?> getLastRun() => _runRepo.getLastRun();
  Future<void> deleteRun(String id) => _runRepo.deleteRun(id);

  // --- User Profile ---
  Future<void> saveUserProfile(UserProfile profile) => _userRepo.saveUserProfile(profile);
  Future<UserProfile?> getUserProfile() => _userRepo.getUserProfile();

  // --- Goal History ---
  Future<void> saveGoalHistory(String periodId, String goalType, double goalValue) async {
    final db = await database;
    await db.insert('goal_history', {
      'periodId': periodId,
      'goalType': goalType,
      'goalValue': goalValue,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<double?> getGoalHistory(String periodId, String goalType) async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'goal_history',
      where: 'periodId = ? AND goalType = ?',
      whereArgs: [periodId, goalType],
    );
    if (maps.isNotEmpty) {
      return (maps.first['goalValue'] as num).toDouble();
    }
    return null;
  }

  // Achievement Methods
  Future<void> saveAchievement(String id, String title, String desc, int iconCode) async {
    final db = await database;
    await db.insert(
      'achievements',
      {
        'id': id,
        'title': title,
        'description': desc,
        'iconCode': iconCode,
        'earnedDate': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getEarnedAchievements() async {
    final db = await database;
    return await db.query('achievements');
  }

  Future<Map<String, dynamic>?> getLastAchievement() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('achievements', orderBy: 'earnedDate DESC', limit: 1);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  // --- Evolution Analysis ---
  Future<List<WeeklyEvolutionStats>> getWeeklyEvolution(int numberOfWeeks) async {
    List<WeeklyEvolutionStats> evolution = [];
    final now = DateTime.now();
    final startOfCurrentWeek = now.subtract(Duration(days: now.weekday % 7));
    
    for (int i = 0; i < numberOfWeeks; i++) {
      final start = DateTime(startOfCurrentWeek.year, startOfCurrentWeek.month, startOfCurrentWeek.day)
          .subtract(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      
      final runs = await getRunsBetween(start, end);
      final periodId = _getWeekPeriodId(start);
      
      double totalDist = 0;
      int totalSeconds = 0;
      for (var r in runs) {
        totalDist += r.distanceKm;
        totalSeconds += r.durationSeconds;
      }
      
      double? goal = await getGoalHistory(periodId, 'weekly');
      if (goal == null && i == 0) {
        final profile = await getUserProfile();
        goal = profile?.weeklyGoal ?? 20.0;
      }
      
      evolution.add(WeeklyEvolutionStats(
        periodId: periodId,
        startDate: start,
        endDate: end,
        totalDistance: totalDist,
        totalDurationSeconds: totalSeconds,
        goalDistance: goal ?? 20.0,
        runCount: runs.length,
      ));
    }
    return evolution;
  }

  String _getWeekPeriodId(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday % 7));
    final dayOfYear = startOfWeek.difference(DateTime(startOfWeek.year, 1, 1)).inDays;
    final weekNum = (dayOfYear / 7).floor() + 1;
    return '${startOfWeek.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final runs = await getRuns();
    double totalDistance = 0;
    int totalRuns = runs.length;
    int totalSeconds = 0;
    int totalCalories = 0;

    for (final run in runs) {
      totalDistance += run.distanceKm;
      totalSeconds += run.durationSeconds.toInt();
      totalCalories += run.calories.toInt();
    }

    String avgPace = '0:00';
    if (totalDistance > 0) {
      double paceInMinutes = (totalSeconds / 60) / totalDistance;
      int minutes = paceInMinutes.toInt();
      int seconds = ((paceInMinutes - minutes) * 60).toInt();
      avgPace = '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    return {
      'totalDistance': totalDistance.toStringAsFixed(1),
      'totalRuns': totalRuns.toString(),
      'avgPace': avgPace,
      'totalCalories': totalCalories >= 1000 
          ? '${(totalCalories / 1000).toStringAsFixed(1)}k' 
          : totalCalories.toString(),
    };
  }

  // Monitored Distances Management
  Future<List<double>> getMonitoredDistances() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('monitored_distances', orderBy: 'distanceKm ASC');
    return List.generate(maps.length, (i) => maps[i]['distanceKm'] as double);
  }

  Future<void> addMonitoredDistance(double distance) async {
    final db = await database;
    await db.insert('monitored_distances', {'distanceKm': distance}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeMonitoredDistance(double distance) async {
    final db = await database;
    await db.delete('monitored_distances', where: 'distanceKm = ?', whereArgs: [distance]);
  }

  Future<Map<String, dynamic>> getPersonalRecords() async {
    final runs = await getRuns();
    final monitored = await getMonitoredDistances();
    
    Map<String, Map<String, dynamic>> records = {};
    for (double dist in monitored) {
      String key = dist == 21.0975 ? '21km' : dist == 42.195 ? '42km' : '${dist.toStringAsFixed(dist == dist.toInt() ? 0 : 1)}km';
      records[key] = {'time': null, 'date': null, 'runId': null};
    }

    double longestDistance = 0;
    DateTime? longestDistanceDate;
    String? longestDistanceRunId;

    for (final run in runs) {
      // Logic for all-time bests for specific distances
      for (double targetDist in monitored) {
        // Tolerância de 1% (ex: 4.95km conta como 5k para RP)
        final double toleranceFactor = 0.99;
        
        if (run.distanceKm >= targetDist * toleranceFactor) {
          // 1. Initial estimation based on average pace
          // Se o treino for muito próximo da meta (ex: 5.0003km para 5k), usamos o tempo total direto
          double bestTimeInRun;
          String currentInterval;

          if ((run.distanceKm - targetDist).abs() / targetDist < 0.005) {
            // Extremamente próximo (menos de 0.5% de diferença): usar o tempo real do treino
            bestTimeInRun = run.durationSeconds.toDouble();
            currentInterval = "Tempo Total";
          } else {
            bestTimeInRun = (run.durationSeconds / run.distanceKm) * targetDist;
            currentInterval = "Média do Treino";
          }
          
          // 2. If we have splits, they are much more accurate for integer distances
          if (run.splits.isNotEmpty) {
            final int tDistInt = targetDist.round();
            // Check if it's very close to an integer (to handle 5.0, 10.0, etc.)
            if ((targetDist - tDistInt).abs() < 0.001) {
              // Se tivermos splits suficientes para cobrir a distância inteira
              if (run.splits.length >= tDistInt) {
                // Find fastest consecutive sequence of splits
                for (int i = 0; i <= run.splits.length - tDistInt; i++) {
                  int sequenceTime = 0;
                  for (int j = 0; j < tDistInt; j++) {
                    sequenceTime += run.splits[i + j].timeSeconds;
                  }
                  
                  // Se o segmento for mais rápido que a média/tempo total, ele vence
                  if (sequenceTime < bestTimeInRun) {
                    bestTimeInRun = sequenceTime.toDouble();
                    currentInterval = tDistInt == 1 ? "km ${i + 1}" : "km ${i + 1} a ${i + tDistInt}";
                  }
                }
              }
            }
          }
          
          String key = targetDist == 21.0975 ? '21km' : targetDist == 42.195 ? '42km' : '${targetDist.toStringAsFixed(targetDist == targetDist.toInt() ? 0 : 1)}km';

          // Atualiza se for o primeiro registro ou se este for mais rápido
          if (records[key]!['time'] == null || bestTimeInRun < (records[key]!['time'] as double)) {
            records[key] = {
              'time': bestTimeInRun,
              'date': run.date,
              'runId': run.id,
              'interval': currentInterval,
            };
          }
        }
      }

      // Logic for longest run
      if (run.distanceKm > longestDistance) {
        longestDistance = run.distanceKm;
        longestDistanceDate = run.date;
        longestDistanceRunId = run.id;
      }
    }

    return {
      'bests': records,
      'longestDistance': {
        'value': longestDistance,
        'date': longestDistanceDate,
        'runId': longestDistanceRunId,
      },
    };
  }

  Future<List<Map<String, dynamic>>> getRecordHistory(String category) async {
    final runs = await getRuns();
    // Sort by date ascending to track evolution
    final sortedRuns = runs.reversed.toList();
    
    double targetDist = 0;
    if (category.endsWith('km')) {
      targetDist = double.tryParse(category.replaceAll('km', '')) ?? 0;
      if (category == '21km') targetDist = 21.0975;
      if (category == '42km') targetDist = 42.195;
    }

    if (targetDist == 0) return [];

    List<Map<String, dynamic>> history = [];
    double? currentBest;

    for (final run in sortedRuns) {
      final double toleranceFactor = 0.99;
      if (run.distanceKm >= targetDist * toleranceFactor) {
        // 1. Initial estimation based on average pace
        double bestTimeInRun;
        String currentInterval;

        if ((run.distanceKm - targetDist).abs() / targetDist < 0.005) {
          bestTimeInRun = run.durationSeconds.toDouble();
          currentInterval = "Tempo Total";
        } else {
          bestTimeInRun = (run.durationSeconds / run.distanceKm) * targetDist;
          currentInterval = "Média do Treino";
        }
        
        // 2. Accurate calculation if splits are present
        if (run.splits.isNotEmpty) {
          final int tDistInt = targetDist.round();
          if ((targetDist - tDistInt).abs() < 0.001) {
            if (run.splits.length >= tDistInt) {
              for (int i = 0; i <= run.splits.length - tDistInt; i++) {
                int sequenceTime = 0;
                for (int j = 0; j < tDistInt; j++) {
                  sequenceTime += run.splits[i + j].timeSeconds;
                }
                if (sequenceTime < bestTimeInRun) {
                  bestTimeInRun = sequenceTime.toDouble();
                  currentInterval = tDistInt == 1 ? "km ${i + 1}" : "km ${i + 1} a ${i + tDistInt}";
                }
              }
            }
          }
        }

        if (currentBest == null || bestTimeInRun < currentBest) {
          double improvement = 0;
          if (currentBest != null) {
            improvement = currentBest - bestTimeInRun;
          }
          
          history.add({
            'time': bestTimeInRun,
            'date': run.date,
            'improvement': improvement,
            'runId': run.id,
            'interval': currentInterval,
          });
          currentBest = bestTimeInRun;
        }
      }
    }

    // Return descending (newest first) for UI
    return history.reversed.toList();
  }

  Future<List<Map<String, dynamic>>> getLongestDistanceHistory() async {
    final runs = await getRuns();
    // Sort by date ascending to track evolution
    final sortedRuns = runs.reversed.toList();
    
    List<Map<String, dynamic>> history = [];
    double currentMax = 0;

    for (final run in sortedRuns) {
      if (run.distanceKm > currentMax) {
        double improvement = 0;
        if (currentMax > 0) {
          improvement = run.distanceKm - currentMax;
        }
        
        currentMax = run.distanceKm;
        history.add({
          'value': run.distanceKm,
          'date': run.date,
          'runId': run.id,
          'improvement': improvement,
        });
      }
    }

    return history.reversed.toList();
  }

  Future<List<double>> getWeeklyProgress() async {
    final now = DateTime.now();
    // Encontrar o último domingo (ou hoje se for domingo)
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    final List<double> dailyDistances = List.filled(7, 0.0);

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'runs',
      where: 'date >= ?',
      whereArgs: [startDate.toIso8601String()],
    );

    for (final map in maps) {
      final date = DateTime.parse(map['date']);
      // Diferença em dias a partir da segunda-feira
      final dayIndex = date.difference(startDate).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        dailyDistances[dayIndex] += map['distanceKm'] as double;
      }
    }

    return dailyDistances;
  }

  // Water Intake Methods
  Future<void> saveWaterIntake(int amount) async {
    final db = await database;
    await db.insert(
      'water_intake',
      {
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getDailyWaterIntake() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    
    return await db.query(
      'water_intake',
      where: 'timestamp >= ?',
      whereArgs: [today],
      orderBy: 'timestamp DESC',
    );
  }

  Future<int> getTotalDailyWaterIntake() async {
    final logs = await getDailyWaterIntake();
    return logs.fold<int>(0, (sum, log) => sum + (log['amount'] as int));
  }

  Future<void> deleteWaterIntake(int id) async {
    final db = await database;
    await db.delete('water_intake', where: 'id = ?', whereArgs: [id]);
  }

  // --- Training Plans Methods ---

  Future<void> saveTrainingPlan(TrainingPlan plan) async {
    final db = await database;
    await db.insert('training_plans', plan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> savePlanSession(PlanSession session) async {
    final db = await database;
    await db.insert('plan_sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TrainingPlan>> getTrainingPlans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('training_plans');
    return List.generate(maps.length, (i) => TrainingPlan.fromMap(maps[i]));
  }

  Future<List<PlanSession>> getPlanSessions(String planId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'plan_sessions',
      where: 'planId = ?',
      whereArgs: [planId],
      orderBy: 'week ASC, day ASC',
    );
    return List.generate(maps.length, (i) => PlanSession.fromMap(maps[i]));
  }

  Future<void> saveEnrollment(UserPlanEnrollment enrollment) async {
    final db = await database;
    // We only support one active plan for now, so deactivate others
    await db.update('user_training_enrollments', {'isActive': 0});
    await db.insert('user_training_enrollments', enrollment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserPlanEnrollment?> getActiveEnrollment() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_training_enrollments',
      where: 'isActive = 1',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UserPlanEnrollment.fromMap(maps.first);
  }

  Future<void> updateEnrollmentProgress(String planId, int week, int day) async {
    final db = await database;
    await db.update(
      'user_training_enrollments',
      {'currentWeek': week, 'currentDay': day},
      where: 'planId = ? AND isActive = 1',
      whereArgs: [planId],
    );
  }

  Future<void> deactivateActiveEnrollment() async {
    final db = await database;
    await db.update('user_training_enrollments', {'isActive': 0});
  }

  // --- Strength Training Management ---
  Future<void> saveStrengthWorkout(StrengthWorkout workout) async {
    final db = await database;
    await db.insert('strength_workouts', {
      'id': workout.id,
      'name': workout.name,
      'date': workout.date?.millisecondsSinceEpoch,
      'payload': workout.toJson(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StrengthWorkout>> getStrengthWorkouts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('strength_workouts', orderBy: 'date DESC');
    return maps.map((map) {
      final payload = map['payload'] as String;
      return StrengthWorkout.fromJson(payload);
    }).toList();
  }

  Future<void> deleteStrengthWorkout(String id) async {
    final db = await database;
    await db.delete('strength_workouts', where: 'id = ?', whereArgs: [id]);
  }
  
  // --- Exercise Dictionary ---
  Future<void> saveToDictionary(String id, String name, String muscleGroupId) async {
    final db = await database;
    await db.insert('exercise_dictionary', {
      'id': id,
      'name': name,
      'muscleGroupId': muscleGroupId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  
  Future<List<Map<String, dynamic>>> getExerciseDictionary(String muscleGroupId) async {
    final db = await database;
    return await db.query('exercise_dictionary', where: 'muscleGroupId = ?', whereArgs: [muscleGroupId]);
  }

  // --- Workout Blocks & Modular Templates ---

  Future<void> saveWorkoutBlock(WorkoutBlock block) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('strength_workout_templates', template.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('template_items', where: 'templateId = ?', whereArgs: [template.id]);
      for (var item in template.items) {
        await txn.insert('template_items', item.toMap(template.id));
      }
    });
  }

  Future<List<StrengthWorkoutTemplate>> getWorkoutTemplates() async {
    final db = await database;
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
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('workout_blocks', where: 'id = ?', whereArgs: [id]);
      await txn.delete('block_exercises', where: 'blockId = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteWorkoutTemplate(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('strength_workout_templates', where: 'id = ?', whereArgs: [id]);
      await txn.delete('template_items', where: 'templateId = ?', whereArgs: [id]);
    });
  }
}
