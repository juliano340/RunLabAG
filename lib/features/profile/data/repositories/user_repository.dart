import 'package:sqflite/sqflite.dart';
import '../../../../core/services/database_helper.dart';
import '../../../../features/profile/domain/models/user_profile.dart';

class UserRepository {
  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserProfile?> getUserProfile() async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_profile',
      where: 'id = ?',
      whereArgs: ['current_user'],
    );
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }
}
