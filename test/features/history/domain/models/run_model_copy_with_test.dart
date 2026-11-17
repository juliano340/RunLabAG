import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runlabag/features/history/domain/models/run_model.dart';

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
}
