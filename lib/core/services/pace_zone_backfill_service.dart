import '../domain/models/run_model.dart';
import '../domain/repositories/run_repository.dart';
import '../domain/services/pace_zone_service.dart';

/// Preenche faixas de ritmo de treinos antigos em lotes pequenos.
class PaceZoneBackfillService {
  final RunRepository _runRepository;

  PaceZoneBackfillService(this._runRepository);

  Future<int> runBatch({int batchSize = 12}) async {
    var processed = 0;
    final pending = await _runRepository.getRunsMissingPaceZones(
      limit: batchSize,
    );
    for (final row in pending) {
      final run = RunModel.fromMap({
        'id': row['id'],
        'date': DateTime.now().toIso8601String(),
        'distanceKm': row['distanceKm'],
        'durationSeconds': row['durationSeconds'],
        'pace': '0:00',
        'calories': 0,
        'route': row['route'],
        'splits': row['splits'],
      });
      final result = PaceZoneService.analyze(
        route: run.route,
        routeTimes: run.routeTimes,
        distanceKm: run.distanceKm,
        durationSeconds: run.durationSeconds,
        splits: run.splits,
      );
      await _runRepository.savePaceZones(row['id'] as String, {
        for (final entry in result.distanceByZoneKm.entries)
          entry.key.name: entry.value,
      });
      processed++;
    }
    return processed;
  }
}
