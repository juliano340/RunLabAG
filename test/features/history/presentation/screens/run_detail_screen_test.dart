import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:runlabag/core/services/theme_service.dart';
import 'package:runlabag/features/history/domain/models/run_model.dart';
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
      expect(find.text('Treino de 17/11/2026 às 07:30'), findsOneWidget);
      expect(find.text('5.00'), findsWidgets);
      expect(find.text('6:00'), findsWidgets);
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
      expect(find.text('Treino de 16/11/2026 às 18:00'), findsOneWidget);
    },
  );
}
