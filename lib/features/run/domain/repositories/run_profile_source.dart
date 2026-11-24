import 'package:runlabag/core/domain/models/user_profile.dart';

/// Fonte do perfil necessária para peso e preferência de avisos de km.
abstract interface class RunProfileSource {
  Future<UserProfile?> load();
}
