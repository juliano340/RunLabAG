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

  /// Converte "47" (min), "47:30" (min:seg) ou "1:47:30" (h:min:seg) em
  /// segundos. Devolve null para entrada inválida ou zero.
  static int? parseDurationInput(String input) {
    final parts = input.trim().split(':');
    if (parts.isEmpty || parts.length > 3) return null;

    final numbers = <int>[];
    for (final part in parts) {
      if (part.isEmpty) return null;
      final value = int.tryParse(part);
      if (value == null || value < 0) return null;
      numbers.add(value);
    }

    int seconds;
    if (numbers.length == 1) {
      seconds = numbers[0] * 60;
    } else if (numbers.length == 2) {
      if (numbers[1] >= 60) return null;
      seconds = numbers[0] * 60 + numbers[1];
    } else {
      if (numbers[1] >= 60 || numbers[2] >= 60) return null;
      seconds = numbers[0] * 3600 + numbers[1] * 60 + numbers[2];
    }
    return seconds > 0 ? seconds : null;
  }

  /// Segundos → "47:30" ou "1:47:30" (o inverso de [parseDurationInput]).
  static String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
