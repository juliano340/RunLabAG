import '../../../dashboard/domain/models/weekly_evolution_stats.dart';
import 'monthly_evolution_stats.dart';

/// Granularidade de agrupamento usada nos gráficos de análise.
enum TrendPeriodType { day, week, month, quarter }

const List<String> _monthShort = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];

const List<String> _monthLong = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

const List<String> _weekdayShort = [
  'Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb',
];

const List<String> _weekdayLong = [
  'Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado',
];

/// Um ponto de uma série temporal de treinos (uma semana, um mês ou um trimestre).
///
/// O pace é [pace] = `null` quando não houve treino no período — nunca `0,0`.
/// Períodos sem treino precisam aparecer como lacuna, não como pace zero.
class PaceSeriesPoint {
  const PaceSeriesPoint({
    required this.periodId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.distanceKm,
    required this.durationSeconds,
    required this.runCount,
    required this.goalKm,
  });

  final String periodId;
  final TrendPeriodType type;
  final DateTime startDate;
  final DateTime endDate;
  final double distanceKm;
  final int durationSeconds;
  final int runCount;
  final double goalKm;

  factory PaceSeriesPoint.fromWeekly(WeeklyEvolutionStats stats) {
    return PaceSeriesPoint(
      periodId: stats.periodId,
      type: TrendPeriodType.week,
      startDate: stats.startDate,
      endDate: stats.endDate,
      distanceKm: stats.totalDistance,
      durationSeconds: stats.totalDurationSeconds,
      runCount: stats.runCount,
      goalKm: stats.goalDistance,
    );
  }

  factory PaceSeriesPoint.fromMonthly(MonthlyEvolutionStats stats) {
    return PaceSeriesPoint(
      periodId: stats.periodId,
      type: TrendPeriodType.month,
      startDate: stats.startDate,
      endDate: stats.endDate,
      distanceKm: stats.totalDistance,
      durationSeconds: stats.totalDurationSeconds,
      runCount: stats.runCount,
      goalKm: stats.goalDistance,
    );
  }

  /// Houve treino de verdade no período (distância e duração válidas).
  bool get hasRuns => runCount > 0 && distanceKm > 0 && durationSeconds > 0;

  /// Pace em minutos por quilômetro. `null` quando o período não tem treino.
  double? get paceMinPerKm {
    if (!hasRuns) return null;
    return (durationSeconds / 60.0) / distanceKm;
  }

  String get paceLabel => formatPace(paceMinPerKm);

  /// Período ainda em andamento (dia/semana/mês/trimestre corrente).
  ///
  /// Nos dias: só o dia de hoje conta — dias futuros da semana nem
  /// aconteceram ainda, não são "em andamento".
  bool get isOngoing {
    final now = DateTime.now();
    if (type == TrendPeriodType.day) {
      final today = DateTime(now.year, now.month, now.day);
      return !startDate.isAfter(today) && endDate.isAfter(now);
    }
    return endDate.isAfter(now);
  }

  /// Rótulo curto usado no eixo X dos gráficos.
  String get axisLabel {
    if (type == TrendPeriodType.day) {
      return _weekdayShort[startDate.weekday % 7];
    }
    if (type == TrendPeriodType.month) {
      return _monthShort[startDate.month - 1];
    }
    if (type == TrendPeriodType.quarter) {
      return 'T$quarterNumber';
    }
    return '${startDate.day}/${startDate.month}';
  }

  /// Rótulo curto usado como legenda secundária no resumo.
  String get shortLabel {
    if (type == TrendPeriodType.day) {
      return _weekdayShort[startDate.weekday % 7];
    }
    if (type == TrendPeriodType.month) {
      return '${_monthShort[startDate.month - 1]}/${_twoDigits(startDate.year % 100)}';
    }
    if (type == TrendPeriodType.quarter) {
      return 'T$quarterNumber/${_twoDigits(startDate.year % 100)}';
    }
    return '${startDate.day}/${startDate.month}';
  }

  /// Rótulo completo do intervalo, usado no tooltip.
  String get rangeLabel {
    if (type == TrendPeriodType.day) {
      return '${_weekdayLong[startDate.weekday % 7]}, '
          '${startDate.day}/${startDate.month}';
    }
    if (type == TrendPeriodType.month) {
      return '${_monthLong[startDate.month - 1]} de ${startDate.year}';
    }
    if (type == TrendPeriodType.quarter) {
      final lastMonth = endDate.month;
      return 'T$quarterNumber · ${_monthShort[startDate.month - 1]}–'
          '${_monthShort[lastMonth - 1]} ${startDate.year}';
    }
    if (startDate.month == endDate.month) {
      return '${startDate.day}–${endDate.day}/${startDate.month}';
    }
    return '${startDate.day}/${startDate.month}–${endDate.day}/${endDate.month}';
  }

  int get quarterNumber => ((startDate.month - 1) ~/ 3) + 1;

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  /// Converte minutos decimais em `m:ss` (ex.: `12.45` → `12:27`).
  static String formatPace(double? minutes) {
    if (minutes == null || minutes <= 0 || !minutes.isFinite) return '--:--';
    final totalSeconds = (minutes * 60).round();
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
