import 'package:runlabag/core/services/database_service.dart';

import '../../domain/repositories/active_run_store.dart';

class DatabaseActiveRunStore implements ActiveRunStore {
  final DatabaseService _databaseService;

  DatabaseActiveRunStore(this._databaseService);

  @override
  Future<void> saveMeta(Map<String, dynamic> data) =>
      _databaseService.saveActiveRunMeta(data);

  @override
  Future<void> saveRoute(String routeJson) =>
      _databaseService.saveActiveRunRoute(routeJson);

  @override
  Future<void> clear() => _databaseService.clearActiveRun();
}
