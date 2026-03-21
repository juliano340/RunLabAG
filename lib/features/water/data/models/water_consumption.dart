class WaterConsumption {
  final int? id;
  final int amount; // em ml
  final DateTime timestamp;

  WaterConsumption({
    this.id,
    required this.amount,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WaterConsumption.fromMap(Map<String, dynamic> map) {
    return WaterConsumption(
      id: map['id'],
      amount: map['amount'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
