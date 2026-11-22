import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runlabag/core/domain/models/run_model.dart';

void main() {
  group('RunModel copyWith', () {
    final base = RunModel(
      id: 'run-1',
      date: DateTime(2026, 11, 17, 7, 30),
      distanceKm: 5.0,
      durationSeconds: 1800,
      pace: '6:00',
      calories: 350,
      route: const [
        [LatLng(-23.5505, -46.6333), LatLng(-23.5605, -46.6433)],
      ],
      type: 'Corrida',
      mood: '🙂',
    );

    test('não altera nada quando nenhum campo é passado', () {
      final copy = base.copyWith();

      expect(copy.id, base.id);
      expect(copy.distanceKm, base.distanceKm);
      expect(copy.pace, base.pace);
      expect(copy.calories, base.calories);
      expect(copy.route, base.route);
      expect(copy.type, base.type);
      expect(copy.mood, base.mood);
      expect(copy.date, base.date);
      expect(copy.durationSeconds, base.durationSeconds);
    });

    test('substitui apenas os campos informados', () {
      final novaRota = [
        [const LatLng(-23.5505, -46.6333), const LatLng(-23.5510, -46.6340)],
      ];

      final copy = base.copyWith(
        distanceKm: 4.5,
        pace: '6:40',
        calories: 315,
        route: novaRota,
      );

      expect(copy.id, 'run-1');
      expect(copy.distanceKm, 4.5);
      expect(copy.pace, '6:40');
      expect(copy.calories, 315);
      expect(copy.route, novaRota);
      // Campos não informados permanecem intactos.
      expect(copy.type, 'Corrida');
      expect(copy.mood, '🙂');
      expect(copy.durationSeconds, 1800);
      expect(copy.date, base.date);
    });

    test('roundtrip toMap/fromMap preserva a rota editada', () {
      final novaRota = [
        [const LatLng(-23.5505, -46.6333), const LatLng(-23.5510, -46.6340)],
      ];
      final copy = base.copyWith(route: novaRota);

      final restored = RunModel.fromMap(copy.toMap());

      expect(restored.id, 'run-1');
      expect(restored.route.length, 1);
      expect(restored.route.first.length, 2);
      expect(restored.route.first.first, const LatLng(-23.5505, -46.6333));
      expect(restored.route.first.last, const LatLng(-23.5510, -46.6340));
    });
  });

  group('RunModel routeTimes (tempos por ponto)', () {
    final run = RunModel(
      id: 'run-times',
      date: DateTime(2026, 11, 17, 7, 30),
      distanceKm: 1.0,
      durationSeconds: 420,
      pace: '7:00',
      calories: 70,
      route: const [
        [LatLng(-23.5505, -46.6333), LatLng(-23.5510, -46.6340)],
      ],
      routeTimes: const [
        [0, 420],
      ],
    );

    test('roundtrip preserva os tempos por ponto', () {
      final restored = RunModel.fromMap(run.toMap());

      expect(restored.routeTimes, [
        [0, 420],
      ]);
    });

    test('formato antigo (sem t) decodifica com routeTimes vazio', () {
      final map = run.toMap();
      // Simula um treino gravado antes da feature: remove o 't' do JSON.
      final List routeJson = jsonDecode(map['route'] as String);
      for (final segment in routeJson) {
        for (final p in segment) {
          p.remove('t');
        }
      }
      map['route'] = jsonEncode(routeJson);

      final restored = RunModel.fromMap(map);

      expect(restored.route.length, 1);
      expect(restored.route.first.length, 2);
      expect(restored.routeTimes, isEmpty);
    });

    test('trocar rota sem informar tempos limpa os tempos antigos', () {
      final novaRota = [
        [const LatLng(-23.5505, -46.6333), const LatLng(-23.5510, -46.6340)],
      ];

      final copy = run.copyWith(route: novaRota);

      expect(copy.route, novaRota);
      expect(copy.routeTimes, isEmpty);
    });

    test('trocar rota informando tempos mantém os novos tempos', () {
      final novaRota = [
        [const LatLng(-23.5505, -46.6333), const LatLng(-23.5510, -46.6340)],
      ];

      final copy = run.copyWith(route: novaRota, routeTimes: const [
        [0, 300],
      ]);

      expect(copy.routeTimes, const [
        [0, 300],
      ]);
    });
  });
}
