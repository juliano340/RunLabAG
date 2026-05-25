class RunFinalizationService {
  static bool isShortRun({
    required double distanceKm,
    required int elapsedSeconds,
  }) {
    return distanceKm < 0.1 && elapsedSeconds < 30;
  }

  static bool shouldAddFinalSplit({
    required double distanceKm,
    required int lastKmNotified,
  }) {
    final currentKm = distanceKm.floor();
    final decimalPart = distanceKm - currentKm;

    return distanceKm > lastKmNotified &&
        (decimalPart > 0.99 || distanceKm > lastKmNotified + 0.99);
  }

  static int calculateFinalSplitTime({
    required int elapsedSeconds,
    required int lastSplitTimeSeconds,
  }) {
    return elapsedSeconds - lastSplitTimeSeconds;
  }

  static int calculateFinalSplitCalories({
    required int totalCalories,
    required int lastSplitCalories,
  }) {
    return totalCalories - lastSplitCalories;
  }

  static int calculateFinalNotifiedKm(double distanceKm) {
    return distanceKm.round();
  }
}
