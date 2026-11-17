import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/theme/app_colors.dart';
import 'package:runlabag/features/analytics/domain/models/pace_series_point.dart';
import 'package:runlabag/features/analytics/domain/services/pace_series_service.dart';
import 'package:runlabag/features/analytics/presentation/widgets/pace_summary_strip.dart';
import 'package:runlabag/features/analytics/presentation/widgets/pace_trend_chart.dart';
import 'package:runlabag/features/analytics/presentation/widgets/volume_bar_chart.dart';

/// Série parecida com a real: muitas semanas sem treino no meio, paces altos.
List<PaceSeriesPoint> _buildSeries() {
  // Mais antigo → mais recente.
  const entries = <(double km, int runs, double pace)>[
    (3.2, 1, 15.6),
    (0, 0, 0),
    (5.0, 1, 14.2),
    (0, 0, 0),
    (4.4, 1, 13.4),
    (0, 0, 0),
    (0, 0, 0),
    (6.1, 2, 12.9),
    (0, 0, 0),
    (10.1, 2, 12.45),
    (0, 0, 0),
    (10.1, 2, 12.45),
  ];

  final base = DateTime(2026, 8, 17);
  return [
    for (var i = 0; i < entries.length; i++)
      PaceSeriesPoint(
        periodId: '2026-W$i',
        type: TrendPeriodType.week,
        startDate: base.add(Duration(days: 7 * i)),
        endDate: base
            .add(Duration(days: 7 * i))
            .add(const Duration(days: 6, hours: 23, minutes: 59)),
        distanceKm: entries[i].$1,
        durationSeconds: (entries[i].$1 * entries[i].$3 * 60).round(),
        runCount: entries[i].$2,
        goalKm: 20,
      ),
  ];
}

void main() {
  final series = _buildSeries();
  final summary = PaceSeriesService.summarize(series);

  Future<void> pumpCharts(WidgetTester tester, {required bool dark}) async {
    // Tela estreita: é onde rótulos e chips costumam estourar.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // O google_fonts tenta baixar Outfit em teste e falha (ambiente sem rede):
    // esses erros assíncronos não afetam o layout verificado aqui.
    await _ignoreFontFetchErrors(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(
            backgroundColor:
                dark ? AppColors.background : AppColors.backgroundLight,
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PaceSummaryStrip(summary: summary),
                      const SizedBox(height: 12),
                      PaceTrendChart(points: series),
                      const SizedBox(height: 20),
                      VolumeBarChart(points: series),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets('gráficos renderizam sem overflow em 360dp (tema escuro)',
      (tester) async {
    await pumpCharts(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.byType(PaceTrendChart), findsOneWidget);
    expect(find.byType(VolumeBarChart), findsOneWidget);
  });

  testWidgets('gráficos renderizam sem overflow em 360dp (tema claro)',
      (tester) async {
    await pumpCharts(tester, dark: false);
    expect(tester.takeException(), isNull);
  });
}

/// Executa [body] ignorando falhas de download de fonte (o ambiente de teste
/// não tem rede).
Future<void> _ignoreFontFetchErrors(Future<void> Function() body) {
  final completer = Completer<void>();
  runZonedGuarded(
    () async {
      try {
        await body();
        if (!completer.isCompleted) completer.complete();
      } catch (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      }
    },
    (error, stackTrace) {},
  );
  return completer.future;
}
