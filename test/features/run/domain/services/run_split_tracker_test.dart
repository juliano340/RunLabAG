import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/domain/models/run_split.dart';
import 'package:runlabag/features/run/domain/services/run_split_tracker.dart';

void main() {
  test('cada quilômetro gera split com tempo e calorias incrementais', () {
    final tracker = RunSplitTracker();

    expect(
      tracker.recordDistance(
        distanceKm: 0.99,
        elapsedSeconds: 300,
        totalCalories: 60,
      ),
      isNull,
    );
    final first = tracker.recordDistance(
      distanceKm: 1.01,
      elapsedSeconds: 360,
      totalCalories: 62,
    );
    final second = tracker.recordDistance(
      distanceKm: 2.01,
      elapsedSeconds: 720,
      totalCalories: 124,
    );

    expect(first?.timeSeconds, 360);
    expect(first?.calories, 62);
    expect(second?.timeSeconds, 360);
    expect(second?.calories, 62);
    expect(tracker.lastKmNotified, 2);
  });

  test('finalização acrescenta split parcial e restaurar reconstrói bases', () {
    final tracker = RunSplitTracker();
    tracker.restore(
      splits: [RunSplit(timeSeconds: 360, calories: 60)],
      lastKmNotified: 1,
    );

    final partial = tracker.finalize(
      distanceKm: 1.995,
      elapsedSeconds: 750,
      totalCalories: 125,
    );

    expect(partial?.timeSeconds, 390);
    expect(partial?.calories, 65);
    expect(tracker.lastKmNotified, 2);
    expect(tracker.splits, hasLength(2));
  });

  test('finalização não duplica split quando não há partial', () {
    final tracker = RunSplitTracker();
    tracker.recordDistance(
      distanceKm: 1.01,
      elapsedSeconds: 360,
      totalCalories: 60,
    );

    expect(
      tracker.finalize(distanceKm: 1.2, elapsedSeconds: 400, totalCalories: 70),
      isNull,
    );
    expect(tracker.splits, hasLength(1));
  });
}
