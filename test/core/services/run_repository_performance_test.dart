import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runlabag/core/services/database_helper.dart';
import 'package:runlabag/core/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/run_split.dart';

/// Garante a regra que mantém o app leve: listas e totais **não** leem a
/// coluna `route`, e a rota só é decodificada quando pedida explicitamente.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.databaseFileName = 'runlab_perf_test.db';
    final dbPath =
        '${await databaseFactory.getDatabasesPath()}/runlab_perf_test.db';
    await databaseFactory.deleteDatabase(dbPath);
    DatabaseHelper.resetForTest();
  });

  tearDown(() async {
    DatabaseHelper.resetForTest();
    DatabaseHelper.databaseFileName = 'runlab_database.db';
  });

  RunModel runWithPoints(String id, DateTime date, {int points = 400}) {
    final route = [
      List.generate(
        points,
        (i) => LatLng(-23.55 + i * 0.00001, -46.63 + i * 0.00001),
      ),
    ];
    return RunModel(
      id: id,
      date: date,
      distanceKm: 5.0,
      durationSeconds: 1800,
      pace: '6:00',
      calories: 300,
      route: route,
      routeTimes: [
        List.generate(points, (i) => i * 4),
      ],
      type: 'Corrida',
      splits: [RunSplit(timeSeconds: 360, calories: 60)],
    );
  }

  test('getRunSummaries não decodifica a rota', () async {
    final db = DatabaseService();
    await db.saveRun(runWithPoints('a', DateTime(2026, 1, 1)));

    final summaries = await db.getRunSummaries();

    expect(summaries, hasLength(1));
    expect(summaries.first.id, 'a');
    expect(summaries.first.route, isEmpty);
    expect(summaries.first.routeTimes, isEmpty);
    // Resumo ainda entrega o que a UI precisa.
    expect(summaries.first.distanceKm, 5.0);
    expect(summaries.first.splits, hasLength(1));
  });

  test('getRunById devolve a rota completa', () async {
    final db = DatabaseService();
    await db.saveRun(runWithPoints('full', DateTime(2026, 1, 2), points: 120));

    final run = await db.getRunById('full');

    expect(run, isNotNull);
    expect(run!.hasRoute, isTrue);
    expect(run.route.first, hasLength(120));
    expect(run.routeTimes.first, hasLength(120));
  });

  test('getTotals agrega em SQL sem carregar treinos', () async {
    final db = DatabaseService();
    await db.saveRun(runWithPoints('a', DateTime(2026, 1, 1)));
    await db.saveRun(runWithPoints('b', DateTime(2026, 1, 3)));

    final totals = await db.getTotals();

    expect(totals.runCount, 2);
    expect(totals.totalDistanceKm, 10.0);
    expect(totals.totalSeconds, 3600);
    expect(totals.totalCalories, 600);
  });

  test('faixas de ritmo são somadas por período', () async {
    final db = DatabaseService();
    await db.saveRun(runWithPoints('a', DateTime(2026, 2, 10)));
    await db.savePaceZones('a', {'running': 4.0, 'fast': 1.0});

    final totals = await db.getPaceZoneTotals(
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 16),
    );

    expect(totals['running'], 4.0);
    expect(totals['fast'], 1.0);
  });

  test('treino ativo: metadados no boot não carregam a rota', () async {
    final db = DatabaseService();
    await db.saveActiveRunMeta({
      'startTime': DateTime(2026, 3, 1).toIso8601String(),
      'distanceKm': 1.2,
      'secondsElapsed': 400,
      'isPaused': 0,
      'finished': 0,
    });
    await db.saveActiveRunRoute(jsonEncode([
      [
        {'lat': -23.5, 'lng': -46.6},
      ],
    ]));

    final meta = await db.getActiveRunMeta();
    expect(meta, isNotNull);
    expect(meta!.containsKey('route'), isFalse);
    expect(meta['secondsElapsed'], 400);

    final full = await db.getActiveRun();
    expect(full!['route'], isNotNull);

    await db.clearActiveRun();
    expect(await db.getActiveRunMeta(), isNull);
  });

  test('resumo grande (500 treinos) responde rápido e sem rota', () async {
    final db = await DatabaseHelper.database;
    final batch = db.batch();
    for (var i = 0; i < 500; i++) {
      final run = runWithPoints('run_$i', DateTime(2026, 1, 1).add(Duration(days: i)));
      batch.insert('runs', run.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    final stopwatch = Stopwatch()..start();
    final summaries = await DatabaseService().getRunSummaries();
    stopwatch.stop();

    expect(summaries, hasLength(500));
    expect(summaries.every((r) => r.route.isEmpty), isTrue);
    // Folga generosa: o objetivo é não decodificar 500 rotas de 400 pontos.
    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });
}
