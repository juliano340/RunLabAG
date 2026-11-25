import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/data/repositories/sqflite_backup_store.dart';
import 'package:runlabag/core/domain/models/backup_snapshot.dart';
import 'package:runlabag/core/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late SqfliteBackupStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.databaseFileName = 'runlab_backup_store_test.db';
    final path =
        '${await databaseFactory.getDatabasesPath()}/runlab_backup_store_test.db';
    await databaseFactory.deleteDatabase(path);
    DatabaseHelper.resetForTest();
    store = SqfliteBackupStore();
  });

  tearDown(() async {
    final db = await DatabaseHelper.database;
    await db.close();
    DatabaseHelper.resetForTest();
    DatabaseHelper.databaseFileName = 'runlab_database.db';
  });

  test('snapshot v4 inclui tabelas antes ausentes', () async {
    final db = await DatabaseHelper.database;
    await db.insert('user_profile', {'id': 'current_user', 'name': 'Runner'});
    await db.insert('runs', {
      'id': 'run_1',
      'date': DateTime(2026, 11, 24).toIso8601String(),
      'distanceKm': 5.0,
      'durationSeconds': 1800,
      'pace': '6:00',
      'calories': 300,
      'route': '[]',
    });
    await db.insert('run_pace_zones', {
      'runId': 'run_1',
      'zone': 'running',
      'distanceKm': 5.0,
    });
    await db.insert('training_plans', {
      'id': 'plan_1',
      'title': 'Plano',
      'totalWeeks': 4,
    });
    await db.insert('plan_sessions', {
      'id': 'session_1',
      'planId': 'plan_1',
      'week': 1,
      'day': 1,
    });
    await db.insert('exercise_dictionary', {
      'id': 'exercise_1',
      'name': 'Agachamento',
      'muscleGroupId': 'legs',
    });

    final snapshot = await store.readSnapshot();

    expect(snapshot.version, 4);
    expect(snapshot.runs.single['id'], 'run_1');
    expect(snapshot.tables['paceZones'], hasLength(1));
    expect(snapshot.tables['trainingPlans'], hasLength(1));
    expect(snapshot.tables['planSessions'], hasLength(1));
    expect(snapshot.tables['exerciseDictionary'], hasLength(1));
  });

  test('roundtrip restaura dados e substitui tabelas sem PK', () async {
    final db = await DatabaseHelper.database;
    await db.insert('monitored_distances', {'distanceKm': 21.0});
    await db.insert('user_training_enrollments', {
      'planId': 'old',
      'startDate': DateTime(2026, 1, 1).toIso8601String(),
      'isActive': 1,
    });

    final snapshot = BackupSnapshot(
      version: 4,
      exportedAt: DateTime(2026, 11, 24),
      profile: {'id': 'current_user', 'name': 'Restaurado'},
      runs: [
        {
          'id': 'run_restored',
          'date': DateTime(2026, 11, 24).toIso8601String(),
          'distanceKm': 10.0,
          'durationSeconds': 3600,
          'pace': '6:00',
          'calories': 600,
          'route': '[]',
        },
      ],
      tables: {
        'monitoredDistances': [
          {'distanceKm': 42.0},
        ],
        'trainingEnrollments': [
          {
            'planId': 'new',
            'startDate': DateTime(2026, 11, 24).toIso8601String(),
            'isActive': 1,
          },
        ],
      },
    );

    await store.restoreSnapshot(snapshot);

    expect((await db.query('user_profile')).single['name'], 'Restaurado');
    expect((await db.query('runs')).single['id'], 'run_restored');
    expect(await db.query('monitored_distances'), hasLength(1));
    expect((await db.query('monitored_distances')).single['distanceKm'], 42.0);
    expect(await db.query('user_training_enrollments'), hasLength(1));
    expect(
      (await db.query('user_training_enrollments')).single['planId'],
      'new',
    );
  });

  test('falha no meio da restauração reverte todas as tabelas', () async {
    final db = await DatabaseHelper.database;
    await db.execute('''
      CREATE TRIGGER fail_achievement_insert
      BEFORE INSERT ON achievements
      BEGIN
        SELECT RAISE(ABORT, 'falha proposital');
      END
    ''');

    final snapshot = BackupSnapshot(
      version: 4,
      exportedAt: DateTime(2026, 11, 24),
      profile: {'id': 'current_user', 'name': 'Não deve restaurar'},
      runs: [
        {
          'id': 'run_rollback',
          'date': DateTime(2026, 11, 24).toIso8601String(),
          'distanceKm': 5.0,
          'durationSeconds': 1800,
          'pace': '6:00',
          'calories': 300,
          'route': '[]',
        },
      ],
      tables: {
        'achievements': [
          {'id': 'ach_1', 'title': 'Conquista'},
        ],
      },
    );

    await expectLater(
      store.restoreSnapshot(snapshot),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('user_profile'), isEmpty);
    expect(await db.query('runs'), isEmpty);
  });
}
