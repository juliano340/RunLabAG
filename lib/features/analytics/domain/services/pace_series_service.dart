import 'dart:math' as math;

import 'package:runlabag/core/domain/models/weekly_evolution_stats.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/monthly_evolution_stats.dart';
import '../models/pace_series_point.dart';

/// Resumo numérico de uma série de treinos, usado no topo dos gráficos.
class TrendSummary {
  const TrendSummary({
    this.currentPace,
    this.currentLabel,
    this.averagePace,
    this.bestPace,
    this.bestLabel,
    this.paceDelta,
    this.totalDistanceKm = 0,
    this.totalRuns = 0,
    this.activePeriods = 0,
  });

  /// Pace do período mais recente que teve treino.
  final double? currentPace;
  final String? currentLabel;

  /// Pace médio ponderado (tempo total / distância total) dos períodos com treino.
  final double? averagePace;

  /// Melhor pace (menor) da janela analisada.
  final double? bestPace;
  final String? bestLabel;

  /// Diferença de pace entre os 3 períodos mais recentes e os 3 anteriores.
  /// Negativo = ficou mais rápido.
  final double? paceDelta;

  final double totalDistanceKm;
  final int totalRuns;
  final int activePeriods;

  bool get hasData => activePeriods > 0;
  bool get isImproving => paceDelta != null && paceDelta! < -0.01;
  bool get isDeclining => paceDelta != null && paceDelta! > 0.01;
}

/// Constrói séries cronológicas (mais antigo → mais recente) e resume os números.
///
/// O banco devolve os períodos do mais recente para o mais antigo; inverter aqui
/// é o que garante que o eixo X dos gráficos leia da esquerda (passado) para a
/// direita (presente), como qualquer pessoa espera.
class PaceSeriesService {
  const PaceSeriesService._();

  static List<PaceSeriesPoint> fromWeekly(List<WeeklyEvolutionStats> stats) {
    return stats.map(PaceSeriesPoint.fromWeekly).toList().reversed.toList();
  }

  static List<PaceSeriesPoint> fromMonthly(List<MonthlyEvolutionStats> stats) {
    return stats.map(PaceSeriesPoint.fromMonthly).toList().reversed.toList();
  }

  /// Dias da semana corrente (domingo → sábado), um ponto por dia.
  /// O agrupamento é por dia de calendário; [runs] deve estar dentro da janela.
  static List<PaceSeriesPoint> fromDays({
    required List<RunModel> runs,
    required DateTime startOfWeek,
    double goalKm = 0,
  }) {
    final start =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final points = <PaceSeriesPoint>[];

    for (var i = 0; i < 7; i++) {
      final dayStart = start.add(Duration(days: i));
      final dayEnd =
          DateTime(dayStart.year, dayStart.month, dayStart.day, 23, 59, 59);

      var distance = 0.0;
      var seconds = 0;
      var count = 0;
      for (final run in runs) {
        if (!run.date.isBefore(dayStart) &&
            run.date.isBefore(dayEnd.add(const Duration(seconds: 1)))) {
          distance += run.distanceKm;
          seconds += run.durationSeconds;
          count++;
        }
      }

      points.add(PaceSeriesPoint(
        periodId:
            '${dayStart.year}-${dayStart.month.toString().padLeft(2, '0')}-'
            '${dayStart.day.toString().padLeft(2, '0')}',
        type: TrendPeriodType.day,
        startDate: dayStart,
        endDate: dayEnd,
        distanceKm: distance,
        durationSeconds: seconds,
        runCount: count,
        goalKm: goalKm,
      ));
    }

    return points; // já em ordem cronológica
  }

  /// Agrupa meses em trimestres. Recebe os meses do mais recente para o mais
  /// antigo (ordem do banco) e devolve no máximo [count] trimestres em ordem
  /// cronológica.
  static List<PaceSeriesPoint> quarters(
    List<MonthlyEvolutionStats> stats, {
    int count = 4,
  }) {
    final grouped = <String, List<PaceSeriesPoint>>{};

    for (final point in fromMonthly(stats)) {
      final key = '${point.startDate.year}-T${point.quarterNumber}';
      grouped.putIfAbsent(key, () => <PaceSeriesPoint>[]).add(point);
    }

    final quarters = grouped.values.map(_mergeQuarter).toList();

    // O primeiro trimestre da janela costuma vir incompleto (só 1 ou 2 meses
    // carregados) e distorceria a leitura — descarta quando há troco.
    if (quarters.length > 1 && quarters.first.endDate.difference(quarters.first.startDate).inDays < 80) {
      quarters.removeAt(0);
    }

    if (quarters.length <= count) return quarters;
    return quarters.sublist(quarters.length - count);
  }

  static PaceSeriesPoint _mergeQuarter(List<PaceSeriesPoint> months) {
    final first = months.first;
    final last = months.last;

    var distance = 0.0;
    var duration = 0;
    var runs = 0;
    var goal = 0.0;
    for (final month in months) {
      distance += month.distanceKm;
      duration += month.durationSeconds;
      runs += month.runCount;
      goal += month.goalKm;
    }

    return PaceSeriesPoint(
      periodId: '${first.startDate.year}-T${first.quarterNumber}',
      type: TrendPeriodType.quarter,
      startDate: DateTime(first.startDate.year, first.startDate.month, 1),
      endDate: last.endDate,
      distanceKm: distance,
      durationSeconds: duration,
      runCount: runs,
      goalKm: goal,
    );
  }

  static TrendSummary summarize(List<PaceSeriesPoint> points) {
    final active = points.where((p) => p.hasRuns).toList();
    if (active.isEmpty) {
      return const TrendSummary();
    }

    var distance = 0.0;
    var seconds = 0;
    var runs = 0;
    for (final point in active) {
      distance += point.distanceKm;
      seconds += point.durationSeconds;
      runs += point.runCount;
    }

    final weightedAverage = distance > 0 ? (seconds / 60.0) / distance : null;

    var best = active.first;
    for (final point in active) {
      if (point.paceMinPerKm! < best.paceMinPerKm!) best = point;
    }

    double? delta;
    if (active.length >= 4) {
      final recent = active.sublist(active.length - 3);
      final priorStart = math.max(0, active.length - 6);
      final prior = active.sublist(priorStart, active.length - 3);
      if (prior.isNotEmpty) {
        delta = _meanPace(recent) - _meanPace(prior);
      }
    }

    final latest = active.last;
    return TrendSummary(
      currentPace: latest.paceMinPerKm,
      currentLabel: latest.shortLabel,
      averagePace: weightedAverage,
      bestPace: best.paceMinPerKm,
      bestLabel: best.shortLabel,
      paceDelta: delta,
      totalDistanceKm: distance,
      totalRuns: runs,
      activePeriods: active.length,
    );
  }

  static double _meanPace(List<PaceSeriesPoint> points) {
    final total = points.fold<double>(0, (sum, p) => sum + p.paceMinPerKm!);
    return total / points.length;
  }
}
