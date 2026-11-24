/// Totais agregados da carreira do usuário.
class UserTotals {
  final int runCount;
  final double totalDistanceKm;
  final int totalSeconds;
  final int totalCalories;

  const UserTotals({
    required this.runCount,
    required this.totalDistanceKm,
    required this.totalSeconds,
    required this.totalCalories,
  });

  static const empty = UserTotals(
    runCount: 0,
    totalDistanceKm: 0,
    totalSeconds: 0,
    totalCalories: 0,
  );
}
