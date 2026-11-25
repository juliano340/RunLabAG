import '../models/earned_achievement.dart';

abstract interface class AchievementRepository {
  Future<List<EarnedAchievement>> getEarnedAchievements();

  Future<void> saveAchievement({
    required String id,
    required String title,
    required String description,
    required int iconCode,
  });

  Future<EarnedAchievement?> getLastAchievement();
}
