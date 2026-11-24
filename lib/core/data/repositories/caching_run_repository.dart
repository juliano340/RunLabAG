import '../../domain/models/run_model.dart';
import '../../domain/repositories/run_repository.dart';
import '../read_model_cache.dart';

/// Compartilha resumos leves entre Histórico, Home, Recordes e Análises.
/// Rotas completas nunca entram no cache.
class CachingRunRepository implements RunRepository {
  final RunRepository _inner;
  final ReadModelCache _cache;

  CachingRunRepository(this._inner, this._cache);

  @override
  Future<void> saveRun(RunModel run) async {
    await _inner.saveRun(run);
    _cache.invalidate();
  }

  @override
  Future<List<RunModel>> getSummaries() async {
    final runs = await _cache.getOrFetch('run-summaries', _inner.getSummaries);
    return List<RunModel>.unmodifiable(runs);
  }

  @override
  Future<List<RunModel>> getSummariesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final runs = await getSummaries();
    final filtered =
        runs
            .where((run) => !run.date.isBefore(start) && !run.date.isAfter(end))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return List<RunModel>.unmodifiable(filtered);
  }

  @override
  Future<RunModel?> getLastRunSummary() async {
    final runs = await getSummaries();
    return runs.isEmpty ? null : runs.first;
  }

  @override
  Future<RunModel?> getById(String id) => _inner.getById(id);

  @override
  Future<void> deleteRun(String id) async {
    await _inner.deleteRun(id);
    _cache.invalidate();
  }

  @override
  Future<void> savePaceZones(
    String runId,
    Map<String, double> distanceByZone,
  ) async {
    await _inner.savePaceZones(runId, distanceByZone);
    _cache.invalidate();
  }

  @override
  Future<Map<String, double>> getPaceZoneTotals(DateTime start, DateTime end) =>
      _inner.getPaceZoneTotals(start, end);

  @override
  Future<List<Map<String, dynamic>>> getRunsMissingPaceZones({
    int limit = 40,
  }) => _inner.getRunsMissingPaceZones(limit: limit);
}
