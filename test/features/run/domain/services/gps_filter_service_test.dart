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
    test('rejects implausible GPS teleport speed > 25 m/s', () {
      // 80 meters in 1 second = 80 m/s (~288 km/h)
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 80.0,
          timeDiffSeconds: 1,
        ),
        true,
      );
    });

    test('accepts normal running speed <= 10 m/s', () {
      // 10 meters in 2 seconds = 5 m/s
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 10.0,
          timeDiffSeconds: 2,
        ),
        false,
      );
    });

    test('accepts walking movement around 5 km/h', () {
      // 4 meters in 3 seconds = 1.33 m/s (~4.8 km/h)
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 4.0,
          timeDiffSeconds: 3,
        ),
        false,
      );
    });

    test('accepts light running movement around 11 km/h', () {
      // 9 meters in 3 seconds = 3 m/s (~10.8 km/h)
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 9.0,
          timeDiffSeconds: 3,
        ),
        false,
      );
    });

    test('accepts urban bus movement around 43 km/h', () {
      // 12 meters in 1 second = 12 m/s (~43 km/h)
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 12.0,
          timeDiffSeconds: 1,
        ),
        false,
      );
    });

    test('accepts faster urban bus movement around 65 km/h', () {
      // 18 meters in 1 second = 18 m/s (~65 km/h)
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 18.0,
          timeDiffSeconds: 1,
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
    test('returns true for distance > 6m when stationary', () {
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 6.1,
          estimatedSpeed: 0,
        ),
        true,
      );
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 10.0,
          estimatedSpeed: 0,
        ),
        true,
      );
    });

    test('returns false for distance <= 6m when stationary', () {
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 6.0,
          estimatedSpeed: 0,
        ),
        false,
      );
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 3.0,
          estimatedSpeed: 0,
        ),
        false,
      );
    });

    test('returns true for distance > 2m when moving (bus scenario)', () {
      // Bus at ~30km/h = ~8m/s, GPS updates every 1s → ~8m between points
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 8.0,
          estimatedSpeed: 8.0,
        ),
        true,
      );
      // Slow bus traffic: 3m displacement at 2m/s
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 3.0,
          estimatedSpeed: 2.0,
        ),
        true,
      );
    });

    test('returns true for accumulated walking displacement > 2m', () {
      // Slow walking can accumulate accepted points every few GPS ticks.
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 2.5,
          estimatedSpeed: 1.2,
        ),
        true,
      );
    });

    test('returns false for distance <= 2m even when moving', () {
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 1.5,
          estimatedSpeed: 5.0,
        ),
        false,
      );
    });

    test('uses stationary threshold when speed is unknown', () {
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 3.0,
          estimatedSpeed: null,
        ),
        false,
      );
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 7.0,
          estimatedSpeed: null,
        ),
        true,
      );
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

    test('does not trigger while walking', () {
      expect(
        GpsFilterService.shouldAutoPause(
          speed: 1.2,
          lowSpeedTicks: 5,
          elapsedSeconds: 60,
          lastResumeSeconds: 0,
        ),
        false,
      );
    });

    test('does not trigger while moving in a bus', () {
      expect(
        GpsFilterService.shouldAutoPause(
          speed: 8.0,
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
