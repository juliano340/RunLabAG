import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/domain/services/pace_zone_service.dart';
import 'package:runlabag/features/history/presentation/widgets/pace_distribution_card.dart';

void main() {
  testWidgets(
    'PaceDistributionCard renderiza rosquinha com percentuais e KPI central',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PaceDistributionCard(
              distanceByZoneKm: {
                PaceZone.walking: 1.0,
                PaceZone.running: 2.0,
                PaceZone.fast: 1.0,
              },
              totalKm: 4.0,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // Título e KPI central.
      expect(find.text('DISTRIBUIÇÃO DE RITMO'), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('km'), findsOneWidget);

      // Percentuais por faixa (distâncias: 1/4, 2/4, 1/4).
      expect(find.text('Caminhada 25%'), findsOneWidget);
      expect(find.text('Corrida 50%'), findsOneWidget);
      expect(find.text('Acelerando 25%'), findsOneWidget);

      // Faixa sem distância não aparece na legenda.
      expect(find.text('Muito lento 0%'), findsNothing);
    },
  );

  testWidgets(
    'PaceDistributionCard sem dados não renderiza nada',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PaceDistributionCard(
              distanceByZoneKm: {},
              totalKm: 0,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('DISTRIBUIÇÃO DE RITMO'), findsNothing);
    },
  );
}
