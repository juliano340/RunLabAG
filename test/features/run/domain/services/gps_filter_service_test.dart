import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/features/run/domain/services/gps_filter_service.dart';

void main() {
  group('GpsFilterService.maxAllowedAccuracy', () {
    test('is stricter in the first 30 seconds', () {
      expect(GpsFilterService.maxAllowedAccuracy(0), 15.0);
      expect(GpsFilterService.maxAllowedAccuracy(29), 15.0);
      expect(GpsFilterService.maxAllowedAccuracy(30), 25.0);
      expect(GpsFilterService.maxAllowedAccuracy(120), 25.0);
    });
  });

  group('GpsFilterService.shouldRejectByAccuracy', () {
    test('accepts point within limit at start of run', () {
      expect(
        GpsFilterService.shouldRejectByAccuracy(
          pointAccuracy: 10.0,
          elapsedSeconds: 5,
        ),
        isFalse,
      );
    });

    test('rejects point above limit at start of run', () {
      expect(
        GpsFilterService.shouldRejectByAccuracy(
          pointAccuracy: 16.0,
          elapsedSeconds: 5,
        ),
        isTrue,
      );
    });

    test('rejects borderline point that was valid during warmup', () {
      expect(
        GpsFilterService.shouldRejectByAccuracy(
          pointAccuracy: 20.0,
          elapsedSeconds: 60,
        ),
        isFalse,
      );
    });
  });

  group('GpsFilterService.shouldRejectBySpeedJump', () {
    test('accepts normal movement', () {
      // 10m em 2s = 5 m/s
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 10,
          timeDiffSeconds: 2,
        ),
        isFalse,
      );
    });

    test('rejects GPS teleport (>25 m/s)', () {
      // 100m em 1s = 100 m/s
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 100,
          timeDiffSeconds: 1,
        ),
        isTrue,
      );
    });

    test('keeps car speed (~90 km/h = 25 m/s boundary)', () {
      // exatamente 25 m/s não rejeita
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 50,
          timeDiffSeconds: 2,
        ),
        isFalse,
      );
    });

    test('never rejects when time diff is zero', () {
      expect(
        GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: 500,
          timeDiffSeconds: 0,
        ),
        isFalse,
      );
    });
  });

  group('GpsFilterService.isSignificantDisplacement', () {
    test('uses higher threshold when stationary', () {
      expect(
        GpsFilterService.isSignificantDisplacement(distanceMeters: 4.0),
        isFalse,
        reason: 'drift de GPS parado deve ser filtrado',
      );
      expect(
        GpsFilterService.isSignificantDisplacement(distanceMeters: 7.0),
        isTrue,
      );
    });

    test('uses lower threshold when clearly moving', () {
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 2.5,
          estimatedSpeed: 1.0,
        ),
        isTrue,
      );
      expect(
        GpsFilterService.isSignificantDisplacement(
          distanceMeters: 1.5,
          estimatedSpeed: 1.0,
        ),
        isFalse,
      );
    });
  });

  group('GpsFilterService auto-pause ticks', () {
    test('shouldAutoPause requires 3 consecutive low-speed ticks', () {
      expect(
        GpsFilterService.shouldAutoPause(
          speed: 0.1,
          lowSpeedTicks: 2,
          elapsedSeconds: 60,
          lastResumeSeconds: 0,
        ),
        isFalse,
      );
      expect(
        GpsFilterService.shouldAutoPause(
          speed: 0.1,
          lowSpeedTicks: 3,
          elapsedSeconds: 60,
          lastResumeSeconds: 0,
        ),
        isTrue,
      );
    });

    test('shouldAutoPause ignores grace period after resume', () {
      expect(
        GpsFilterService.shouldAutoPause(
          speed: 0.0,
          lowSpeedTicks: 3,
          elapsedSeconds: 15,
          lastResumeSeconds: 10,
        ),
        isFalse,
        reason: 'não deve pausar nos primeiros 10s após retomada',
      );
    });

    test('shouldAutoPause does not trigger while moving', () {
      expect(
        GpsFilterService.shouldAutoPause(
          speed: 0.5,
          lowSpeedTicks: 10,
          elapsedSeconds: 60,
          lastResumeSeconds: 0,
        ),
        isFalse,
      );
    });

    test('updateLowSpeedTicks increments below threshold', () {
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

    test('updateLowSpeedTicks resets when moving', () {
      expect(
        GpsFilterService.updateLowSpeedTicks(
          speed: 3.0,
          currentTicks: 2,
          elapsedSeconds: 60,
          lastResumeSeconds: 0,
        ),
        0,
      );
    });

    test('updateLowSpeedTicks resets during resume grace period', () {
      expect(
        GpsFilterService.updateLowSpeedTicks(
          speed: 0.2,
          currentTicks: 2,
          elapsedSeconds: 12,
          lastResumeSeconds: 10,
        ),
        0,
      );
    });
  });
}
