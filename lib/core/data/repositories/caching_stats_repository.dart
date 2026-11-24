import '../../domain/models/consistency_stats.dart';
import '../../domain/models/monthly_evolution_stats.dart';
import '../../domain/models/personal_records.dart';
import '../../domain/models/record_history_entry.dart';
import '../../domain/models/user_stats.dart';
import '../../domain/models/user_totals.dart';
import '../../domain/models/weekly_evolution_stats.dart';
import '../../domain/repositories/stats_repository.dart';
import '../read_model_cache.dart';

/// Cache de consultas derivadas. A invalidação é global após qualquer escrita,
/// o que é simples e seguro para o volume atual do app.
class CachingStatsRepository implements StatsRepository {
  final StatsRepository _inner;
  final ReadModelCache _cache;

  CachingStatsRepository(this._inner, this._cache);

  @override
  Future<void> saveGoalHistory(
    String periodId,
    String goalType,
    double goalValue,
  ) async {
    await _inner.saveGoalHistory(periodId, goalType, goalValue);
    _cache.invalidate();
  }

  @override
  Future<double?> getGoalHistory(String periodId, String goalType) {
    return _cache.getOrFetch(
      'goal:$periodId:$goalType',
      () => _inner.getGoalHistory(periodId, goalType),
    );
  }

  @override
  Future<List<WeeklyEvolutionStats>> getWeeklyEvolution(
    int numberOfWeeks,
  ) async {
    final key = 'weekly-evolution:$numberOfWeeks:${_weekKey(DateTime.now())}';
    final value = await _cache.getOrFetch(
      key,
      () => _inner.getWeeklyEvolution(numberOfWeeks),
    );
    return List<WeeklyEvolutionStats>.unmodifiable(value);
  }

  @override
  Future<UserTotals> getTotals({DateTime? since}) {
    final key = 'totals:${_windowKey(since, DateTime.now())}';
    return _cache.getOrFetch(key, () => _inner.getTotals(since: since));
  }

  @override
  Future<UserStats> getUserStats({DateTime? since}) {
    final key = 'user-stats:${_windowKey(since, DateTime.now())}';
    return _cache.getOrFetch(key, () => _inner.getUserStats(since: since));
  }

  @override
  Future<List<double>> getMonitoredDistances() async {
    final value = await _cache.getOrFetch(
      'monitored-distances',
      _inner.getMonitoredDistances,
    );
    return List<double>.unmodifiable(value);
  }

  @override
  Future<void> addMonitoredDistance(double distance) async {
    await _inner.addMonitoredDistance(distance);
    _cache.invalidate();
  }

  @override
  Future<void> removeMonitoredDistance(double distance) async {
    await _inner.removeMonitoredDistance(distance);
    _cache.invalidate();
  }

  @override
  Future<PersonalRecordsSnapshot> getPersonalRecords() {
    return _cache.getOrFetch('personal-records', _inner.getPersonalRecords);
  }

  @override
  Future<List<RecordHistoryEntry>> getRecordHistory(
    double targetDistanceKm,
  ) async {
    final value = await _cache.getOrFetch(
      'record-history:${targetDistanceKm.toStringAsFixed(4)}',
      () => _inner.getRecordHistory(targetDistanceKm),
    );
    return List<RecordHistoryEntry>.unmodifiable(value);
  }

  @override
  Future<List<LongestDistanceHistoryEntry>> getLongestDistanceHistory() async {
    final value = await _cache.getOrFetch(
      'longest-distance-history',
      _inner.getLongestDistanceHistory,
    );
    return List<LongestDistanceHistoryEntry>.unmodifiable(value);
  }

  @override
  Future<List<double>> getWeeklyProgress() async {
    final key = 'weekly-progress:${_weekKey(DateTime.now())}';
    final value = await _cache.getOrFetch(key, _inner.getWeeklyProgress);
    return List<double>.unmodifiable(value);
  }

  @override
  Future<List<MonthlyEvolutionStats>> getMonthlyEvolution(
    int numberOfMonths,
  ) async {
    final key =
        'monthly-evolution:$numberOfMonths:${_monthKey(DateTime.now())}';
    final value = await _cache.getOrFetch(
      key,
      () => _inner.getMonthlyEvolution(numberOfMonths),
    );
    return List<MonthlyEvolutionStats>.unmodifiable(value);
  }

  @override
  Future<Map<String, int>> getRunsByTypeBetween(
    DateTime start,
    DateTime end,
  ) async {
    final value = await _cache.getOrFetch(
      'runs-by-type:${start.millisecondsSinceEpoch}:'
      '${end.millisecondsSinceEpoch}',
      () => _inner.getRunsByTypeBetween(start, end),
    );
    return Map<String, int>.unmodifiable(value);
  }

  @override
  Future<ConsistencyStats> getConsistencyStats(DateTime since) {
    final key = 'consistency:${_dayKey(since)}:${_dayKey(DateTime.now())}';
    return _cache.getOrFetch(key, () => _inner.getConsistencyStats(since));
  }

  @override
  Future<Map<String, dynamic>> getPerformanceTrend(int weeks) {
    final key = 'performance-trend:$weeks:${_weekKey(DateTime.now())}';
    return _cache.getOrFetch(key, () => _inner.getPerformanceTrend(weeks));
  }

  @override
  Future<Map<String, dynamic>> comparePeriods(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  ) {
    final key =
        'compare:${start1.millisecondsSinceEpoch}:'
        '${end1.millisecondsSinceEpoch}:'
        '${start2.millisecondsSinceEpoch}:'
        '${end2.millisecondsSinceEpoch}';
    return _cache.getOrFetch(
      key,
      () => _inner.comparePeriods(start1, end1, start2, end2),
    );
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${_pad(date.month)}-${_pad(date.day)}';

  String _weekKey(DateTime now) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday % 7));
    return _dayKey(start);
  }

  String _monthKey(DateTime now) => '${now.year}-${_pad(now.month)}';

  String _windowKey(DateTime? since, DateTime now) => since == null
      ? 'all:${_dayKey(now)}'
      : '${_dayKey(since)}:${_dayKey(now)}';

  String _pad(int value) => value.toString().padLeft(2, '0');
}
