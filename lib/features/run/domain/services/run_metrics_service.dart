/// Pure calculation functions for run metrics.
/// No state, no side effects — just math.
class RunMetricsService {
  /// Calculate calories burned based on weight and distance.
  /// Formula: weight(kg) * distance(km) * 1.036
  static int calculateCalories(double distanceKm, double weightKg) {
    if (distanceKm == 0) return 0;
    return (weightKg * distanceKm * 1.036).toInt();
  }

  /// Calculate pace from elapsed time and distance.
  /// Returns formatted string like "6:30" (min/km).
  static String calculatePace(int elapsedSeconds, double distanceKm) {
    if (distanceKm == 0) return '0:00';
    final paceInMinutes = (elapsedSeconds / 60) / distanceKm;
    if (paceInMinutes <= 0 || paceInMinutes >= 35) return '0:00';
    final minutes = paceInMinutes.toInt();
    final seconds = ((paceInMinutes - minutes) * 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Calculate ETA based on current pace and remaining distance.
  /// Returns formatted time like "14:30" or special strings.
  static String calculateETA({
    required double currentDistanceKm,
    required double goalDistanceKm,
    required int elapsedSeconds,
    DateTime? now,
  }) {
    if (currentDistanceKm < 0.1) return '--:--';
    if (goalDistanceKm == 0) return '--:--';

    final remainingDistance = goalDistanceKm - currentDistanceKm;
    if (remainingDistance <= 0) return 'Chegou!';

    final paceInMinutes = (elapsedSeconds / 60) / currentDistanceKm;
    final remainingMinutes = remainingDistance * paceInMinutes;
    final eta = (now ?? DateTime.now()).add(
      Duration(seconds: (remainingMinutes * 60).toInt()),
    );
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  }

  /// Calculate split calories increment.
  static int calculateSplitCalories({
    required int totalCalories,
    required int lastSplitCalories,
  }) {
    return totalCalories - lastSplitCalories;
  }
}
