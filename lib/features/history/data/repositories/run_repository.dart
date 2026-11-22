import 'package:sqflite/sqflite.dart';
import '../../../../core/services/database_helper.dart';
import 'package:runlabag/core/domain/models/run_model.dart';

/// Acesso à tabela `runs`.
///
/// Regra de ouro: **listas, totais, recordes e gráficos nunca leem a coluna
/// `route`**. A rota é o maior payload do banco (centenas de KB por treino) e
/// decodificá-la em toda leitura custava caro o suficiente para travar o app
/// no boot. Use [getSummaries]/[getSummariesBetween] por padrão e
/// [getById] apenas quando a tela for realmente desenhar o mapa.
class RunRepository {
  static const summaryColumns =
      'id, date, distanceKm, durationSeconds, pausedDurationSeconds, '
      'pace, calories, type, mood, splits';

  Future<void> saveRun(RunModel run) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'runs',
      run.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Treinos sem rota (leve). Ordenados do mais recente para o mais antigo.
  Future<List<RunModel>> getSummaries() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'runs',
      columns: summaryColumns.split(', '),
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => RunModel.fromSummaryMap(maps[i]));
  }

  Future<List<RunModel>> getSummariesBetween(DateTime start, DateTime end) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'runs',
      columns: summaryColumns.split(', '),
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) => RunModel.fromSummaryMap(maps[i]));
  }

  Future<RunModel?> getLastRunSummary() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'runs',
      columns: summaryColumns.split(', '),
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return RunModel.fromSummaryMap(maps.first);
  }

  /// Treino completo (com rota). Use só para desenhar o mapa / compartilhar.
  Future<RunModel?> getById(String id) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('runs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return RunModel.fromMap(maps.first);
  }

  Future<void> deleteRun(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('runs', where: 'id = ?', whereArgs: [id]);
    await db.delete('run_pace_zones', where: 'runId = ?', whereArgs: [id]);
  }

  // --- Faixas de ritmo pré-calculadas -------------------------------------
  // Guardadas por treino no momento em que ele é salvo, para que o histórico
  // e as análises leiam só números em vez de reprocessar milhares de pontos.

  Future<void> savePaceZones(String runId, Map<String, double> distanceByZone) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      await txn.delete('run_pace_zones', where: 'runId = ?', whereArgs: [runId]);
      for (final entry in distanceByZone.entries) {
        await txn.insert(
          'run_pace_zones',
          {'runId': runId, 'zone': entry.key, 'distanceKm': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      // Marca "já calculado" mesmo quando o treino não tem rota/voltas.
      if (distanceByZone.isEmpty) {
        await txn.insert(
          'run_pace_zones',
          {'runId': runId, 'zone': 'none', 'distanceKm': 0.0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<Map<String, double>> getPaceZoneTotals(DateTime start, DateTime end) async {
    final db = await DatabaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT z.zone AS zone, SUM(z.distanceKm) AS total '
      'FROM run_pace_zones z INNER JOIN runs r ON r.id = z.runId '
      'WHERE r.date >= ? AND r.date <= ? AND z.zone != ? '
      'GROUP BY z.zone',
      [start.toIso8601String(), end.toIso8601String(), 'none'],
    );
    return {
      for (final row in rows)
        row['zone'] as String: (row['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Ids de treinos que ainda não tiveram as faixas de ritmo calculadas.
  Future<List<Map<String, dynamic>>> getRunsMissingPaceZones({int limit = 40}) async {
    final db = await DatabaseHelper.database;
    return db.rawQuery(
      'SELECT r.id AS id, r.route AS route, r.splits AS splits, '
      'r.distanceKm AS distanceKm, r.durationSeconds AS durationSeconds '
      'FROM runs r LEFT JOIN run_pace_zones z ON z.runId = r.id '
      'WHERE z.runId IS NULL ORDER BY r.date DESC LIMIT ?',
      [limit],
    );
  }
}
