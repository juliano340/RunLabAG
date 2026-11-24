import 'package:sqflite/sqflite.dart';
import '../../domain/models/consistency_stats.dart';
import '../../domain/models/monthly_evolution_stats.dart';
import '../../domain/models/personal_records.dart';
import '../../domain/models/record_history_entry.dart';
import '../../domain/models/run_model.dart';
import '../../domain/models/user_stats.dart';
import '../../domain/models/user_totals.dart';
import '../../domain/models/weekly_evolution_stats.dart';
import '../../services/database_helper.dart';
import '../../domain/repositories/run_repository.dart';
import '../../domain/repositories/stats_repository.dart';
import '../../domain/repositories/user_repository.dart';

/// Consultas agregadas: totais, evolução semanal/mensal, recordes,
/// consistência, distâncias monitoradas e comparativos de período.
///
/// Lê treinos **sem a coluna route** (via [RunRepository.getSummaries] /
/// [getSummariesBetween]) — nenhuma consulta desta classe precisa do mapa,
/// então o payload grande nunca entra na memória por aqui.
class SqfliteStatsRepository implements StatsRepository {
  final RunRepository _runRepo;
  final UserRepository _userRepo;

  SqfliteStatsRepository({
    required RunRepository runRepository,
    required UserRepository userRepository,
  }) : _runRepo = runRepository,
       _userRepo = userRepository;

  // --- Histórico de metas -------------------------------------------------

  @override
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

  @override
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

  Future<Map<String, double>> _getGoalHistoryMap(
    Iterable<String> periodIds,
    String goalType,
  ) async {
    final ids = periodIds.toSet().toList();
    if (ids.isEmpty) return {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final db = await DatabaseHelper.database;
    final rows = await db.query(
      'goal_history',
      columns: ['periodId', 'goalValue'],
      where: 'periodId IN ($placeholders) AND goalType = ?',
      whereArgs: [...ids, goalType],
    );
    return {
      for (final row in rows)
        row['periodId'] as String: (row['goalValue'] as num).toDouble(),
    };
  }

  // --- Evolução semanal ---------------------------------------------------

  /// Evolução semanal sem consultas N+1 de metas (uma busca em lote).
  @override
  Future<List<WeeklyEvolutionStats>> getWeeklyEvolution(
    int numberOfWeeks,
  ) async {
    if (numberOfWeeks <= 0) return [];

    final now = DateTime.now();
    final currentWeekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday % 7));
    final oldestStart = currentWeekStart.subtract(
      Duration(days: 7 * (numberOfWeeks - 1)),
    );

    final runs = await _runRepo.getSummariesBetween(oldestStart, now);
    final profile = await _userRepo.getUserProfile();
    final periodIds = [
      for (var i = 0; i < numberOfWeeks; i++)
        _getWeekPeriodId(currentWeekStart.subtract(Duration(days: 7 * i))),
    ];
    final goals = await _getGoalHistoryMap(periodIds, 'weekly');

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

      double? goal = goals[periodId];
      if (goal == null && i == 0) {
        goal = profile?.weeklyGoal ?? 20.0;
      }

      evolution.add(
        WeeklyEvolutionStats(
          periodId: periodId,
          startDate: start,
          endDate: end.subtract(const Duration(seconds: 1)),
          totalDistance: totalDist,
          totalDurationSeconds: totalSeconds,
          goalDistance: goal ?? 20.0,
          runCount: runCount,
        ),
      );
    }
    return evolution;
  }

  String _getWeekPeriodId(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday % 7));
    final dayOfYear = startOfWeek
        .difference(DateTime(startOfWeek.year, 1, 1))
        .inDays;
    final weekNum = (dayOfYear / 7).floor() + 1;
    return '${startOfWeek.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  // --- Totais -------------------------------------------------------------

  /// Totais agregados direto no SQLite — nenhum treino é carregado.
  /// [since] filtra por data (string ISO, mesma convenção de getWeeklyProgress).
  @override
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

  @override
  Future<UserStats> getUserStats({DateTime? since}) async {
    final totals = await getTotals(since: since);
    final averagePaceSecondsPerKm = totals.totalDistanceKm > 0
        ? totals.totalSeconds / totals.totalDistanceKm
        : 0.0;
    return UserStats(
      totals: totals,
      averagePaceSecondsPerKm: averagePaceSecondsPerKm,
    );
  }

  // --- Distâncias monitoradas (recordes) ---------------------------------

  @override
  Future<List<double>> getMonitoredDistances() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'monitored_distances',
      orderBy: 'distanceKm ASC',
    );
    return List.generate(maps.length, (i) => maps[i]['distanceKm'] as double);
  }

  @override
  Future<void> addMonitoredDistance(double distance) async {
    final db = await DatabaseHelper.database;
    await db.insert('monitored_distances', {
      'distanceKm': distance,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> removeMonitoredDistance(double distance) async {
    final db = await DatabaseHelper.database;
    await db.delete(
      'monitored_distances',
      where: 'distanceKm = ?',
      whereArgs: [distance],
    );
  }

  // --- Recordes -----------------------------------------------------------

  @override
  Future<PersonalRecordsSnapshot> getPersonalRecords() async {
    final runs = await _runRepo.getSummaries();
    final monitored = await getMonitoredDistances();
    final records = <double, PersonalRecord>{
      for (final distance in monitored)
        distance: PersonalRecord(
          targetDistanceKm: distance,
          timeSeconds: null,
          date: null,
          runId: null,
          interval: null,
        ),
    };

    var longestDistance = 0.0;
    DateTime? longestDistanceDate;
    String? longestDistanceRunId;

    for (final run in runs) {
      for (final targetDistance in monitored) {
        final best = _bestTimeForTarget(run, targetDistance);
        if (best == null) continue;

        final current = records[targetDistance]!;
        if (current.timeSeconds == null ||
            best.timeSeconds < current.timeSeconds!) {
          records[targetDistance] = PersonalRecord(
            targetDistanceKm: targetDistance,
            timeSeconds: best.timeSeconds,
            date: run.date,
            runId: run.id,
            interval: best.interval,
          );
        }
      }

      if (run.distanceKm > longestDistance) {
        longestDistance = run.distanceKm;
        longestDistanceDate = run.date;
        longestDistanceRunId = run.id;
      }
    }

    return PersonalRecordsSnapshot(
      bests: [for (final distance in monitored) records[distance]!],
      longestDistance: LongestDistanceRecord(
        distanceKm: longestDistance,
        date: longestDistanceDate,
        runId: longestDistanceRunId,
      ),
    );
  }

  @override
  Future<List<RecordHistoryEntry>> getRecordHistory(
    double targetDistanceKm,
  ) async {
    if (targetDistanceKm <= 0) return [];
    final runs = await _runRepo.getSummaries();
    final sortedRuns = runs.reversed.toList();
    final history = <RecordHistoryEntry>[];
    double? currentBest;

    for (final run in sortedRuns) {
      final best = _bestTimeForTarget(run, targetDistanceKm);
      if (best == null) continue;
      if (currentBest == null || best.timeSeconds < currentBest) {
        history.add(
          RecordHistoryEntry(
            timeSeconds: best.timeSeconds,
            date: run.date,
            improvementSeconds: currentBest == null
                ? 0
                : currentBest - best.timeSeconds,
            runId: run.id,
            interval: best.interval,
          ),
        );
        currentBest = best.timeSeconds;
      }
    }

    return history.reversed.toList();
  }

  @override
  Future<List<LongestDistanceHistoryEntry>> getLongestDistanceHistory() async {
    final runs = await _runRepo.getSummaries();
    final sortedRuns = runs.reversed.toList();
    final history = <LongestDistanceHistoryEntry>[];
    var currentMax = 0.0;

    for (final run in sortedRuns) {
      if (run.distanceKm > currentMax) {
        history.add(
          LongestDistanceHistoryEntry(
            distanceKm: run.distanceKm,
            date: run.date,
            runId: run.id,
            improvementKm: currentMax > 0 ? run.distanceKm - currentMax : 0,
          ),
        );
        currentMax = run.distanceKm;
      }
    }

    return history.reversed.toList();
  }

  /// Preserva as regras de recorde: tolerância de 1%, tempo total para metas
  /// quase exatas e melhor sequência consecutiva de splits.
  ({double timeSeconds, String interval})? _bestTimeForTarget(
    RunModel run,
    double targetDistanceKm,
  ) {
    if (run.durationSeconds <= 0 || run.distanceKm <= 0) return null;
    if (run.distanceKm < targetDistanceKm * 0.99) return null;

    double bestTime;
    String interval;
    if ((run.distanceKm - targetDistanceKm).abs() / targetDistanceKm < 0.005) {
      bestTime = run.durationSeconds.toDouble();
      interval = 'Tempo Total';
    } else {
      bestTime = (run.durationSeconds / run.distanceKm) * targetDistanceKm;
      interval = 'Média do Treino';
    }

    final targetInteger = targetDistanceKm.round();
    if ((targetDistanceKm - targetInteger).abs() < 0.001 &&
        run.splits.length >= targetInteger) {
      for (var i = 0; i <= run.splits.length - targetInteger; i++) {
        var sequenceTime = 0;
        for (var j = 0; j < targetInteger; j++) {
          sequenceTime += run.splits[i + j].timeSeconds;
        }
        if (sequenceTime < bestTime) {
          bestTime = sequenceTime.toDouble();
          interval = targetInteger == 1
              ? 'km ${i + 1}'
              : 'km ${i + 1} a ${i + targetInteger}';
        }
      }
    }

    return (timeSeconds: bestTime, interval: interval);
  }

  @override
  Future<List<double>> getWeeklyProgress() async {
    final now = DateTime.now();
    // Encontrar o último domingo (ou hoje se for domingo)
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final startDate = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    final List<double> dailyDistances = List.filled(7, 0.0);

    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'runs',
      columns: ['date', 'distanceKm'],
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

  @override
  Future<List<MonthlyEvolutionStats>> getMonthlyEvolution(
    int numberOfMonths,
  ) async {
    if (numberOfMonths <= 0) return [];

    final now = DateTime.now();
    final oldestStart = DateTime(now.year, now.month - (numberOfMonths - 1), 1);

    final runs = await _runRepo.getSummariesBetween(oldestStart, now);
    final profile = await _userRepo.getUserProfile();
    final periodIds = [
      for (var i = 0; i < numberOfMonths; i++)
        '${DateTime(now.year, now.month - i, 1).year}-'
            '${DateTime(now.year, now.month - i, 1).month.toString().padLeft(2, '0')}',
    ];
    final goals = await _getGoalHistoryMap(periodIds, 'monthly');

    final evolution = <MonthlyEvolutionStats>[];
    for (int i = 0; i < numberOfMonths; i++) {
      final start = DateTime(now.year, now.month - i, 1);
      final end = (i == 0)
          ? now.add(const Duration(seconds: 1))
          : DateTime(now.year, now.month - i + 1, 1);
      final periodId =
          '${start.year}-${start.month.toString().padLeft(2, '0')}';

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

      double? goal = goals[periodId];
      if (goal == null && i == 0) {
        goal = profile?.monthlyGoal ?? 80.0;
      }

      evolution.add(
        MonthlyEvolutionStats(
          periodId: periodId,
          startDate: start,
          endDate: end.subtract(const Duration(seconds: 1)),
          totalDistance: totalDist,
          totalDurationSeconds: totalSeconds,
          goalDistance: goal ?? 80.0,
          runCount: runCount,
          totalCalories: totalCal,
          runsByType: runsByType,
        ),
      );
    }
    return evolution;
  }

  @override
  Future<Map<String, int>> getRunsByTypeBetween(
    DateTime start,
    DateTime end,
  ) async {
    final runs = await _runRepo.getSummariesBetween(start, end);
    Map<String, int> result = {};
    for (var r in runs) {
      final type = r.type.isNotEmpty ? r.type : 'Corrida';
      result[type] = (result[type] ?? 0) + 1;
    }
    return result;
  }

  @override
  Future<ConsistencyStats> getConsistencyStats(DateTime since) async {
    final now = DateTime.now();
    final runs = await _runRepo.getSummariesBetween(since, now);

    final Set<String> trainedDays = {};
    for (var r in runs) {
      final day = DateTime(r.date.year, r.date.month, r.date.day);
      trainedDays.add(day.toIso8601String());
    }

    final totalDays = now.difference(since).inDays + 1;
    final taxaFrequencia = totalDays > 0 ? trainedDays.length / totalDays : 0.0;

    int currentStreak = 0;
    int bestStreak = 0;
    int tempStreak = 0;
    DateTime? lastRunDate;

    final sortedRuns = List<RunModel>.from(runs)
      ..sort((a, b) => a.date.compareTo(b.date));

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

    final today = now;
    final todayStr = DateTime(
      today.year,
      today.month,
      today.day,
    ).toIso8601String();
    final lastRunStr = lastRunDate != null
        ? DateTime(
            lastRunDate.year,
            lastRunDate.month,
            lastRunDate.day,
          ).toIso8601String()
        : '';
    final trainedToday = lastRunStr == todayStr;

    currentStreak = trainedToday ? tempStreak : 0;
    if (!trainedToday && lastRunDate != null) {
      final diff = DateTime(today.year, today.month, today.day)
          .difference(
            DateTime(lastRunDate.year, lastRunDate.month, lastRunDate.day),
          )
          .inDays;
      if (diff > 1) currentStreak = 0;
    }

    return ConsistencyStats(
      trainedDays: trainedDays.length,
      totalDays: totalDays,
      frequencyRate: taxaFrequencia,
      currentStreak: currentStreak,
      bestStreak: bestStreak > currentStreak ? bestStreak : currentStreak,
    );
  }

  @override
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
      final variance =
          recentPaces
              .map((p) => (p - avg) * (p - avg))
              .reduce((a, b) => a + b) /
          recentPaces.length;
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

  @override
  Future<Map<String, dynamic>> comparePeriods(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
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
      'period1': {
        'distance': dist1,
        'runs': runs1.length,
        'pace': pace1,
        'calories': cal1,
        'seconds': sec1,
      },
      'period2': {
        'distance': dist2,
        'runs': runs2.length,
        'pace': pace2,
        'calories': cal2,
        'seconds': sec2,
      },
      'deltaDistance': dist1 - dist2,
      'deltaRuns': runs1.length - runs2.length,
      'deltaPace': pace1 - pace2,
      'deltaCalories': cal1 - cal2,
    };
  }
}
