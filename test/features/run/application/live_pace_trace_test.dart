import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runlabag/core/domain/services/pace_zone_service.dart';
import 'package:runlabag/features/run/application/live_pace_trace.dart';

void main() {
  ({List<LatLng> points, List<int> times, double distanceKm}) buildRoute({
    int pointCount = 600,
    double startLatitude = -23.55,
    double startLongitude = -46.63,
    int startTime = 0,
  }) {
    final points = <LatLng>[
      for (var i = 0; i < pointCount; i++)
        LatLng(startLatitude + i * 0.0001, startLongitude + i * 0.0001),
    ];
    final times = <int>[for (var i = 0; i < pointCount; i++) startTime + i * 7];
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += PaceZoneService.distanceMeters(points[i - 1], points[i]);
    }
    return (points: points, times: times, distanceKm: meters / 1000);
  }

  void expectSameResult(PaceZoneResult expected, PaceZoneResult actual) {
    expect(actual.segments, hasLength(expected.segments.length));
    for (var i = 0; i < expected.segments.length; i++) {
      final expectedSegment = expected.segments[i];
      final actualSegment = actual.segments[i];
      expect(actualSegment.color, expectedSegment.color);
      expect(actualSegment.zone, expectedSegment.zone);
      expect(actualSegment.points, hasLength(expectedSegment.points.length));
      for (var j = 0; j < expectedSegment.points.length; j++) {
        expect(
          actualSegment.points[j].latitude,
          closeTo(expectedSegment.points[j].latitude, 1e-12),
        );
        expect(
          actualSegment.points[j].longitude,
          closeTo(expectedSegment.points[j].longitude, 1e-12),
        );
      }
    }
    for (final zone in PaceZone.values) {
      expect(
        actual.distanceByZoneKm[zone] ?? 0,
        closeTo(expected.distanceByZoneKm[zone] ?? 0, 1e-9),
      );
    }
  }

  test('acumulador incremental converge para a análise completa', () {
    final route = buildRoute();
    final center = PaceZoneService.centerSecPerKm(
      runAvgSecPerKm: route.times.last / route.distanceKm,
    );
    final expected = PaceZoneService.analyze(
      route: [route.points],
      routeTimes: [route.times],
      distanceKm: route.distanceKm,
      durationSeconds: route.times.last,
      splits: const [],
    );

    final trace = LivePaceTrace();
    for (var i = 0; i < route.points.length; i++) {
      trace.addPoint(route.points[i], route.times[i], startsNewSegment: i == 0);
    }

    expectSameResult(expected, trace.build(centerSecPerKm: center));
    expect(trace.completedChunkCount, lessThan(route.points.length ~/ 2));
  });

  test('builds intermediários não congelam nem perdem o chunk final', () {
    final route = buildRoute(pointCount: 120);
    final center = PaceZoneService.centerSecPerKm(
      runAvgSecPerKm: route.times.last / route.distanceKm,
    );
    final expected = PaceZoneService.analyze(
      route: [route.points],
      routeTimes: [route.times],
      distanceKm: route.distanceKm,
      durationSeconds: route.times.last,
      splits: const [],
    );

    final trace = LivePaceTrace();
    for (var i = 0; i < route.points.length; i++) {
      trace.addPoint(route.points[i], route.times[i], startsNewSegment: i == 0);
      if (i == 2 || i == 17 || i == 63) {
        trace.build(centerSecPerKm: center);
      }
    }

    expectSameResult(expected, trace.build(centerSecPerKm: center));
  });

  test('pausa cria segmentos independentes sem conectar a rota', () {
    final first = buildRoute(pointCount: 90);
    final second = buildRoute(
      pointCount: 70,
      startLatitude: -23.56,
      startLongitude: -46.64,
      startTime: first.times.last + 120,
    );
    final duration = second.times.last;
    final distanceKm = first.distanceKm + second.distanceKm;
    final center = PaceZoneService.centerSecPerKm(
      runAvgSecPerKm: duration / distanceKm,
    );
    final expected = PaceZoneService.analyze(
      route: [first.points, second.points],
      routeTimes: [first.times, second.times],
      distanceKm: distanceKm,
      durationSeconds: duration,
      splits: const [],
    );

    final trace = LivePaceTrace();
    for (var i = 0; i < first.points.length; i++) {
      trace.addPoint(first.points[i], first.times[i], startsNewSegment: i == 0);
    }
    for (var i = 0; i < second.points.length; i++) {
      trace.addPoint(
        second.points[i],
        second.times[i],
        startsNewSegment: i == 0,
      );
    }

    expectSameResult(expected, trace.build(centerSecPerKm: center));
  });
}
