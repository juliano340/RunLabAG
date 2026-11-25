import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/data/repositories/achievement_repository.dart';
import 'package:runlabag/core/data/repositories/user_data_reset_repository.dart';
import 'package:runlabag/core/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.databaseFileName = 'runlab_user_repos_test.db';
    final path =
        '${await databaseFactory.getDatabasesPath()}/runlab_user_repos_test.db';
    await databaseFactory.deleteDatabase(path);
    DatabaseHelper.resetForTest();
  });

  tearDown(() async {
    final db = await DatabaseHelper.database;
    await db.close();
    DatabaseHelper.resetForTest();
    DatabaseHelper.databaseFileName = 'runlab_database.db';
  });

  test('AchievementRepository persiste e não duplica conquistas', () async {
    final repository = SqfliteAchievementRepository();
    await repository.saveAchievement(
      id: 'first_run',
      title: 'Primeiro Passo',
      description: 'Primeira corrida',
      iconCode: 123,
    );
    await repository.saveAchievement(
      id: 'first_run',
      title: 'Duplicado',
      description: 'Não deve substituir',
      iconCode: 999,
    );

    final earned = await repository.getEarnedAchievements();
    expect(earned, hasLength(1));
    expect(earned.single.id, 'first_run');
    expect(earned.single.title, 'Primeiro Passo');
    expect((await repository.getLastAchievement())?.id, 'first_run');
  });

  test('reset limpa dados e restaura distâncias padrão', () async {
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
    await db.insert('monitored_distances', {'distanceKm': 42.0});

    await SqfliteUserDataResetRepository().resetAllData();

    expect(await db.query('user_profile'), isEmpty);
    expect(await db.query('runs'), isEmpty);
    expect(await db.query('monitored_distances'), hasLength(4));
  });
}
