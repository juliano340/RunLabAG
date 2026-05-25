import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/features/run/domain/services/gps_filter_service.dart';

void main() {
  group('GpsFilterService.maxAllowedAccuracy', () {
    test('returns 15m for first 30 seconds', () {
      expect(GpsFilterService.maxAllowedAccuracy(0), 15.0);
      expect(GpsFilterService.maxAllowedAccuracy(15), 15.0);
      expect(GpsFilterService.maxAllowedAccuracy(29), 15.0);
    });

    test('returns 25m after 30 seconds', () {
      expect(GpsFilterService.maxAllowedAccuracy(30), 25.0);
      expect(GpsFilterService.maxAllowedAccuracy(60), 25.0);
      expect(GpsFilterService.maxAllowedAccuracy(3600), 25.0);
    });
  });

  group('GpsFilterService.shouldRejectByAccuracy', () {
    test('rejects point with accuracy > 15m in first 30s', () {
      expect(
        GpsFilterService.shouldRejectByAccuracy(
          pointAccuracy: 20.0,
          elapsedSeconds: 10,
        ),
        true,
      );
    });

    test('accepts point with accuracy <= 15m in first 30s', () {
      expect(
        GpsFilterService.shouldRejectByAccuracy(
          pointAccuracy: 10.0,
          elapsedSeconds: 10,
        ),
        false,
      );
    });

    test('rejects point with accuracy > 25m after 30s', () {
      expect(
        GpsFilterService.shouldRejectByAccuracy(
          pointAccuracy: 30.0,
          elapsedSeconds: 60,
        ),
        true,
      );
    });

    test('accepts point with accuracy <= 25m after 30s', () {
      expect(
        GpsFilterService.shouldRejectByAccuracy(
          pointAccuracy: 20.0,
          elapsedSeconds: 60,
        ),
        false,
      );
    });
  });

  group('GpsFilterService.shouldRejectBySpeedJump', () {
    test('rejects speed > 10 m/s', () {
      // 50 meters in 2 seconds = 25 m/s
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 50.0,
          timeDiffSeconds: 2,
        ),
        true,
      );
    });

    test('accepts speed <= 10 m/s', () {
      // 10 meters in 2 seconds = 5 m/s
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 10.0,
          timeDiffSeconds: 2,
        ),
        false,
      );
    });

    test('does not reject when timeDiff is 0', () {
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 100.0,
          timeDiffSeconds: 0,
        ),
        false,
      );
    });

    test('does not reject when timeDiff is negative', () {
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 100.0,
          timeDiffSeconds: -1,
        ),
        false,
      );
    });
  });

  group('GpsFilterService.isSignificantDisplacement', () {
    test('returns true for distance > 6m', () {
      expect(GpsFilterService.isSignificantDisplacement(6.1), true);
      expect(GpsFilterService.isSignificantDisplacement(10.0), true);
    });

    test('returns false for distance <= 6m', () {
      expect(GpsFilterService.isSignificantDisplacement(6.0), false);
      expect(GpsFilterService.isSignificantDisplacement(3.0), false);
      expect(GpsFilterService.isSignificantDisplacement(0.0), false);
    });
  });

  group('GpsFilterService.shouldAutoPause', () {
    test('triggers after 3 low speed ticks', () {
      expect(
        GpsFilterService.shouldAutoPause(
          speed: 0.2,
          lowSpeedTicks: 3,
          elapsedSeconds: 60,
          lastResumeSeconds: 0,
        ),
        true,
      );
    });

    test('does not trigger with fewer than 3 ticks', () {
      expect(
        GpsFilterService.shouldAutoPause(
          speed: 0.2,
          lowSpeedTicks: 2,
          elapsedSeconds: 60,
          lastResumeSeconds: 0,
        ),
        false,
      );
    });

    test('does not trigger if speed is above threshold', () {
      expect(
        GpsFilterService.shouldAutoPause(
          speed: 0.5,
          lowSpeedTicks: 5,
          elapsedSeconds: 60,
          lastResumeSeconds: 0,
        ),
        false,
      );
    });

    test('does not trigger during grace period (10s after resume)', () {
      expect(
        GpsFilterService.shouldAutoPause(
          speed: 0.1,
          lowSpeedTicks: 3,
          elapsedSeconds: 15,
          lastResumeSeconds: 10,
        ),
        false,
      );
    });
  });

  group('GpsFilterService.updateLowSpeedTicks', () {
    test('increments when speed is below threshold', () {
      expect(
        GpsFilterService.updateLowSpeedTicks(
          speed: 0.2,
          currentTicks: 1,
          elapsedSeconds: 60,
          lastResumeSeconds: 0,
        ),
        2,
      );
    });

    test('resets when speed is above threshold', () {
      expect(
        GpsFilterService.updateLowSpeedTicks(
          speed: 0.5,
          currentTicks: 2,
          elapsedSeconds: 60,
          lastResumeSeconds: 0,
        ),
        0,
      );
    });

    test('resets during grace period', () {
      expect(
        GpsFilterService.updateLowSpeedTicks(
          speed: 0.1,
          currentTicks: 2,
          elapsedSeconds: 15,
          lastResumeSeconds: 10,
        ),
        0,
      );
    });
  });
}
