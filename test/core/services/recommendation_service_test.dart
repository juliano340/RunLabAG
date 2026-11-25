import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';
import 'package:runlabag/core/services/recommendation_service.dart';

void main() {
  UserProfile profile({DateTime? lastGoalUpdate}) => UserProfile(
    name: 'Runner',
    age: 30,
    weight: 70,
    height: 170,
    weeklyGoal: 20,
    monthlyGoal: 80,
    lastGoalUpdate: lastGoalUpdate,
  );

  test('cooldown usa o relógio injetado', () {
    final now = DateTime(2026, 11, 29); // domingo
    final result = RecommendationService.calculateWeeklyRecommendation(
      profile: profile(lastGoalUpdate: now.subtract(const Duration(days: 6))),
      runs: const [],
      currentPeriodGoal: 20,
      now: now,
    );

    expect(result.emoji, '⏱️');
    expect(result.recommendedGoal, 20);
  });

  test('semana sem atividade no domingo reduz a meta com segurança', () {
    final result = RecommendationService.calculateWeeklyRecommendation(
      profile: profile(),
      runs: const [],
      currentPeriodGoal: 20,
      now: DateTime(2026, 11, 29),
    );

    expect(result.emoji, '😴');
    expect(result.recommendedGoal, 16);
  });
}
