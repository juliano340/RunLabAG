/// Pure GPS filtering rules for run tracking.
/// No state, no side effects — just decision logic.
class GpsFilterService {
  /// Maximum allowed GPS accuracy (meters).
  /// More strict in first 30 seconds.
  static double maxAllowedAccuracy(int elapsedSeconds) {
    return elapsedSeconds < 30 ? 15.0 : 25.0;
  }

  /// Check if a GPS point should be rejected due to poor accuracy.
  static bool shouldRejectByAccuracy({
    required double pointAccuracy,
    required int elapsedSeconds,
  }) {
    return pointAccuracy > maxAllowedAccuracy(elapsedSeconds);
  }

  /// Check if a GPS point should be rejected due to excessive speed jump.
  /// Returns true if the implied speed exceeds 10 m/s (~36 km/h).
  static bool shouldRejectBySpeedJump({
    required double distanceMeters,
    required int timeDiffSeconds,
  }) {
    if (timeDiffSeconds <= 0) return false;
    final speed = distanceMeters / timeDiffSeconds;
    return speed > 10.0;
  }

  /// Check if a GPS displacement is significant enough to count.
  /// Filters out jitter (GPS drift when stationary).
  static bool isSignificantDisplacement(double distanceMeters) {
    return distanceMeters > 6.0;
  }

  /// Determine if auto-pause should trigger based on low speed ticks.
  /// Returns true when speed has been below threshold for enough consecutive ticks.
  static bool shouldAutoPause({
    required double speed,
    required int lowSpeedTicks,
    required int elapsedSeconds,
    required int lastResumeSeconds,
  }) {
    // Grace period: don't auto-pause in first 10 seconds after resume
    if (elapsedSeconds - lastResumeSeconds < 10) return false;
    if (speed >= 0.4) return false;
    return lowSpeedTicks >= 3;
  }

  /// Update low speed tick counter for auto-pause logic.
  /// Returns the new tick count.
  static int updateLowSpeedTicks({
    required double speed,
    required int currentTicks,
    required int elapsedSeconds,
    required int lastResumeSeconds,
  }) {
    // Grace period: reset counter
    if (elapsedSeconds - lastResumeSeconds < 10) return 0;
    if (speed < 0.4) return currentTicks + 1;
    return 0; // Reset if moving
  }
}
