import '../../domain/models/user_profile.dart';
import '../../domain/repositories/user_repository.dart';
import '../read_model_cache.dart';

class CachingUserRepository implements UserRepository {
  final UserRepository _inner;
  final ReadModelCache _cache;

  CachingUserRepository(this._inner, this._cache);

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    await _inner.saveUserProfile(profile);
    _cache.invalidate();
  }

  @override
  Future<UserProfile?> getUserProfile() {
    return _cache.getOrFetch('user-profile', _inner.getUserProfile);
  }
}
