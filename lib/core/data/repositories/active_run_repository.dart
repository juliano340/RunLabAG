import 'package:sqflite/sqflite.dart';
import '../../services/database_helper.dart';

/// Persistência do treino em andamento.
///
/// A rota (payload grande) fica em `active_run_route`, separada da linha de
/// metadados em `active_run`. Assim:
/// - gravar métricas a cada poucos segundos não reescreve a rota inteira;
/// - o boot lê só os metadados (`getActiveRunMeta`), nunca centenas de KB.
class ActiveRunRepository {
  static const _metaId = 1;
  static const _routeId = 1;

  /// Metadados do treino ativo — sem a coluna `route`.
  Future<void> saveActiveRunMeta(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.database;
    final meta = Map<String, dynamic>.from(data)..remove('route');
    await db.insert(
      'active_run',
      {...meta, 'id': _metaId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Rota do treino ativo (chamada com pouca frequência).
  Future<void> saveActiveRunRoute(String routeJson) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'active_run_route',
      {'id': _routeId, 'route': routeJson},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Somente metadados: usado no boot para saber se há treino a recuperar.
  /// A coluna `route` é explicitamente omitida da leitura.
  Future<Map<String, dynamic>?> getActiveRunMeta() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'active_run',
      columns: const [
        'id',
        'startTime',
        'distanceKm',
        'secondsElapsed',
        'pausedDurationSeconds',
        'lastKmNotified',
        'distanceGoal',
        'isPaused',
        'splits',
        'targetTimeSeconds',
        'autoPauses',
        'finished',
      ],
      where: 'id = ?',
      whereArgs: [_metaId],
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// Metadados + rota: usado apenas quando o usuário escolhe retomar.
  Future<Map<String, dynamic>?> getActiveRun() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('active_run', where: 'id = ?', whereArgs: [_metaId]);
    if (maps.isEmpty) return null;

    final data = Map<String, dynamic>.from(maps.first);
    final routeRows = await db.query(
      'active_run_route',
      columns: ['route'],
      where: 'id = ?',
      whereArgs: [_routeId],
    );
    data['route'] = routeRows.isEmpty ? null : routeRows.first['route'];
    return data;
  }

  Future<void> clearActiveRun() async {
    final db = await DatabaseHelper.database;
    await db.delete('active_run', where: 'id = ?', whereArgs: [_metaId]);
    await db.delete('active_run_route', where: 'id = ?', whereArgs: [_routeId]);
  }
}
