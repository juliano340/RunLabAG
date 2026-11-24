import '../models/user_profile.dart';

abstract interface class UserRepository {
  Future<void> saveUserProfile(UserProfile profile);

  Future<UserProfile?> getUserProfile();
}
