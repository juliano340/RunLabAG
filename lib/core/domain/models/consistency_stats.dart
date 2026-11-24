class ConsistencyStats {
  final int trainedDays;
  final int totalDays;
  final double frequencyRate;
  final int currentStreak;
  final int bestStreak;

  const ConsistencyStats({
    required this.trainedDays,
    required this.totalDays,
    required this.frequencyRate,
    required this.currentStreak,
    required this.bestStreak,
  });

  static const empty = ConsistencyStats(
    trainedDays: 0,
    totalDays: 0,
    frequencyRate: 0,
    currentStreak: 0,
    bestStreak: 0,
  );
}
