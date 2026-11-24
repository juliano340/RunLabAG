class PersonalRecord {
  final double targetDistanceKm;
  final double? timeSeconds;
  final DateTime? date;
  final String? runId;
  final String? interval;

  const PersonalRecord({
    required this.targetDistanceKm,
    required this.timeSeconds,
    required this.date,
    required this.runId,
    required this.interval,
  });
}

class LongestDistanceRecord {
  final double distanceKm;
  final DateTime? date;
  final String? runId;

  const LongestDistanceRecord({
    required this.distanceKm,
    required this.date,
    required this.runId,
  });
}

class PersonalRecordsSnapshot {
  final List<PersonalRecord> bests;
  final LongestDistanceRecord longestDistance;

  const PersonalRecordsSnapshot({
    required this.bests,
    required this.longestDistance,
  });

  PersonalRecord? recordFor(double targetDistanceKm) {
    for (final record in bests) {
      if ((record.targetDistanceKm - targetDistanceKm).abs() < 0.0001) {
        return record;
      }
    }
    return null;
  }
}
