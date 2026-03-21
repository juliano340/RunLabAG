import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path/path.dart';

class RunSplit {
  final int timeSeconds;
  final int calories;

  RunSplit({required this.timeSeconds, required this.calories});

  Map<String, dynamic> toMap() => {'t': timeSeconds, 'c': calories};
  factory RunSplit.fromMap(Map<String, dynamic> map) => RunSplit(
    timeSeconds: map['t'] ?? 0,
    calories: map['c'] ?? 0,
  );
}

class RunModel {
  final String id;
  final DateTime date;
  final double distanceKm;
  final int durationSeconds;
  final String pace;
  final int calories;
  final List<LatLng> route;
  final String type;
  final String mood;
  final List<RunSplit> splits; // Detalhes de cada km

  RunModel({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.durationSeconds,
    required this.pace,
    required this.calories,
    this.route = const [],
    this.type = 'Corrida',
    this.mood = '',
    this.splits = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'pace': pace,
      'calories': calories,
      'route': jsonEncode(route.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()),
      'type': type,
      'mood': mood,
      'splits': jsonEncode(splits.map((s) => s.toMap()).toList()),
    };
  }

  factory RunModel.fromMap(Map<String, dynamic> map) {
    List<dynamic> routeList = jsonDecode(map['route'] ?? '[]');
    List<dynamic> splitList = jsonDecode(map['splits'] ?? '[]');
    return RunModel(
      id: map['id'],
      date: DateTime.parse(map['date']),
      distanceKm: map['distanceKm'],
      durationSeconds: map['durationSeconds'],
      pace: map['pace'],
      calories: map['calories'],
      route: routeList.map((p) => LatLng(p['lat'], p['lng'])).toList(),
      type: map['type'] ?? 'Corrida',
      mood: map['mood'] ?? '',
      splits: splitList.map((s) {
        if (s is Map) return RunSplit.fromMap(s.cast<String, dynamic>());
        if (s is int) return RunSplit(timeSeconds: s, calories: 0);
        return RunSplit(timeSeconds: 0, calories: 0);
      }).toList(),
    );
  }
}

class UserProfile {
  final String name;
  final int age;
  final double weight;
  final double height;
  final String? profilePicturePath;
  final double weeklyGoal;
  final double monthlyGoal;
  final double waterGoal; // em ml

  UserProfile({
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    this.profilePicturePath,
    this.weeklyGoal = 20.0,
    this.monthlyGoal = 80.0,
    this.waterGoal = 2000.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 'current_user',
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'profilePicturePath': profilePicturePath,
      'weeklyGoal': weeklyGoal,
      'monthlyGoal': monthlyGoal,
      'waterGoal': waterGoal,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? 'Runner',
      age: map['age'] ?? 0,
      weight: map['weight'] ?? 0.0,
      height: map['height'] ?? 0.0,
      profilePicturePath: map['profilePicturePath'],
      weeklyGoal: map['weeklyGoal'] ?? 20.0,
      monthlyGoal: map['monthlyGoal'] ?? 80.0,
      waterGoal: map['waterGoal']?.toDouble() ?? 2000.0,
    );
  }

  double get bmi {
    if (height <= 0) return 0;
    return weight / ((height / 100) * (height / 100));
  }

  String get bmiStatus {
    double val = bmi;
    if (val < 18.5) return "Abaixo do peso";
    if (val < 25) return "Peso normal";
    if (val < 30) return "Sobrepeso";
    return "Obesidade";
  }
}

class DatabaseService {
  static Database? _database;

  static const _databaseVersion = 12;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'runlab_database.db');
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE runs(id TEXT PRIMARY KEY, date TEXT, distanceKm REAL, durationSeconds INTEGER, pace TEXT, calories INTEGER, route TEXT, type TEXT, mood TEXT, splits TEXT)',
        );
        await db.execute(
          'CREATE TABLE user_profile(id TEXT PRIMARY KEY, name TEXT, age INTEGER, weight REAL, height REAL, profilePicturePath TEXT, weeklyGoal REAL, monthlyGoal REAL)',
        );
        await db.execute(
          'CREATE TABLE achievements(id TEXT PRIMARY KEY, title TEXT, description TEXT, iconCode INTEGER, earnedDate TEXT)',
        );
        await db.execute(
          'CREATE TABLE active_run(id INTEGER PRIMARY KEY, startTime TEXT, distanceKm REAL, secondsElapsed INTEGER, lastKmNotified INTEGER, route TEXT, distanceGoal REAL, isPaused INTEGER, splits TEXT)',
        );
        await db.execute(
          'CREATE TABLE monitored_distances(distanceKm REAL PRIMARY KEY)',
        );
        await db.execute(
          'CREATE TABLE water_intake(id INTEGER PRIMARY KEY AUTOINCREMENT, amount INTEGER, timestamp TEXT)',
        );
        // Pre-populate defaults
        for (double dist in [1.0, 5.0, 10.0, 15.0]) {
          await db.insert('monitored_distances', {'distanceKm': dist});
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
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
      },
    );
  }

  // Achievement Methods
  Future<void> saveAchievement(String id, String title, String desc, int iconCode) async {
    final db = await database;
    await db.insert(
      'achievements',
      {
        'id': id,
        'title': title,
        'description': desc,
        'iconCode': iconCode,
        'earnedDate': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getEarnedAchievements() async {
    final db = await database;
    return await db.query('achievements');
  }

  Future<Map<String, dynamic>?> getLastAchievement() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('achievements', orderBy: 'earnedDate DESC', limit: 1);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  // Active Run Persistence (for recovery)
  Future<void> saveActiveRun(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'active_run',
      {...data, 'id': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getActiveRun() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('active_run', where: 'id = 1');
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> clearActiveRun() async {
    final db = await database;
    await db.delete('active_run', where: 'id = 1');
  }

  Future<void> saveRun(RunModel run) async {
    final db = await database;
    await db.insert(
      'runs',
      run.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RunModel>> getHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('runs', orderBy: 'date DESC');
    return List.generate(maps.length, (i) {
      return RunModel.fromMap(maps[i]);
    });
  }

  Future<RunModel?> getLastRun() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('runs', orderBy: 'date DESC', limit: 1);
    if (maps.isEmpty) return null;
    return RunModel.fromMap(maps.first);
  }

  Future<void> deleteRun(String id) async {
    final db = await database;
    await db.delete(
      'runs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final runs = await getHistory();
    double totalDistance = 0;
    int totalRuns = runs.length;
    int totalSeconds = 0;
    int totalCalories = 0;

    for (final run in runs) {
      totalDistance += run.distanceKm;
      totalSeconds += run.durationSeconds;
      totalCalories += run.calories;
    }

    String avgPace = '0:00';
    if (totalDistance > 0) {
      double paceInMinutes = (totalSeconds / 60) / totalDistance;
      int minutes = paceInMinutes.toInt();
      int seconds = ((paceInMinutes - minutes) * 60).toInt();
      avgPace = '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    return {
      'totalDistance': totalDistance.toStringAsFixed(1),
      'totalRuns': totalRuns.toString(),
      'avgPace': avgPace,
      'totalCalories': totalCalories >= 1000 
          ? '${(totalCalories / 1000).toStringAsFixed(1)}k' 
          : totalCalories.toString(),
    };
  }

  // Monitored Distances Management
  Future<List<double>> getMonitoredDistances() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('monitored_distances', orderBy: 'distanceKm ASC');
    return List.generate(maps.length, (i) => maps[i]['distanceKm'] as double);
  }

  Future<void> addMonitoredDistance(double distance) async {
    final db = await database;
    await db.insert('monitored_distances', {'distanceKm': distance}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeMonitoredDistance(double distance) async {
    final db = await database;
    await db.delete('monitored_distances', where: 'distanceKm = ?', whereArgs: [distance]);
  }

  Future<Map<String, dynamic>> getPersonalRecords() async {
    final runs = await getHistory();
    final monitored = await getMonitoredDistances();
    
    Map<String, Map<String, dynamic>> records = {};
    for (double dist in monitored) {
      String key = dist == 21.0975 ? '21km' : dist == 42.195 ? '42km' : '${dist.toStringAsFixed(dist == dist.toInt() ? 0 : 1)}km';
      records[key] = {'time': null, 'date': null, 'runId': null};
    }

    double longestDistance = 0;
    DateTime? longestDistanceDate;
    String? longestDistanceRunId;

    for (final run in runs) {
      // Logic for all-time bests for specific distances
      for (double targetDist in monitored) {
        if (run.distanceKm >= targetDist) {
          // Estimate time for the exact distance based on average pace
          final double estimatedTime = (run.durationSeconds / run.distanceKm) * targetDist;
          
          String key = targetDist == 21.0975 ? '21km' : targetDist == 42.195 ? '42km' : '${targetDist.toStringAsFixed(targetDist == targetDist.toInt() ? 0 : 1)}km';

          if (records[key]!['time'] == null || estimatedTime < records[key]!['time']) {
            records[key] = {
              'time': estimatedTime,
              'date': run.date,
              'runId': run.id,
            };
          }
        }
      }

      // Logic for longest run
      if (run.distanceKm > longestDistance) {
        longestDistance = run.distanceKm;
        longestDistanceDate = run.date;
        longestDistanceRunId = run.id;
      }
    }

    return {
      'bests': records,
      'longestDistance': {
        'value': longestDistance,
        'date': longestDistanceDate,
        'runId': longestDistanceRunId,
      },
    };
  }

  Future<List<Map<String, dynamic>>> getRecordHistory(String category) async {
    final runs = await getHistory();
    // Sort by date ascending to track evolution
    final sortedRuns = runs.reversed.toList();
    
    double targetDist = 0;
    if (category.endsWith('km')) {
      targetDist = double.tryParse(category.replaceAll('km', '')) ?? 0;
      if (category == '21km') targetDist = 21.0975;
      if (category == '42km') targetDist = 42.195;
    }

    if (targetDist == 0) return [];

    List<Map<String, dynamic>> history = [];
    double? currentBest;

    for (final run in sortedRuns) {
      if (run.distanceKm >= targetDist) {
        final double estimatedTime = (run.durationSeconds / run.distanceKm) * targetDist;
        
        if (currentBest == null || estimatedTime < currentBest) {
          double improvement = 0;
          if (currentBest != null) {
            improvement = currentBest - estimatedTime;
          }
          
          currentBest = estimatedTime;
          history.add({
            'time': estimatedTime,
            'date': run.date,
            'runId': run.id,
            'improvement': improvement,
          });
        }
      }
    }

    // Return descending (newest first) for UI
    return history.reversed.toList();
  }

  Future<List<Map<String, dynamic>>> getLongestDistanceHistory() async {
    final runs = await getHistory();
    // Sort by date ascending to track evolution
    final sortedRuns = runs.reversed.toList();
    
    List<Map<String, dynamic>> history = [];
    double currentMax = 0;

    for (final run in sortedRuns) {
      if (run.distanceKm > currentMax) {
        double improvement = 0;
        if (currentMax > 0) {
          improvement = run.distanceKm - currentMax;
        }
        
        currentMax = run.distanceKm;
        history.add({
          'value': run.distanceKm,
          'date': run.date,
          'runId': run.id,
          'improvement': improvement,
        });
      }
    }

    return history.reversed.toList();
  }

  Future<List<double>> getWeeklyProgress() async {
    final now = DateTime.now();
    // Encontrar o último domingo (ou hoje se for domingo)
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    final List<double> dailyDistances = List.filled(7, 0.0);

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'runs',
      where: 'date >= ?',
      whereArgs: [startDate.toIso8601String()],
    );

    for (final map in maps) {
      final date = DateTime.parse(map['date']);
      // Diferença em dias a partir da segunda-feira
      final dayIndex = date.difference(startDate).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        dailyDistances[dayIndex] += map['distanceKm'] as double;
      }
    }

    return dailyDistances;
  }

  // User Profile Methods
  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_profile',
      where: 'id = ?',
      whereArgs: ['current_user'],
    );
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }

  // Water Intake Methods
  Future<void> saveWaterIntake(int amount) async {
    final db = await database;
    await db.insert(
      'water_intake',
      {
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getDailyWaterIntake() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    
    return await db.query(
      'water_intake',
      where: 'timestamp >= ?',
      whereArgs: [today],
      orderBy: 'timestamp DESC',
    );
  }

  Future<int> getTotalDailyWaterIntake() async {
    final logs = await getDailyWaterIntake();
    return logs.fold<int>(0, (sum, log) => sum + (log['amount'] as int));
  }

  Future<void> deleteWaterIntake(int id) async {
    final db = await database;
    await db.delete('water_intake', where: 'id = ?', whereArgs: [id]);
  }
}
