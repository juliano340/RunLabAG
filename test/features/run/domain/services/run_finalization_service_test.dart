import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/features/run/domain/services/run_finalization_service.dart';

void main() {
  group('RunFinalizationService.isShortRun', () {
    test('returns true below 100m and below 30s', () {
      expect(
        RunFinalizationService.isShortRun(
          distanceKm: 0.09,
          elapsedSeconds: 29,
        ),
        true,
      );
    });

    test('returns false at 100m', () {
      expect(
        RunFinalizationService.isShortRun(
          distanceKm: 0.1,
          elapsedSeconds: 29,
        ),
        false,
      );
    });

    test('returns false at 30s', () {
      expect(
        RunFinalizationService.isShortRun(
          distanceKm: 0.09,
          elapsedSeconds: 30,
        ),
        false,
      );
    });
  });

  group('RunFinalizationService.shouldAddFinalSplit', () {
    test('adds split near next kilometer', () {
      expect(
        RunFinalizationService.shouldAddFinalSplit(
          distanceKm: 4.995,
          lastKmNotified: 4,
        ),
        true,
      );
    });

    test('adds split when distance is more than 0.99km beyond last notified', () {
      expect(
        RunFinalizationService.shouldAddFinalSplit(
          distanceKm: 5.01,
          lastKmNotified: 4,
        ),
        true,
      );
    });

    test('does not add split for partial remainder', () {
      expect(
        RunFinalizationService.shouldAddFinalSplit(
          distanceKm: 4.5,
          lastKmNotified: 4,
        ),
        false,
      );
    });

    test('does not add split when already notified', () {
      expect(
        RunFinalizationService.shouldAddFinalSplit(
          distanceKm: 5.0,
          lastKmNotified: 5,
        ),
        false,
      );
    });
  });

  group('RunFinalizationService split calculations', () {
    test('calculates final split time', () {
      expect(
        RunFinalizationService.calculateFinalSplitTime(
          elapsedSeconds: 1800,
          lastSplitTimeSeconds: 1200,
        ),
        600,
      );
    });

    test('calculates final split calories', () {
      expect(
        RunFinalizationService.calculateFinalSplitCalories(
          totalCalories: 320,
          lastSplitCalories: 250,
        ),
        70,
      );
    });

    test('rounds final notified kilometer', () {
      expect(RunFinalizationService.calculateFinalNotifiedKm(4.99), 5);
    });
  });
}
