import 'package:sqflite/sqflite.dart';
import '../../../../core/services/database_helper.dart';
import '../../../../features/history/domain/models/run_model.dart';

class RunRepository {
  Future<void> saveRun(RunModel run) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'runs',
      run.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RunModel>> getRuns() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('runs', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => RunModel.fromMap(maps[i]));
  }

  Future<List<RunModel>> getRunsBetween(DateTime start, DateTime end) async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'runs',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) => RunModel.fromMap(maps[i]));
  }

  Future<RunModel?> getLastRun() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('runs', orderBy: 'date DESC', limit: 1);
    if (maps.isEmpty) return null;
    return RunModel.fromMap(maps.first);
  }

  Future<void> deleteRun(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('runs', where: 'id = ?', whereArgs: [id]);
  }
}
