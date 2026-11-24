import 'user_totals.dart';

/// Visão agregada usada pelo dashboard e pelo formulário manual.
/// Mantém números tipados; formatação pertence ao modelo de exibição.
class UserStats {
  final UserTotals totals;
  final double averagePaceSecondsPerKm;

  const UserStats({
    required this.totals,
    required this.averagePaceSecondsPerKm,
  });

  static const empty = UserStats(
    totals: UserTotals.empty,
    averagePaceSecondsPerKm: 0,
  );

  double get averagePaceMinutesPerKm => averagePaceSecondsPerKm / 60;

  String get formattedTotalDistance =>
      totals.totalDistanceKm.toStringAsFixed(1);

  String get formattedTotalRuns => totals.runCount.toString();

  String get formattedAveragePace {
    final totalSeconds = averagePaceSecondsPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedTotalCalories => totals.totalCalories >= 1000
      ? '${(totals.totalCalories / 1000).toStringAsFixed(1)}k'
      : totals.totalCalories.toString();
}
