import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  static const databaseVersion = 20;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String dbPath = join(await getDatabasesPath(), 'runlab_database.db');
    return await openDatabase(
      dbPath,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE runs(id TEXT PRIMARY KEY, date TEXT, distanceKm REAL, durationSeconds INTEGER, pausedDurationSeconds INTEGER DEFAULT 0, pace TEXT, calories INTEGER, route TEXT, type TEXT, mood TEXT, splits TEXT)',
    );
    await db.execute(
      'CREATE TABLE user_profile(id TEXT PRIMARY KEY, name TEXT, age INTEGER, weight REAL, height REAL, profilePicturePath TEXT, weeklyGoal REAL, monthlyGoal REAL, waterGoal REAL DEFAULT 2000.0, lastGoalUpdate TEXT, kmNotificationsEnabled INTEGER DEFAULT 1)',
    );
    await db.execute(
      'CREATE TABLE achievements(id TEXT PRIMARY KEY, title TEXT, description TEXT, iconCode INTEGER, earnedDate TEXT)',
    );
    await db.execute(
      'CREATE TABLE active_run(id INTEGER PRIMARY KEY, startTime TEXT, distanceKm REAL, secondsElapsed INTEGER, pausedDurationSeconds INTEGER DEFAULT 0, lastKmNotified INTEGER, route TEXT, distanceGoal REAL, isPaused INTEGER, splits TEXT, targetTimeSeconds INTEGER)',
    );
    await db.execute(
      'CREATE TABLE monitored_distances(distanceKm REAL PRIMARY KEY)',
    );
    await db.execute(
      'CREATE TABLE water_intake(id INTEGER PRIMARY KEY AUTOINCREMENT, amount INTEGER, timestamp TEXT)',
    );
    await db.execute(
      'CREATE TABLE training_plans(id TEXT PRIMARY KEY, title TEXT, description TEXT, totalWeeks INTEGER, level INTEGER, goal TEXT)',
    );
    await db.execute(
      'CREATE TABLE plan_sessions(id TEXT PRIMARY KEY, planId TEXT, week INTEGER, day INTEGER, title TEXT, type INTEGER, targetDistance REAL, description TEXT)',
    );
    await db.execute(
      'CREATE TABLE user_training_enrollments(planId TEXT, startDate TEXT, currentWeek INTEGER, currentDay INTEGER, isActive INTEGER)',
    );
    await db.execute(
      'CREATE TABLE strength_workouts(id TEXT PRIMARY KEY, name TEXT, date INTEGER, payload TEXT)',
    );
    await db.execute(
      'CREATE TABLE exercise_dictionary(id TEXT PRIMARY KEY, name TEXT, muscleGroupId TEXT)',
    );
    await db.execute(
      'CREATE TABLE goal_history(periodId TEXT PRIMARY KEY, goalType TEXT, goalValue REAL)',
    );
    await db.execute(
      'CREATE TABLE workout_blocks(id TEXT PRIMARY KEY, name TEXT, description TEXT)',
    );
    await db.execute(
      'CREATE TABLE block_exercises(id TEXT PRIMARY KEY, blockId TEXT, name TEXT, defaultSets INTEGER, defaultReps TEXT, defaultWeight REAL, isTimeBased INTEGER, orderIndex INTEGER)',
    );
    await db.execute(
      'CREATE TABLE strength_workout_templates(id TEXT PRIMARY KEY, name TEXT)',
    );
    await db.execute(
      'CREATE TABLE template_items(id TEXT PRIMARY KEY, templateId TEXT, type TEXT, itemId TEXT, orderIndex INTEGER, overrides TEXT)',
    );
    for (double dist in [1.0, 5.0, 10.0, 15.0]) {
      await db.insert('monitored_distances', {'distanceKm': dist});
    }
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE runs ADD COLUMN route TEXT');
    }
    if (oldVersion < 3) {
      await db.execute(
        'CREATE TABLE user_profile(id TEXT PRIMARY KEY, name TEXT, age INTEGER, weight REAL, height REAL, profilePicturePath TEXT)',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'CREATE TABLE achievements(id TEXT PRIMARY KEY, title TEXT, description TEXT, iconCode INTEGER, earnedDate TEXT)',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'CREATE TABLE active_run(id INTEGER PRIMARY KEY, startTime TEXT, distanceKm REAL, secondsElapsed INTEGER, lastKmNotified INTEGER, route TEXT, distanceGoal REAL, isPaused INTEGER)',
      );
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN weeklyGoal REAL');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE runs ADD COLUMN type TEXT');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE runs ADD COLUMN mood TEXT');
    }
    if (oldVersion < 9) {
      var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='monitored_distances'");
      if (tables.isEmpty) {
        await db.execute('CREATE TABLE monitored_distances(distanceKm REAL PRIMARY KEY)');
        for (double dist in [1.0, 5.0, 10.0, 15.0]) {
          await db.insert('monitored_distances', {'distanceKm': dist}, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN monthlyGoal REAL DEFAULT 80.0');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE runs ADD COLUMN splits TEXT');
      await db.execute('ALTER TABLE active_run ADD COLUMN splits TEXT');
    }
    if (oldVersion < 12) {
      await db.execute(
        'CREATE TABLE water_intake(id INTEGER PRIMARY KEY AUTOINCREMENT, amount INTEGER, timestamp TEXT)',
      );
      await db.execute('ALTER TABLE user_profile ADD COLUMN waterGoal REAL DEFAULT 2000.0');
    }
    if (oldVersion < 13) {
      await db.execute(
        'CREATE TABLE training_plans(id TEXT PRIMARY KEY, title TEXT, description TEXT, totalWeeks INTEGER, level INTEGER, goal TEXT)',
      );
      await db.execute(
        'CREATE TABLE plan_sessions(id TEXT PRIMARY KEY, planId TEXT, week INTEGER, day INTEGER, title TEXT, type INTEGER, targetDistance REAL, description TEXT)',
      );
      await db.execute(
        'CREATE TABLE user_training_enrollments(planId TEXT, startDate TEXT, currentWeek INTEGER, currentDay INTEGER, isActive INTEGER)',
      );
    }
    if (oldVersion < 14) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN lastGoalUpdate TEXT');
    }
    if (oldVersion < 15) {
      await db.execute(
        'CREATE TABLE strength_workouts(id TEXT PRIMARY KEY, name TEXT, date INTEGER, payload TEXT)',
      );
      await db.execute(
        'CREATE TABLE exercise_dictionary(id TEXT PRIMARY KEY, name TEXT, muscleGroupId TEXT)',
      );
    }
    if (oldVersion < 16) {
      await db.execute(
        'CREATE TABLE goal_history(periodId TEXT PRIMARY KEY, goalType TEXT, goalValue REAL)',
      );
    }
    if (oldVersion < 17) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN kmNotificationsEnabled INTEGER DEFAULT 1');
    }
    if (oldVersion < 18) {
      await db.execute(
        'CREATE TABLE workout_blocks(id TEXT PRIMARY KEY, name TEXT, description TEXT)',
      );
      await db.execute(
        'CREATE TABLE block_exercises(id TEXT PRIMARY KEY, blockId TEXT, name TEXT, defaultSets INTEGER, defaultReps TEXT, defaultWeight REAL, isTimeBased INTEGER, orderIndex INTEGER)',
      );
      await db.execute(
        'CREATE TABLE strength_workout_templates(id TEXT PRIMARY KEY, name TEXT)',
      );
      await db.execute(
        'CREATE TABLE template_items(id TEXT PRIMARY KEY, templateId TEXT, type TEXT, itemId TEXT, orderIndex INTEGER, overrides TEXT)',
      );
    }
    if (oldVersion < 19) {
      await db.execute('ALTER TABLE active_run ADD COLUMN targetTimeSeconds INTEGER');
    }
    if (oldVersion < 20) {
      await db.execute('ALTER TABLE runs ADD COLUMN pausedDurationSeconds INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE active_run ADD COLUMN pausedDurationSeconds INTEGER DEFAULT 0');
    }
  }
}
