import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';

void main() {
  test('copyWith altera metas sem perder preferências ou foto', () {
    final profile = UserProfile(
      name: 'Runner',
      age: 30,
      weight: 70,
      height: 170,
      profilePicturePath: '/foto.jpg',
      weeklyGoal: 20,
      monthlyGoal: 80,
      lastGoalUpdate: DateTime(2026, 11, 1),
      kmNotificationsEnabled: false,
    );

    final updated = profile.copyWith(
      weeklyGoal: 25,
      lastGoalUpdate: DateTime(2026, 11, 24),
    );

    expect(updated.weeklyGoal, 25);
    expect(updated.monthlyGoal, 80);
    expect(updated.profilePicturePath, '/foto.jpg');
    expect(updated.kmNotificationsEnabled, isFalse);
    expect(updated.lastGoalUpdate, DateTime(2026, 11, 24));
  });

  test('copyWith permite limpar campos nullable explicitamente', () {
    final profile = UserProfile(
      name: 'Runner',
      age: 30,
      weight: 70,
      height: 170,
      profilePicturePath: '/foto.jpg',
      lastGoalUpdate: DateTime(2026, 11, 1),
    );

    final updated = profile.copyWith(
      profilePicturePath: null,
      lastGoalUpdate: null,
    );

    expect(updated.profilePicturePath, isNull);
    expect(updated.lastGoalUpdate, isNull);
  });
}
