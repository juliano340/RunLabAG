class RecordHistoryEntry {
  final double timeSeconds;
  final DateTime date;
  final double improvementSeconds;
  final String runId;
  final String interval;

  const RecordHistoryEntry({
    required this.timeSeconds,
    required this.date,
    required this.improvementSeconds,
    required this.runId,
    required this.interval,
  });
}

class LongestDistanceHistoryEntry {
  final double distanceKm;
  final DateTime date;
  final String runId;
  final double improvementKm;

  const LongestDistanceHistoryEntry({
    required this.distanceKm,
    required this.date,
    required this.runId,
    required this.improvementKm,
  });
}
