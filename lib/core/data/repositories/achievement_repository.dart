import 'package:sqflite/sqflite.dart';

import '../../domain/models/earned_achievement.dart';
import '../../domain/repositories/achievement_repository.dart';
import '../../services/database_helper.dart';

class SqfliteAchievementRepository implements AchievementRepository {
  @override
  Future<List<EarnedAchievement>> getEarnedAchievements() async {
    final db = await DatabaseHelper.database;
    final rows = await db.query('achievements', orderBy: 'earnedDate DESC');
    return rows.map(EarnedAchievement.fromMap).toList();
  }

  @override
  Future<void> saveAchievement({
    required String id,
    required String title,
    required String description,
    required int iconCode,
  }) async {
    final db = await DatabaseHelper.database;
    await db.insert('achievements', {
      'id': id,
      'title': title,
      'description': description,
      'iconCode': iconCode,
      'earnedDate': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<EarnedAchievement?> getLastAchievement() async {
    final db = await DatabaseHelper.database;
    final rows = await db.query(
      'achievements',
      orderBy: 'earnedDate DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : EarnedAchievement.fromMap(rows.first);
  }
}
