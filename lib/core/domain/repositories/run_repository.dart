import '../models/run_model.dart';

/// Contrato de persistência de treinos. A UI depende desta porta, não do SQLite.
abstract interface class RunRepository {
  Future<void> saveRun(RunModel run);

  Future<List<RunModel>> getSummaries();

  Future<List<RunModel>> getSummariesBetween(DateTime start, DateTime end);

  Future<RunModel?> getLastRunSummary();

  Future<RunModel?> getById(String id);

  Future<void> deleteRun(String id);

  Future<void> savePaceZones(String runId, Map<String, double> distanceByZone);

  Future<Map<String, double>> getPaceZoneTotals(DateTime start, DateTime end);

  Future<List<Map<String, dynamic>>> getRunsMissingPaceZones({int limit});
}
