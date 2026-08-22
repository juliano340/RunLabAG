import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runlabag/features/history/domain/models/auto_pause_event.dart';
import 'package:runlabag/features/history/domain/models/run_model.dart';

void main() {
  group('AutoPauseEvent & RunModel AutoPause Tests', () {
    test('AutoPauseEvent map and JSON serialization', () {
      final now = DateTime.now().toIso8601String();
      final autoPause = AutoPauseEvent(
        latitude: -23.5505,
        longitude: -46.6333,
        durationSeconds: 125,
        timestamp: now,
      );

      expect(autoPause.location, const LatLng(-23.5505, -46.6333));
      expect(autoPause.formattedDuration, '02:05');

      final map = autoPause.toMap();
      final restored = AutoPauseEvent.fromMap(map);

      expect(restored.latitude, -23.5505);
      expect(restored.longitude, -46.6333);
      expect(restored.durationSeconds, 125);
      expect(restored.timestamp, now);
      expect(restored.resumeLocation, isNull);
    });

    test('AutoPauseEvent serializes resume location', () {
      final autoPause = AutoPauseEvent(
        latitude: -23.5505,
        longitude: -46.6333,
        resumeLatitude: -23.5510,
        resumeLongitude: -46.6340,
        durationSeconds: 60,
        timestamp: DateTime.now().toIso8601String(),
      );

      final restored = AutoPauseEvent.fromMap(autoPause.toMap());

      expect(restored.resumeLatitude, -23.5510);
      expect(restored.resumeLongitude, -46.6340);
      expect(restored.resumeLocation, const LatLng(-23.5510, -46.6340));
    });

    test('RunModel handles autoPauses list correctly', () {
      final now = DateTime.now();
      final autoPause = AutoPauseEvent(
        latitude: -23.5505,
        longitude: -46.6333,
        durationSeconds: 90,
        timestamp: now.toIso8601String(),
      );

      final run = RunModel(
        id: 'test_123',
        date: now,
        distanceKm: 5.0,
        durationSeconds: 1500,
        pausedDurationSeconds: 90,
        pace: '5:00',
        calories: 350,
        autoPauses: [autoPause],
      );

      expect(run.autoPauses.length, 1);
      expect(run.autoPauses.first.durationSeconds, 90);

      final map = run.toMap();
      final restoredRun = RunModel.fromMap(map);

      expect(restoredRun.autoPauses.length, 1);
      expect(restoredRun.autoPauses.first.durationSeconds, 90);
      expect(restoredRun.autoPauses.first.latitude, -23.5505);
    });
  });
}
