
class WeeklyEvolutionStats {
  final String periodId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalDistance;
  final int totalDurationSeconds;
  final double goalDistance;
  final int runCount;

  WeeklyEvolutionStats({
    required this.periodId,
    required this.startDate,
    required this.endDate,
    required this.totalDistance,
    required this.totalDurationSeconds,
    required this.goalDistance,
    required this.runCount,
  });

  double get achievementPercentage => goalDistance > 0 ? (totalDistance / goalDistance) * 100 : 0.0;
  
  String get avgPace {
    if (totalDistance <= 0) return '0:00';
    double paceInMinutes = (totalDurationSeconds / 60) / totalDistance;
    int minutes = paceInMinutes.toInt();
    int seconds = ((paceInMinutes - minutes) * 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  double get paceRaw {
    if (totalDistance <= 0) return 0.0;
    return (totalDurationSeconds / 60) / totalDistance;
  }
}
