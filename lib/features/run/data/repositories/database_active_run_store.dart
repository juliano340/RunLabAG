import '../../../../core/data/repositories/active_run_repository.dart';
import '../../../../core/domain/repositories/active_run_repository.dart';
import '../../domain/repositories/active_run_store.dart';

/// Adapta o repositório de domínio à porta estreita usada pelo motor da corrida.
class DatabaseActiveRunStore implements ActiveRunStore {
  final ActiveRunRepository _repository;

  DatabaseActiveRunStore([ActiveRunRepository? repository])
    : _repository = repository ?? SqfliteActiveRunRepository();

  @override
  Future<void> saveMeta(Map<String, dynamic> data) =>
      _repository.saveActiveRunMeta(data);

  @override
  Future<void> saveRoute(String routeJson) =>
      _repository.saveActiveRunRoute(routeJson);

  @override
  Future<void> clear() => _repository.clearActiveRun();
}
