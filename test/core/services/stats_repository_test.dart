import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/data/read_model_cache.dart';
import 'package:runlabag/core/data/repositories/caching_run_repository.dart';
import 'package:runlabag/core/data/repositories/caching_stats_repository.dart';
import 'package:runlabag/core/data/repositories/caching_user_repository.dart';
import 'package:runlabag/core/data/repositories/run_repository.dart';
import 'package:runlabag/core/data/repositories/stats_repository.dart';
import 'package:runlabag/core/data/repositories/user_repository.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';
import 'package:runlabag/core/services/database_helper.dart';
import 'package:runlabag/core/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseService database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.databaseFileName = 'runlab_stats_test.db';
    final path =
        '${await databaseFactory.getDatabasesPath()}/runlab_stats_test.db';
    await databaseFactory.deleteDatabase(path);
    DatabaseHelper.resetForTest();

    final cache = ReadModelCache();
    final runs = CachingRunRepository(SqfliteRunRepository(), cache);
    final users = CachingUserRepository(SqfliteUserRepository(), cache);
    final stats = CachingStatsRepository(
      SqfliteStatsRepository(runRepository: runs, userRepository: users),
      cache,
    );
    database = DatabaseService(
      runRepository: runs,
      userRepository: users,
      statsRepository: stats,
    );
  });

  tearDown(() async {
    final db = await DatabaseHelper.database;
    await db.close();
    DatabaseHelper.resetForTest();
    DatabaseHelper.databaseFileName = 'runlab_database.db';
  });

  RunModel run(
    String id,
    DateTime date, {
    required double distanceKm,
    required int durationSeconds,
  }) {
    return RunModel(
      id: id,
      date: date,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      pace: '6:00',
      calories: 300,
    );
  }

  test(
    'getUserStats devolve números tipados e formatação consistente',
    () async {
      final now = DateTime.now();
      await database.saveRun(
        run(
          'a',
          now.subtract(const Duration(days: 2)),
          distanceKm: 5,
          durationSeconds: 1800,
        ),
      );
      await database.saveRun(
        run(
          'b',
          now.subtract(const Duration(days: 1)),
          distanceKm: 3,
          durationSeconds: 1200,
        ),
      );

      final stats = await database.getUserStats();

      expect(stats.totals.runCount, 2);
      expect(stats.totals.totalDistanceKm, 8);
      expect(stats.totals.totalSeconds, 3000);
      expect(stats.averagePaceSecondsPerKm, 375);
      expect(stats.formattedAveragePace, '6:15');
      expect(stats.formattedTotalDistance, '8.0');
    },
  );

  test('recordes e históricos preservam regras e não usam Maps', () async {
    final now = DateTime.now();
    await database.saveRun(
      run(
        'old',
        now.subtract(const Duration(days: 2)),
        distanceKm: 5,
        durationSeconds: 1500,
      ),
    );
    await database.saveRun(
      run(
        'new',
        now.subtract(const Duration(days: 1)),
        distanceKm: 5,
        durationSeconds: 1400,
      ),
    );
    await database.saveRun(
      run('zero', now, distanceKm: 10, durationSeconds: 0),
    );

    final records = await database.getPersonalRecords();
    expect(records.bests, hasLength(4));
    expect(records.recordFor(5)?.timeSeconds, 1400);
    expect(records.recordFor(10)?.timeSeconds, isNull);
    expect(records.longestDistance.distanceKm, 10);

    final history = await database.getRecordHistory(5);
    expect(history, hasLength(2));
    expect(history.first.timeSeconds, 1400);
    expect(history.first.improvementSeconds, 100);
  });

  test('cache compartilhado invalida após salvar treino e perfil', () async {
    final now = DateTime.now();
    await database.saveRun(run('a', now, distanceKm: 5, durationSeconds: 1500));
    expect(await database.getRunSummaries(), hasLength(1));
    expect(
      (await database.getPersonalRecords()).recordFor(5)?.timeSeconds,
      1500,
    );

    await database.saveRun(
      run(
        'b',
        now.add(const Duration(seconds: 1)),
        distanceKm: 5,
        durationSeconds: 1400,
      ),
    );
    expect(await database.getRunSummaries(), hasLength(2));
    expect(
      (await database.getPersonalRecords()).recordFor(5)?.timeSeconds,
      1400,
    );

    await database.saveUserProfile(
      UserProfile(name: 'Antigo', age: 30, weight: 70, height: 170),
    );
    expect(await (await database.database).query('user_profile'), hasLength(1));
    expect((await database.getUserProfile())?.name, 'Antigo');
    await database.saveUserProfile(
      UserProfile(name: 'Novo', age: 30, weight: 72, height: 170),
    );
    expect((await database.getUserProfile())?.name, 'Novo');
  });

  test('consistência tipada conta dias e sequência atual', () async {
    final now = DateTime.now();
    final today = now;
    await database.saveRun(
      run('today', today, distanceKm: 5, durationSeconds: 1500),
    );
    await database.saveRun(
      run(
        'yesterday',
        today.subtract(const Duration(days: 1)),
        distanceKm: 3,
        durationSeconds: 1200,
      ),
    );

    final consistency = await database.getConsistencyStats(
      today.subtract(const Duration(days: 3)),
    );

    expect(consistency.trainedDays, 2);
    expect(consistency.totalDays, 4);
    expect(consistency.currentStreak, 2);
    expect(consistency.bestStreak, 2);
  });
}
