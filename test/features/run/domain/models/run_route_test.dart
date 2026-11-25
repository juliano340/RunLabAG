import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runlabag/features/run/domain/models/run_route.dart';

void main() {
  test('roundtrip preserva segmentos e tempos paralelos', () {
    final route = RunRoute()
      ..append(const LatLng(-23.55, -46.63), 12)
      ..startSegment()
      ..append(const LatLng(-23.56, -46.64), 30);

    final restored = RunRoute.fromJson(route.toJson());

    expect(restored.trackPointTimes, isTrue);
    expect(restored.points, hasLength(2));
    expect(restored.points.first.single, const LatLng(-23.55, -46.63));
    expect(restored.times, [
      [12],
      [30],
    ]);
    expect(jsonDecode(route.toJson()), isA<List>());
  });

  test('formato plano legado não inventa tempos por ponto', () {
    final route = RunRoute.fromJson(
      jsonEncode([
        {'lat': -23.55, 'lng': -46.63},
        {'lat': -23.56, 'lng': -46.64},
      ]),
    );

    expect(route.trackPointTimes, isFalse);
    expect(route.points.single, hasLength(2));
    route.append(const LatLng(-23.57, -46.65), 99);
    expect(route.times, isEmpty);
  });

  test('rota aninhada sem qualquer tempo volta ao modo legado', () {
    final route = RunRoute.fromJson(
      jsonEncode([
        [
          {'lat': -23.55, 'lng': -46.63, 't': 10},
          {'lat': -23.56, 'lng': -46.64},
        ],
      ]),
    );

    expect(route.trackPointTimes, isFalse);
    expect(route.points.single, hasLength(2));
    expect(route.times, isEmpty);
  });

  test('segmento vazio restaurado recebe o primeiro ponto e seu tempo', () {
    final route = RunRoute.fromJson('[[]]');

    route.append(const LatLng(-23.55, -46.63), 42);

    expect(route.points, hasLength(1));
    expect(route.times, [
      [42],
    ]);
  });

  test('JSON inválido não derruba a restauração', () {
    final route = RunRoute.fromJson('{inválido}');

    expect(route.points, isEmpty);
    expect(route.times, isEmpty);
    expect(route.trackPointTimes, isTrue);
  });
}
