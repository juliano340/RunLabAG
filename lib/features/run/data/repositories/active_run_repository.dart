import 'package:sqflite/sqflite.dart';
import '../../../../core/services/database_helper.dart';

class ActiveRunRepository {
  Future<void> saveActiveRun(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'active_run',
      {...data, 'id': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getActiveRun() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('active_run', where: 'id = 1');
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> clearActiveRun() async {
    final db = await DatabaseHelper.database;
    await db.delete('active_run', where: 'id = 1');
  }
}
