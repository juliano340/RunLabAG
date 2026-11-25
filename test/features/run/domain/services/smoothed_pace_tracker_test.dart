import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runlabag/features/run/domain/services/smoothed_pace_tracker.dart';

Position _position(DateTime timestamp, double latitude) {
  return Position(
    latitude: latitude,
    longitude: -46.63,
    timestamp: timestamp,
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 3,
    speedAccuracy: 0,
  );
}

void main() {
  test('pace só é publicado após cinco pontos', () {
    final tracker = SmoothedPaceTracker();
    final start = DateTime(2026, 11, 24);

    for (var i = 0; i < 4; i++) {
      tracker.add(
        _position(start.add(Duration(seconds: i * 30)), -23.55 + i * 0.0009),
      );
      expect(tracker.value, '0:00');
    }

    tracker.add(_position(start.add(const Duration(seconds: 120)), -23.5536));

    expect(tracker.value, isNot('0:00'));
  });

  test('janela mantém no máximo trinta pontos', () {
    final tracker = SmoothedPaceTracker();
    final start = DateTime(2026, 11, 24);

    for (var i = 0; i < 40; i++) {
      tracker.add(
        _position(start.add(Duration(seconds: i * 30)), -23.55 + i * 0.0009),
      );
    }

    expect(
      tracker.lastPosition?.timestamp,
      start.add(const Duration(minutes: 19, seconds: 30)),
    );
    tracker.reset();
    expect(tracker.value, '0:00');
    expect(tracker.lastPosition, isNull);
  });
}
