import 'package:sqflite/sqflite.dart';
import '../../domain/models/monthly_evolution_stats.dart';
import '../../domain/models/run_model.dart';
import '../../domain/models/weekly_evolution_stats.dart';
import '../../services/database_helper.dart';
import 'run_repository.dart';
import 'user_repository.dart';

/// Totais agregados da carreira do usuário (calculados em SQL).
class UserTotals {
  final int runCount;
  final double totalDistanceKm;
  final int totalSeconds;
  final int totalCalories;

  const UserTotals({
    required this.runCount,
    required this.totalDistanceKm,
    required this.totalSeconds,
    required this.totalCalories,
  });

  static const empty = UserTotals(
    runCount: 0,
    totalDistanceKm: 0,
    totalSeconds: 0,
    totalCalories: 0,
  );
}

/// Consultas agregadas: totais, evolução semanal/mensal, recordes,
/// consistência, distâncias monitoradas e comparativos de período.
///
/// Lê treinos **sem a coluna route** (via [RunRepository.getSummaries] /
/// [getSummariesBetween]) — nenhuma consulta desta classe precisa do mapa,
/// então o payload grande nunca entra na memória por aqui.
class StatsRepository {
  final _runRepo = RunRepository();
  final _userRepo = UserRepository();

  // --- Histórico de metas -------------------------------------------------

  Future<void> saveGoalHistory(
    String periodId,
    String goalType,
    double goalValue,
  ) async {
    final db = await DatabaseHelper.database;
    await db.insert('goal_history', {
      'periodId': periodId,
      'goalType': goalType,
      'goalValue': goalValue,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<double?> getGoalHistory(String periodId, String goalType) async {
    final db = await DatabaseHelper.database;
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

  // --- Evolução semanal ---------------------------------------------------

  /// Evolução semanal em **uma única consulta** ao banco (sem a coluna route).
  Future<List<WeeklyEvolutionStats>> getWeeklyEvolution(int numberOfWeeks) async {
    if (numberOfWeeks <= 0) return [];

    final now = DateTime.now();
    final currentWeekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday % 7));
    final oldestStart =
        currentWeekStart.subtract(Duration(days: 7 * (numberOfWeeks - 1)));

    final runs = await _runRepo.getSummariesBetween(oldestStart, now);
    final profile = await _userRepo.getUserProfile();

    final evolution = <WeeklyEvolutionStats>[];
    for (int i = 0; i < numberOfWeeks; i++) {
      final start = currentWeekStart.subtract(Duration(days: 7 * i));
      final end = start.add(const Duration(days: 7));
      final periodId = _getWeekPeriodId(start);

      double totalDist = 0;
      int totalSeconds = 0;
      int runCount = 0;
      for (final r in runs) {
        if (!r.date.isBefore(start) && r.date.isBefore(end)) {
          totalDist += r.distanceKm;
          totalSeconds += r.durationSeconds;
          runCount++;
        }
      }

      double? goal = await getGoalHistory(periodId, 'weekly');
      if (goal == null && i == 0) {
        goal = profile?.weeklyGoal ?? 20.0;
      }

      evolution.add(WeeklyEvolutionStats(
        periodId: periodId,
        startDate: start,
        endDate: end.subtract(const Duration(seconds: 1)),
        totalDistance: totalDist,
        totalDurationSeconds: totalSeconds,
        goalDistance: goal ?? 20.0,
        runCount: runCount,
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

  // --- Totais -------------------------------------------------------------

  /// Totais agregados direto no SQLite — nenhum treino é carregado.
  /// [since] filtra por data (string ISO, mesma convenção de getWeeklyProgress).
  Future<UserTotals> getTotals({DateTime? since}) async {
    final db = await DatabaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c, COALESCE(SUM(distanceKm), 0) AS d, '
      'COALESCE(SUM(durationSeconds), 0) AS s, '
      'COALESCE(SUM(calories), 0) AS k FROM runs'
      '${since != null ? ' WHERE date >= ?' : ''}',
      since != null ? [since.toIso8601String()] : null,
    );
    if (rows.isEmpty) return UserTotals.empty;
    final row = rows.first;
    return UserTotals(
      runCount: (row['c'] as num?)?.toInt() ?? 0,
      totalDistanceKm: (row['d'] as num?)?.toDouble() ?? 0,
      totalSeconds: (row['s'] as num?)?.toInt() ?? 0,
      totalCalories: (row['k'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, dynamic>> getUserStats({DateTime? since}) async {
    final totals = await getTotals(since: since);
    final totalDistance = totals.totalDistanceKm;
    final totalRuns = totals.runCount;
    final totalSeconds = totals.totalSeconds;
    final totalCalories = totals.totalCalories;

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

  // --- Distâncias monitoradas (recordes) ---------------------------------

  Future<List<double>> getMonitoredDistances() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps =
        await db.query('monitored_distances', orderBy: 'distanceKm ASC');
    return List.generate(maps.length, (i) => maps[i]['distanceKm'] as double);
  }

  Future<void> addMonitoredDistance(double distance) async {
    final db = await DatabaseHelper.database;
    await db.insert('monitored_distances', {'distanceKm': distance},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeMonitoredDistance(double distance) async {
    final db = await DatabaseHelper.database;
    await db.delete('monitored_distances',
        where: 'distanceKm = ?', whereArgs: [distance]);
  }

  // --- Recordes -----------------------------------------------------------

  Future<Map<String, dynamic>> getPersonalRecords() async {
    final runs = await _runRepo.getSummaries();
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
        // Treino sem duração não disputa recorde de tempo: com
        // durationSeconds = 0, "10km em 00:00" venceria tudo injustamente.
        if (run.durationSeconds <= 0) continue;
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
    final runs = await _runRepo.getSummaries();
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
    final runs = await _runRepo.getSummaries();
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

    final db = await DatabaseHelper.database;
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

  // --- Analíticos ---------------------------------------------------------

  Future<List<MonthlyEvolutionStats>> getMonthlyEvolution(int numberOfMonths) async {
    if (numberOfMonths <= 0) return [];

    final now = DateTime.now();
    final oldestStart = DateTime(now.year, now.month - (numberOfMonths - 1), 1);

    final runs = await _runRepo.getSummariesBetween(oldestStart, now);
    final profile = await _userRepo.getUserProfile();

    final evolution = <MonthlyEvolutionStats>[];
    for (int i = 0; i < numberOfMonths; i++) {
      final start = DateTime(now.year, now.month - i, 1);
      final end = (i == 0)
          ? now.add(const Duration(seconds: 1))
          : DateTime(now.year, now.month - i + 1, 1);
      final periodId = '${start.year}-${start.month.toString().padLeft(2, '0')}';

      double totalDist = 0;
      int totalSeconds = 0;
      int totalCal = 0;
      int runCount = 0;
      final Map<String, int> runsByType = {};

      for (final r in runs) {
        if (r.date.isBefore(start) || !r.date.isBefore(end)) continue;
        totalDist += r.distanceKm;
        totalSeconds += r.durationSeconds;
        totalCal += r.calories;
        runCount++;
        final type = r.type.isNotEmpty ? r.type : 'Corrida';
        runsByType[type] = (runsByType[type] ?? 0) + 1;
      }

      double? goal = await getGoalHistory(periodId, 'monthly');
      if (goal == null && i == 0) {
        goal = profile?.monthlyGoal ?? 80.0;
      }

      evolution.add(MonthlyEvolutionStats(
        periodId: periodId,
        startDate: start,
        endDate: end.subtract(const Duration(seconds: 1)),
        totalDistance: totalDist,
        totalDurationSeconds: totalSeconds,
        goalDistance: goal ?? 80.0,
        runCount: runCount,
        totalCalories: totalCal,
        runsByType: runsByType,
      ));
    }
    return evolution;
  }

  Future<Map<String, int>> getRunsByTypeBetween(DateTime start, DateTime end) async {
    final runs = await _runRepo.getSummariesBetween(start, end);
    Map<String, int> result = {};
    for (var r in runs) {
      final type = r.type.isNotEmpty ? r.type : 'Corrida';
      result[type] = (result[type] ?? 0) + 1;
    }
    return result;
  }

  Future<Map<String, dynamic>> getConsistencyStats(DateTime since) async {
    final runs = await _runRepo.getSummariesBetween(since, DateTime.now());

    final Set<String> trainedDays = {};
    for (var r in runs) {
      final day = DateTime(r.date.year, r.date.month, r.date.day);
      trainedDays.add(day.toIso8601String());
    }

    final totalDays = DateTime.now().difference(since).inDays + 1;
    final taxaFrequencia = totalDays > 0 ? trainedDays.length / totalDays : 0.0;

    int currentStreak = 0;
    int bestStreak = 0;
    int tempStreak = 0;
    DateTime? lastRunDate;

    final sortedRuns = List<RunModel>.from(runs)..sort((a, b) => a.date.compareTo(b.date));

    for (var r in sortedRuns) {
      final day = DateTime(r.date.year, r.date.month, r.date.day);
      if (lastRunDate != null) {
        final diff = day.difference(lastRunDate).inDays;
        if (diff == 1) {
          tempStreak++;
        } else if (diff > 1) {
          if (tempStreak > bestStreak) bestStreak = tempStreak;
          tempStreak = 1;
        }
      } else {
        tempStreak = 1;
      }
      lastRunDate = day;
    }
    if (tempStreak > bestStreak) bestStreak = tempStreak;

    final today = DateTime.now();
    final todayStr = DateTime(today.year, today.month, today.day).toIso8601String();
    final lastRunStr = lastRunDate != null
        ? DateTime(lastRunDate.year, lastRunDate.month, lastRunDate.day).toIso8601String()
        : '';
    final trainedToday = lastRunStr == todayStr;

    currentStreak = trainedToday ? tempStreak : 0;
    if (!trainedToday && lastRunDate != null) {
      final diff = DateTime(today.year, today.month, today.day)
          .difference(DateTime(lastRunDate.year, lastRunDate.month, lastRunDate.day))
          .inDays;
      if (diff > 1) currentStreak = 0;
    }

    return {
      'trainedDays': trainedDays.length,
      'totalDays': totalDays,
      'taxaFrequencia': taxaFrequencia,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak > currentStreak ? bestStreak : currentStreak,
    };
  }

  Future<Map<String, dynamic>> getPerformanceTrend(int weeks) async {
    final evolution = await getWeeklyEvolution(weeks);
    if (evolution.length < 3) {
      return {
        'isPlateau': false,
        'paceTrend': 0.0,
        'distanceTrend': 0.0,
        'slope': 0.0,
      };
    }

    final paces = evolution.map((e) => e.paceRaw).toList();
    final distances = evolution.map((e) => e.totalDistance).toList();

    final paceSlope = _calculateSlope(paces);
    final distanceSlope = _calculateSlope(distances);

    bool isPlateau = false;
    if (paces.length >= 4) {
      final recentPaces = paces.sublist(paces.length - 4);
      final avg = recentPaces.reduce((a, b) => a + b) / recentPaces.length;
      final variance = recentPaces.map((p) => (p - avg) * (p - avg)).reduce((a, b) => a + b) / recentPaces.length;
      final cv = variance > 0 ? (variance / (avg * avg)) : 0;
      isPlateau = cv < 0.002;
    }

    return {
      'isPlateau': isPlateau,
      'paceTrend': paceSlope,
      'distanceTrend': distanceSlope,
      'slope': paceSlope,
    };
  }

  double _calculateSlope(List<double> values) {
    if (values.length < 2) return 0.0;
    int n = values.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }
    double denominator = (n * sumX2 - sumX * sumX);
    if (denominator == 0) return 0.0;
    return (n * sumXY - sumX * sumY) / denominator;
  }

  Future<Map<String, dynamic>> comparePeriods(
    DateTime start1, DateTime end1,
    DateTime start2, DateTime end2,
  ) async {
    final runs1 = await _runRepo.getSummariesBetween(start1, end1);
    final runs2 = await _runRepo.getSummariesBetween(start2, end2);

    double dist1 = 0, dist2 = 0;
    int sec1 = 0, sec2 = 0;
    int cal1 = 0, cal2 = 0;

    for (var r in runs1) {
      dist1 += r.distanceKm;
      sec1 += r.durationSeconds;
      cal1 += r.calories;
    }
    for (var r in runs2) {
      dist2 += r.distanceKm;
      sec2 += r.durationSeconds;
      cal2 += r.calories;
    }

    double pace1 = dist1 > 0 ? (sec1 / 60) / dist1 : 0;
    double pace2 = dist2 > 0 ? (sec2 / 60) / dist2 : 0;

    return {
      'period1': {'distance': dist1, 'runs': runs1.length, 'pace': pace1, 'calories': cal1, 'seconds': sec1},
      'period2': {'distance': dist2, 'runs': runs2.length, 'pace': pace2, 'calories': cal2, 'seconds': sec2},
      'deltaDistance': dist1 - dist2,
      'deltaRuns': runs1.length - runs2.length,
      'deltaPace': pace1 - pace2,
      'deltaCalories': cal1 - cal2,
    };
  }
}
