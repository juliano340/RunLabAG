import '../models/performance_alert.dart';
import 'package:runlabag/core/domain/models/weekly_evolution_stats.dart';

class PerformanceAlertService {
  static List<PerformanceAlert> analyze({
    required List<WeeklyEvolutionStats> evolution,
  }) {
    final alerts = <PerformanceAlert>[];

    // Semana em andamento não entra na análise: período parcial contra
    // período completo gera queda de performance "fantasma".
    final now = DateTime.now();
    final complete =
        evolution.where((e) => !e.endDate.isAfter(now)).toList();

    if (complete.length >= 4) {
      _detectPlateau(complete, alerts);
    }

    if (complete.length >= 2) {
      _detectPerformanceDrop(complete, alerts);
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
