import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/features/analytics/domain/models/monthly_evolution_stats.dart';
import 'package:runlabag/features/analytics/domain/models/pace_series_point.dart';
import 'package:runlabag/features/analytics/domain/services/pace_series_service.dart';
import 'package:runlabag/features/dashboard/domain/models/weekly_evolution_stats.dart';

WeeklyEvolutionStats _week({
  required DateTime start,
  required double distanceKm,
  required int runCount,
  int paceMinutesPerKm = 12,
}) {
  return WeeklyEvolutionStats(
    periodId: '${start.year}-W${start.day}',
    startDate: start,
    endDate: start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59)),
    totalDistance: distanceKm,
    totalDurationSeconds: (paceMinutesPerKm * 60 * distanceKm).round(),
    goalDistance: 20,
    runCount: runCount,
  );
}

MonthlyEvolutionStats _month({
  required DateTime start,
  required double distanceKm,
  required int runCount,
}) {
  return MonthlyEvolutionStats(
    periodId: '${start.year}-${start.month}',
    startDate: start,
    endDate: DateTime(start.year, start.month + 1, 0, 23, 59, 59),
    totalDistance: distanceKm,
    totalDurationSeconds: (12 * 60 * distanceKm).round(),
    goalDistance: 80,
    runCount: runCount,
  );
}

void main() {
  group('PaceSeriesService.fromWeekly', () {
    test('inverte a ordem do banco (mais novo primeiro → cronológico)', () {
      final now = DateTime(2026, 11, 8);
      final newestFirst = [
        _week(start: now, distanceKm: 10, runCount: 2),
        _week(start: now.subtract(const Duration(days: 7)), distanceKm: 5, runCount: 1),
        _week(start: now.subtract(const Duration(days: 14)), distanceKm: 0, runCount: 0),
      ];

      final series = PaceSeriesService.fromWeekly(newestFirst);

      expect(series.first.startDate.isBefore(series.last.startDate), isTrue);
      expect(series.last.distanceKm, 10);
      expect(series.map((p) => p.startDate), [
        now.subtract(const Duration(days: 14)),
        now.subtract(const Duration(days: 7)),
        now,
      ]);
    });

    test('período sem treino tem pace nulo (nunca 0:00)', () {
      final series = PaceSeriesService.fromWeekly([
        _week(start: DateTime(2026, 11, 8), distanceKm: 0, runCount: 0),
      ]);

      expect(series.single.hasRuns, isFalse);
      expect(series.single.paceMinPerKm, isNull);
      expect(series.single.paceLabel, '--:--');
    });
  });

  group('PaceSeriesService.summarize', () {
    test('ignora períodos vazios na média e no melhor pace', () {
      final base = DateTime(2026, 9, 1);
      final series = PaceSeriesService.fromWeekly([
        _week(start: base.add(const Duration(days: 21)), distanceKm: 10, runCount: 2, paceMinutesPerKm: 11),
        _week(start: base.add(const Duration(days: 14)), distanceKm: 0, runCount: 0),
        _week(start: base.add(const Duration(days: 7)), distanceKm: 6, runCount: 1, paceMinutesPerKm: 13),
        _week(start: base, distanceKm: 4, runCount: 1, paceMinutesPerKm: 15),
      ]);

      final summary = PaceSeriesService.summarize(series);

      expect(summary.activePeriods, 3);
      expect(summary.bestPace, 11);
      expect(summary.currentPace, 11);
      // Média ponderada: (10*11 + 6*13 + 4*15) / 20 = 12.4
      expect(summary.averagePace, closeTo(12.4, 0.001));
      expect(summary.totalDistanceKm, 20);
      expect(summary.totalRuns, 4);
    });

    test('sem nenhum treino devolve resumo vazio', () {
      final summary = PaceSeriesService.summarize(
        PaceSeriesService.fromWeekly([
          _week(start: DateTime(2026, 11, 8), distanceKm: 0, runCount: 0),
        ]),
      );

      expect(summary.hasData, isFalse);
      expect(summary.currentPace, isNull);
      expect(summary.paceDelta, isNull);
    });

    test('paceDelta negativo indica evolução (mais rápido)', () {
      final base = DateTime(2026, 8, 1);
      final weeks = <WeeklyEvolutionStats>[];
      // 4 semanas antigas em 13:00 e 4 recentes em 12:00.
      for (var i = 0; i < 8; i++) {
        final start = base.add(Duration(days: 7 * i));
        weeks.insert(
          0,
          _week(
            start: start,
            distanceKm: 5,
            runCount: 1,
            paceMinutesPerKm: i < 4 ? 13 : 12,
          ),
        );
      }

      final summary = PaceSeriesService.summarize(
        PaceSeriesService.fromWeekly(weeks),
      );

      expect(summary.paceDelta, isNotNull);
      expect(summary.paceDelta!, lessThan(0));
      expect(summary.isImproving, isTrue);
    });

    test('menos de 4 períodos com treino não calcula tendência', () {
      final base = DateTime(2026, 10, 1);
      final summary = PaceSeriesService.summarize(
        PaceSeriesService.fromWeekly([
          _week(start: base.add(const Duration(days: 14)), distanceKm: 5, runCount: 1),
          _week(start: base.add(const Duration(days: 7)), distanceKm: 5, runCount: 1),
          _week(start: base, distanceKm: 5, runCount: 1),
        ]),
      );

      expect(summary.paceDelta, isNull);
    });
  });

  group('PaceSeriesService.quarters', () {
    test('agrupa meses em trimestres com distância somada', () {
      final monthly = [
        _month(start: DateTime(2026, 11, 1), distanceKm: 30, runCount: 4),
        _month(start: DateTime(2026, 10, 1), distanceKm: 40, runCount: 3),
        _month(start: DateTime(2026, 9, 1), distanceKm: 20, runCount: 2),
        _month(start: DateTime(2026, 8, 1), distanceKm: 10, runCount: 1),
        _month(start: DateTime(2026, 7, 1), distanceKm: 10, runCount: 1),
        _month(start: DateTime(2026, 6, 1), distanceKm: 10, runCount: 1),
      ];

      final quarters = PaceSeriesService.quarters(monthly);

      // O trimestre mais antigo (junho isolado) é descartado por vir incompleto.
      expect(quarters.length, 2);
      expect(quarters.last.type, TrendPeriodType.quarter);
      // Out + Nov = 70 km, 7 treinos
      expect(quarters.last.distanceKm, 70);
      expect(quarters.last.runCount, 7);
      expect(quarters.last.startDate, DateTime(2026, 10, 1));
      expect(quarters.first.startDate, DateTime(2026, 7, 1));
    });
  });

  group('PaceSeriesPoint.formatPace', () {
    test('arredonda para o segundo mais próximo', () {
      expect(PaceSeriesPoint.formatPace(12.5), '12:30');
      expect(PaceSeriesPoint.formatPace(12.9999), '13:00');
      expect(PaceSeriesPoint.formatPace(null), '--:--');
      expect(PaceSeriesPoint.formatPace(0), '--:--');
    });
  });
}
