enum HistoryPeriodMode { week, month }

/// Intervalo fechado no início e exclusivo no fim, sempre em hora local.
class HistoryPeriod {
  final HistoryPeriodMode mode;
  final DateTime referenceDate;
  final DateTime start;
  final DateTime end;

  const HistoryPeriod({
    required this.mode,
    required this.referenceDate,
    required this.start,
    required this.end,
  });

  factory HistoryPeriod.week(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(day.year, day.month, day.day - day.weekday % 7);
    return HistoryPeriod(
      mode: HistoryPeriodMode.week,
      referenceDate: day,
      start: start,
      end: DateTime(start.year, start.month, start.day + 7),
    );
  }

  factory HistoryPeriod.month(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(day.year, day.month, 1);
    return HistoryPeriod(
      mode: HistoryPeriodMode.month,
      referenceDate: day,
      start: start,
      end: DateTime(day.year, day.month + 1, 1),
    );
  }

  String get id {
    if (mode == HistoryPeriodMode.month) {
      return '${start.year}-${start.month.toString().padLeft(2, '0')}';
    }
    // Usa UTC apenas para contar dias corridos: `difference` em hora local
    // pode perder um dia quando a semana cruza uma transição de horário.
    final dayOfYear = DateTime.utc(
      start.year,
      start.month,
      start.day,
    ).difference(DateTime.utc(start.year, 1, 1)).inDays;
    final weekNumber = (dayOfYear / 7).floor() + 1;
    return '${start.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  String get goalType => mode == HistoryPeriodMode.week ? 'weekly' : 'monthly';

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);

  HistoryPeriod get previous => mode == HistoryPeriodMode.week
      ? HistoryPeriod.week(DateTime(start.year, start.month, start.day - 7))
      : HistoryPeriod.month(DateTime(start.year, start.month - 1, 1));

  HistoryPeriod get next => mode == HistoryPeriodMode.week
      ? HistoryPeriod.week(DateTime(start.year, start.month, start.day + 7))
      : HistoryPeriod.month(DateTime(start.year, start.month + 1, 1));

  String get title {
    const months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    const shortMonths = [
      '',
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    if (mode == HistoryPeriodMode.month) {
      return '${months[start.month]} ${start.year}';
    }

    final lastDay = DateTime(start.year, start.month, start.day + 6);
    if (start.month == lastDay.month) {
      return '${start.day} - ${lastDay.day} de ${months[start.month]}';
    }
    return '${start.day} ${shortMonths[start.month]} - '
        '${lastDay.day} ${shortMonths[lastDay.month]}';
  }
}

class HistorySummary {
  final double totalKm;
  final int totalSeconds;
  final int totalCalories;
  final double estimatedWeightLossKg;
  final double rawGoalProgress;
  final double goalProgress;

  const HistorySummary({
    required this.totalKm,
    required this.totalSeconds,
    required this.totalCalories,
    required this.estimatedWeightLossKg,
    required this.rawGoalProgress,
    required this.goalProgress,
  });
}

class HistoryChartBar {
  final int index;
  final double distanceKm;
  final double colorRatio;

  const HistoryChartBar({
    required this.index,
    required this.distanceKm,
    required this.colorRatio,
  });
}
