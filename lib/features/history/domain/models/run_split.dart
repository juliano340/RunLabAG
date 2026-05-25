class RunSplit {
  final int timeSeconds;
  final int calories;

  RunSplit({required this.timeSeconds, required this.calories});

  Map<String, dynamic> toMap() => {'t': timeSeconds, 'c': calories};
  factory RunSplit.fromMap(Map<String, dynamic> map) => RunSplit(
    timeSeconds: map['t'] ?? 0,
    calories: map['c'] ?? 0,
  );
}
