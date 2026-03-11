import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path/path.dart';

class RunModel {
  final String id;
  final DateTime date;
  final double distanceKm;
  final int durationSeconds;
  final String pace;
  final int calories;
  final List<LatLng> route;

  RunModel({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.durationSeconds,
    required this.pace,
    required this.calories,
    this.route = const [],
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
    };
  }

  factory RunModel.fromMap(Map<String, dynamic> map) {
    List<dynamic> routeList = jsonDecode(map['route'] ?? '[]');
    return RunModel(
      id: map['id'],
      date: DateTime.parse(map['date']),
      distanceKm: map['distanceKm'],
      durationSeconds: map['durationSeconds'],
      pace: map['pace'],
      calories: map['calories'],
      route: routeList.map((p) => LatLng(p['lat'], p['lng'])).toList(),
    );
  }
}

class UserProfile {
  final String name;
  final int age;
  final double weight;
  final double height;
  final String? profilePicturePath;

  UserProfile({
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    this.profilePicturePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 'current_user',
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'profilePicturePath': profilePicturePath,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? 'Runner',
      age: map['age'] ?? 0,
      weight: map['weight'] ?? 0.0,
      height: map['height'] ?? 0.0,
      profilePicturePath: map['profilePicturePath'],
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

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'runlab_database.db');
    return await openDatabase(
      path,
      version: 3, // Upgraded version
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE runs(id TEXT PRIMARY KEY, date TEXT, distanceKm REAL, durationSeconds INTEGER, pace TEXT, calories INTEGER, route TEXT)',
        );
        await db.execute(
          'CREATE TABLE user_profile(id TEXT PRIMARY KEY, name TEXT, age INTEGER, weight REAL, height REAL, profilePicturePath TEXT)',
        );
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
      },
    );
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

  Future<List<double>> getWeeklyProgress() async {
    final now = DateTime.now();
    // Encontrar a última segunda-feira
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
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
}
