import 'package:runlabag/core/domain/models/user_profile.dart';
import 'package:runlabag/core/services/database_service.dart';

import '../../domain/repositories/run_profile_source.dart';

class DatabaseRunProfileSource implements RunProfileSource {
  final DatabaseService _databaseService;

  DatabaseRunProfileSource(this._databaseService);

  @override
  Future<UserProfile?> load() => _databaseService.getUserProfile();
}
