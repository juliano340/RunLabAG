import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/domain/models/earned_achievement.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/user_totals.dart';
import 'package:runlabag/core/domain/repositories/achievement_repository.dart';
import 'package:runlabag/core/domain/repositories/stats_repository.dart';
import 'package:runlabag/core/services/achievement_service.dart';

class _FakeStatsRepository implements StatsRepository {
  @override
  Future<UserTotals> getTotals({DateTime? since}) async => const UserTotals(
    runCount: 1,
    totalDistanceKm: 5,
    totalSeconds: 1800,
    totalCalories: 300,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAchievementRepository implements AchievementRepository {
  final List<EarnedAchievement> earned = [];
  final List<EarnedAchievement> saved = [];

  @override
  Future<List<EarnedAchievement>> getEarnedAchievements() async => earned;

  @override
  Future<void> saveAchievement({
    required String id,
    required String title,
    required String description,
    required int iconCode,
  }) async {
    final achievement = EarnedAchievement(
      id: id,
      title: title,
      description: description,
      iconCode: iconCode,
      earnedDate: DateTime(2026, 11, 25),
    );
    saved.add(achievement);
    earned.add(achievement);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('conquistas usam repositórios injetados e não duplicam ids', () async {
    final achievements = _FakeAchievementRepository();
    final service = AchievementService(
      statsRepository: _FakeStatsRepository(),
      achievementRepository: achievements,
    );
    final run = RunModel(
      id: 'run_1',
      date: DateTime(2026, 11, 25, 10),
      distanceKm: 5,
      durationSeconds: 1800,
      pace: '6:00',
      calories: 300,
    );

    final first = await service.checkAwards(run);
    final second = await service.checkAwards(run);

    expect(first.map((item) => item['id']), ['first_run', 'finisher_5k']);
    expect(second, isEmpty);
    expect(achievements.saved, hasLength(2));
  });
}
