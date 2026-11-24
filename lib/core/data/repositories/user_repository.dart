import 'package:sqflite/sqflite.dart';
import '../../services/database_helper.dart';
import '../../domain/repositories/user_repository.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';

class SqfliteUserRepository implements UserRepository {
  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await DatabaseHelper.database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
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
