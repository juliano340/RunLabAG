import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/features/run/domain/services/run_metrics_service.dart';

void main() {
  group('RunMetricsService.calculateCalories', () {
    test('returns 0 for zero distance', () {
      expect(RunMetricsService.calculateCalories(0, 70), 0);
    });

    test('calculates calories for 5km at 70kg', () {
      // 70 * 5 * 1.036 = 362.6 → 362
      final result = RunMetricsService.calculateCalories(5.0, 70.0);
      expect(result, 362);
    });

    test('calculates calories for 1km at 80kg', () {
      // 80 * 1 * 1.036 = 82.88 → 82
      final result = RunMetricsService.calculateCalories(1.0, 80.0);
      expect(result, 82);
    });

    test('uses default weight when not provided', () {
      // Same as 70kg default
      final result = RunMetricsService.calculateCalories(1.0, 70.0);
      expect(result, 72); // 70 * 1 * 1.036 = 72.52 → 72
    });
  });

  group('RunMetricsService.calculatePace', () {
    test('returns 0:00 for zero distance', () {
      expect(RunMetricsService.calculatePace(1800, 0), '0:00');
    });

    test('calculates 6:00 pace for 5km in 30min', () {
      // 30 min / 5 km = 6:00 min/km
      final result = RunMetricsService.calculatePace(1800, 5.0);
      expect(result, '6:00');
    });

    test('calculates 5:30 pace for 10km in 55min', () {
      // 55 min / 10 km = 5.5 min/km = 5:30
      final result = RunMetricsService.calculatePace(3300, 10.0);
      expect(result, '5:30');
    });

    test('calculates 4:00 pace for 5km in 20min', () {
      // 20 min / 5 km = 4:00 min/km
      final result = RunMetricsService.calculatePace(1200, 5.0);
      expect(result, '4:00');
    });

    test('returns 0:00 for unrealistic pace (>35 min/km)', () {
      // 3500 seconds for 0.01km = 583 min/km (unrealistic)
      final result = RunMetricsService.calculatePace(3500, 0.01);
      expect(result, '0:00');
    });
  });

  group('RunMetricsService.calculateETA', () {
    test('returns --:-- for very short distance', () {
      expect(
        RunMetricsService.calculateETA(
          currentDistanceKm: 0.05,
          goalDistanceKm: 5.0,
          elapsedSeconds: 300,
        ),
        '--:--',
      );
    });

    test('returns --:-- for zero goal', () {
      expect(
        RunMetricsService.calculateETA(
          currentDistanceKm: 1.0,
          goalDistanceKm: 0,
          elapsedSeconds: 600,
        ),
        '--:--',
      );
    });

    test('returns Chegou! when goal reached', () {
      expect(
        RunMetricsService.calculateETA(
          currentDistanceKm: 5.0,
          goalDistanceKm: 5.0,
          elapsedSeconds: 1800,
        ),
        'Chegou!',
      );
    });

    test('returns Chegou! when goal exceeded', () {
      expect(
        RunMetricsService.calculateETA(
          currentDistanceKm: 5.1,
          goalDistanceKm: 5.0,
          elapsedSeconds: 1800,
        ),
        'Chegou!',
      );
    });

    test('returns deterministic ETA for remaining distance', () {
      final result = RunMetricsService.calculateETA(
        currentDistanceKm: 2.5,
        goalDistanceKm: 5.0,
        elapsedSeconds: 900, // 15 min for 2.5km → 6:00 pace
        now: DateTime(2026, 1, 1, 10, 0),
      );
      expect(result, '10:15');
    });
  });

  group('RunMetricsService.calculateSplitCalories', () {
    test('calculates difference between total and last split', () {
      expect(
        RunMetricsService.calculateSplitCalories(
          totalCalories: 200,
          lastSplitCalories: 120,
        ),
        80,
      );
    });

    test('returns total when no previous splits', () {
      expect(
        RunMetricsService.calculateSplitCalories(
          totalCalories: 150,
          lastSplitCalories: 0,
        ),
        150,
      );
    });
  });
}
