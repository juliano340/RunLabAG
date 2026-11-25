import '../../../../core/data/repositories/user_repository.dart';
import '../../../../core/domain/models/user_profile.dart';
import '../../../../core/domain/repositories/user_repository.dart';
import '../../domain/repositories/run_profile_source.dart';

/// Adapta o repositório de perfil à porta consumida pelo motor da corrida.
class DatabaseRunProfileSource implements RunProfileSource {
  final UserRepository _repository;

  DatabaseRunProfileSource([UserRepository? repository])
    : _repository = repository ?? SqfliteUserRepository();

  @override
  Future<UserProfile?> load() => _repository.getUserProfile();
}
