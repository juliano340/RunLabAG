import '../models/performance_alert.dart';
import '../../../dashboard/domain/models/weekly_evolution_stats.dart';
import '../../../history/domain/models/run_model.dart';

class PerformanceAlertService {
  static List<PerformanceAlert> analyze({
    required List<RunModel> recentRuns,
    required List<WeeklyEvolutionStats> evolution,
    required Map<String, dynamic> personalRecords,
  }) {
    final alerts = <PerformanceAlert>[];

    if (evolution.length >= 4) {
      _detectPlateau(evolution, alerts);
    }

    if (recentRuns.isNotEmpty && personalRecords.isNotEmpty) {
      _detectNewRecords(recentRuns, personalRecords, alerts);
    }

    if (evolution.length >= 2) {
      _detectPerformanceDrop(evolution, alerts);
    }

    return alerts;
  }

  static void _detectPlateau(
    List<WeeklyEvolutionStats> evolution,
    List<PerformanceAlert> alerts,
  ) {
    final recent = evolution.sublist(0, 4);
    final paces = recent.map((e) => e.paceRaw).where((p) => p > 0).toList();

    if (paces.length < 4) return;

    final avg = paces.reduce((a, b) => a + b) / paces.length;
    final variance = paces.map((p) => (p - avg) * (p - avg)).reduce((a, b) => a + b) / paces.length;
    final cv = variance > 0 ? (variance / (avg * avg)) : 0;

    if (cv < 0.002) {
      alerts.add(PerformanceAlert.plateau(
        weeks: 4,
        suggestion: 'Tente treinos intervalados ou hill repeats para quebrar o platô.',
      ));
    }
  }

  static void _detectNewRecords(
    List<RunModel> recentRuns,
    Map<String, dynamic> personalRecords,
    List<PerformanceAlert> alerts,
  ) {
    final bests = personalRecords['bests'] as Map<String, dynamic>? ?? {};

    for (var run in recentRuns) {
      for (var entry in bests.entries) {
        final record = entry.value as Map<String, dynamic>?;
        if (record == null) continue;

        final recordDate = record['date'] as DateTime?;
        if (recordDate == null) continue;

        final runDay = DateTime(run.date.year, run.date.month, run.date.day);
        final recordDay = DateTime(recordDate.year, recordDate.month, recordDate.day);

        if (runDay.isAtSameMomentAs(recordDay)) {
          final time = record['time'] as double?;
          if (time == null || time <= 0) continue;

          final distance = entry.key;
          int timeMinutes = (time / 60).toInt();
          int timeSeconds = (time % 60).toInt();
          final timeStr = '$timeMinutes:${timeSeconds.toString().padLeft(2, '0')}';

          alerts.add(PerformanceAlert.newRecord(
            distance: distance,
            time: timeStr,
            improvement: 0.02,
          ));
        }
      }
    }
  }

  static void _detectPerformanceDrop(
    List<WeeklyEvolutionStats> evolution,
    List<PerformanceAlert> alerts,
  ) {
    final current = evolution[0];
    final previous = evolution[1];

    if (current.paceRaw <= 0 || previous.paceRaw <= 0) return;

    final paceChange = (current.paceRaw - previous.paceRaw) / previous.paceRaw;

    if (paceChange > 0.10) {
      final pct = (paceChange * 100).toInt();
      alerts.add(PerformanceAlert.drop(
        percentage: pct,
        suggestion: 'Considere mais descanso ou verifique se há sinais de lesão.',
      ));
    }
  }
}
