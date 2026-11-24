import 'package:sqflite/sqflite.dart';

import '../../domain/models/run_model.dart';
import '../../domain/repositories/run_completion_store.dart';
import '../../services/database_helper.dart';

class SqfliteRunCompletionStore implements RunCompletionStore {
  @override
  Future<void> saveCompletedRun({
    required RunModel run,
    required Map<String, double> distanceByZone,
  }) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'runs',
        run.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'run_pace_zones',
        where: 'runId = ?',
        whereArgs: [run.id],
      );
      for (final entry in distanceByZone.entries) {
        await txn.insert('run_pace_zones', {
          'runId': run.id,
          'zone': entry.key,
          'distanceKm': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (distanceByZone.isEmpty) {
        await txn.insert('run_pace_zones', {
          'runId': run.id,
          'zone': 'none',
          'distanceKm': 0.0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Só limpa o rascunho depois que o treino e seus derivados foram
      // confirmados na mesma transação.
      await txn.delete('active_run', where: 'id = ?', whereArgs: [1]);
      await txn.delete('active_run_route', where: 'id = ?', whereArgs: [1]);
    });
  }
}
