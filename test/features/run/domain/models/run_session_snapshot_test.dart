import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/features/run/domain/models/run_session_snapshot.dart';

void main() {
  test('snapshot restaura metadados e formatos legados de splits', () {
    final snapshot = RunSessionSnapshot.fromStored({
      'distanceKm': 5.5,
      'secondsElapsed': 2100,
      'pausedDurationSeconds': 15,
      'lastKmNotified': 5,
      'distanceGoal': 10,
      'targetTimeSeconds': 3600,
      'startTime': '2026-11-24T14:30:00.000',
      'isPaused': 1,
      'finished': 0,
      'splits': jsonEncode([
        {'t': 420, 'c': 52},
        390,
      ]),
      'autoPauses': jsonEncode([
        {
          'lat': -23.55,
          'lng': -46.63,
          'durationSeconds': 12,
          'timestamp': '2026-11-24T14:40:00.000',
          'resume_lat': -23.56,
          'resume_lng': -46.64,
        },
      ]),
    });

    expect(snapshot.distanceKm, 5.5);
    expect(snapshot.isPaused, isTrue);
    expect(snapshot.splits, hasLength(2));
    expect(snapshot.splits.first.calories, 52);
    expect(snapshot.splits.last.calories, 0);
    expect(snapshot.autoPauses.single.resumeLocation?.latitude, -23.56);
  });

  test('toMeta marca finalização e serializa listas tipadas', () {
    final snapshot = RunSessionSnapshot(
      distanceKm: 1,
      secondsElapsed: 300,
      pausedDurationSeconds: 3,
      lastKmNotified: 1,
      distanceGoal: null,
      targetTimeSeconds: null,
      startTime: DateTime(2026, 11, 24),
      isPaused: false,
      isFinished: false,
      splits: [],
      autoPauses: [],
    );

    final meta = snapshot.toMeta(
      finished: true,
      fallbackStartTime: DateTime(2027),
    );

    expect(meta['finished'], 1);
    expect(meta['isPaused'], 1);
    expect(meta['startTime'], '2026-11-24T00:00:00.000');
    expect(jsonDecode(meta['splits'] as String), isEmpty);
  });

  test('coleções corrompidas degradam para vazio', () {
    expect(RunSessionSnapshot.decodeSplits('não-json'), isEmpty);
    expect(RunSessionSnapshot.decodeAutoPauses('não-json'), isEmpty);
  });
}
