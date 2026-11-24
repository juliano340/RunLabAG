import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:runlabag/core/services/theme_service.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/features/history/presentation/screens/run_detail_screen.dart';

void main() {
  // Regressão: o initState chegou a ficar com "_run = _run" (auto-atribuição),
  // o que gerava LateInitializationError e tela vermelha ao abrir qualquer treino.
  testWidgets(
    'RunDetailScreen renderiza treino sem rota sem crash',
    (WidgetTester tester) async {
      final run = RunModel(
        id: 'test-run',
        date: DateTime(2026, 11, 17, 7, 30),
        distanceKm: 5.0,
        durationSeconds: 1800,
        pace: '6:00',
        calories: 350,
        route: const [],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeService(),
          child: MaterialApp(home: RunDetailScreen(run: run)),
        ),
      );

      // Primeiro frame + settle dos loads assíncronos (map style, marcadores).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('17/11/2026 às 07:30'), findsOneWidget);
      expect(find.text('5.00'), findsWidgets);
      expect(find.text('6:00/km'), findsWidgets);
    },
  );

  testWidgets(
    'RunDetailScreen renderiza treino com rota e splits sem crash',
    (WidgetTester tester) async {
      final run = RunModel(
        id: 'test-run-route',
        date: DateTime(2026, 11, 16, 18, 0),
        distanceKm: 3.0,
        durationSeconds: 1140,
        pace: '6:20',
        calories: 210,
        route: const [
          [
            LatLng(-23.5505, -46.6333),
            LatLng(-23.5510, -46.6340),
          ],
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeService(),
          child: MaterialApp(home: RunDetailScreen(run: run)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('16/11/2026 às 18:00'), findsOneWidget);
    },
  );

  testWidgets(
    'RunDetailScreen renderiza mapa colorido por pace sem crash',
    (WidgetTester tester) async {
      final run = RunModel(
        id: 'test-run-pace',
        date: DateTime(2026, 11, 16, 18, 0),
        distanceKm: 0.33,
        durationSeconds: 402,
        pace: '20:10',
        calories: 23,
        route: const [
          [
            LatLng(-23.5505, -46.6333),
            LatLng(-23.5515, -46.6333),
            LatLng(-23.5525, -46.6333),
            LatLng(-23.5535, -46.6333),
          ],
        ],
        routeTimes: const [
          [0, 134, 268, 402],
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeService(),
          child: MaterialApp(home: RunDetailScreen(run: run)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Sem crash e com a legenda de faixas visível (rota 100% caminhada).
      expect(tester.takeException(), isNull);
      expect(find.text('16/11/2026 às 18:00'), findsOneWidget);
      expect(find.text('Caminhada 100%'), findsOneWidget);
    },
  );
}
