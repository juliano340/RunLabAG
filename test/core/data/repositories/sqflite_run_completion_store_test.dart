import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runlabag/core/data/repositories/sqflite_run_completion_store.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late SqfliteRunCompletionStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.databaseFileName = 'runlab_completion_test.db';
    final path =
        '${await databaseFactory.getDatabasesPath()}/runlab_completion_test.db';
    await databaseFactory.deleteDatabase(path);
    DatabaseHelper.resetForTest();
    store = SqfliteRunCompletionStore();

    final db = await DatabaseHelper.database;
    await db.insert('active_run', {
      'id': 1,
      'startTime': DateTime(2026, 11, 24, 10).toIso8601String(),
      'distanceKm': 5,
      'secondsElapsed': 1800,
      'isPaused': 1,
      'finished': 1,
    });
    await db.insert('active_run_route', {
      'id': 1,
      'route': jsonEncode([
        [
          {'lat': -23.55, 'lng': -46.63, 't': 0},
          {'lat': -23.56, 'lng': -46.64, 't': 1800},
        ],
      ]),
    });
  });

  tearDown(() async {
    final db = await DatabaseHelper.database;
    await db.close();
    DatabaseHelper.resetForTest();
    DatabaseHelper.databaseFileName = 'runlab_database.db';
  });

  RunModel buildRun() => RunModel(
    id: 'completed-run',
    date: DateTime(2026, 11, 24, 10),
    distanceKm: 5,
    durationSeconds: 1800,
    pace: '6:00',
    calories: 300,
    route: const [
      [LatLng(-23.55, -46.63), LatLng(-23.56, -46.64)],
    ],
    routeTimes: const [
      [0, 1800],
    ],
  );

  test('salva treino, faixas e limpeza do rascunho juntos', () async {
    await store.saveCompletedRun(
      run: buildRun(),
      distanceByZone: {'running': 4, 'fast': 1},
    );

    final db = await DatabaseHelper.database;
    expect(await db.query('runs'), hasLength(1));
    expect(await db.query('active_run'), isEmpty);
    expect(await db.query('active_run_route'), isEmpty);
    final zones = await db.query('run_pace_zones');
    expect(zones, hasLength(2));
    expect(
      zones.firstWhere((row) => row['zone'] == 'running')['distanceKm'],
      4,
    );
  });

  test('repetir a confirmação não duplica o treino', () async {
    final run = buildRun();
    await store.saveCompletedRun(run: run, distanceByZone: {'running': 5});
    await store.saveCompletedRun(run: run, distanceByZone: {'running': 5});

    final db = await DatabaseHelper.database;
    expect(await db.query('runs'), hasLength(1));
    expect(await db.query('run_pace_zones'), hasLength(1));
  });

  test('falha na limpeza reverte também o treino e as faixas', () async {
    final db = await DatabaseHelper.database;
    await db.execute('''
      CREATE TRIGGER fail_active_delete
      BEFORE DELETE ON active_run
      BEGIN
        SELECT RAISE(ABORT, 'falha proposital');
      END
    ''');

    await expectLater(
      store.saveCompletedRun(run: buildRun(), distanceByZone: {'running': 5}),
      throwsA(isA<DatabaseException>()),
    );

    expect(await db.query('runs'), isEmpty);
    expect(await db.query('run_pace_zones'), isEmpty);
    expect(await db.query('active_run'), hasLength(1));
    expect(await db.query('active_run_route'), hasLength(1));
  });
}
