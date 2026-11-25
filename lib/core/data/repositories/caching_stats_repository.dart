import '../../domain/models/consistency_stats.dart';
import '../../domain/models/monthly_evolution_stats.dart';
import '../../domain/models/personal_records.dart';
import '../../domain/models/record_history_entry.dart';
import '../../domain/models/user_stats.dart';
import '../../domain/models/user_totals.dart';
import '../../domain/models/weekly_evolution_stats.dart';
import '../../domain/repositories/stats_repository.dart';
import '../data_change_hub.dart';
import '../read_model_cache.dart';

/// Cache de consultas derivadas com invalidação por escopo.
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
    _cache.invalidate({DataScope.goals});
  }

  @override
  Future<double?> getGoalHistory(String periodId, String goalType) {
    return _cache.getOrFetch(
      'goal:$periodId:$goalType',
      () => _inner.getGoalHistory(periodId, goalType),
      scopes: {DataScope.goals},
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
      scopes: {DataScope.runs, DataScope.profile, DataScope.goals},
    );
    return List<WeeklyEvolutionStats>.unmodifiable(value);
  }

  @override
  Future<UserTotals> getTotals({DateTime? since}) {
    final key = 'totals:${_windowKey(since, DateTime.now())}';
    return _cache.getOrFetch(
      key,
      () => _inner.getTotals(since: since),
      scopes: {DataScope.runs},
    );
  }

  @override
  Future<UserStats> getUserStats({DateTime? since}) {
    final key = 'user-stats:${_windowKey(since, DateTime.now())}';
    return _cache.getOrFetch(
      key,
      () => _inner.getUserStats(since: since),
      scopes: {DataScope.runs},
    );
  }

  @override
  Future<List<double>> getMonitoredDistances() async {
    final value = await _cache.getOrFetch(
      'monitored-distances',
      _inner.getMonitoredDistances,
      scopes: {DataScope.monitoredDistances},
    );
    return List<double>.unmodifiable(value);
  }

  @override
  Future<void> addMonitoredDistance(double distance) async {
    await _inner.addMonitoredDistance(distance);
    _cache.invalidate({DataScope.monitoredDistances});
  }

  @override
  Future<void> removeMonitoredDistance(double distance) async {
    await _inner.removeMonitoredDistance(distance);
    _cache.invalidate({DataScope.monitoredDistances});
  }

  @override
  Future<PersonalRecordsSnapshot> getPersonalRecords() {
    return _cache.getOrFetch(
      'personal-records',
      _inner.getPersonalRecords,
      scopes: {DataScope.runs, DataScope.monitoredDistances},
    );
  }

  @override
  Future<List<RecordHistoryEntry>> getRecordHistory(
    double targetDistanceKm,
  ) async {
    final value = await _cache.getOrFetch(
      'record-history:${targetDistanceKm.toStringAsFixed(4)}',
      () => _inner.getRecordHistory(targetDistanceKm),
      scopes: {DataScope.runs},
    );
    return List<RecordHistoryEntry>.unmodifiable(value);
  }

  @override
  Future<List<LongestDistanceHistoryEntry>> getLongestDistanceHistory() async {
    final value = await _cache.getOrFetch(
      'longest-distance-history',
      _inner.getLongestDistanceHistory,
      scopes: {DataScope.runs},
    );
    return List<LongestDistanceHistoryEntry>.unmodifiable(value);
  }

  @override
  Future<List<double>> getWeeklyProgress() async {
    final key = 'weekly-progress:${_weekKey(DateTime.now())}';
    final value = await _cache.getOrFetch(
      key,
      _inner.getWeeklyProgress,
      scopes: {DataScope.runs},
    );
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
      scopes: {DataScope.runs, DataScope.profile, DataScope.goals},
    );
    return List<MonthlyEvolutionStats>.unmodifiable(value);
  }

  @override
  Future<ConsistencyStats> getConsistencyStats(DateTime since) {
    final key = 'consistency:${_dayKey(since)}:${_dayKey(DateTime.now())}';
    return _cache.getOrFetch(
      key,
      () => _inner.getConsistencyStats(since),
      scopes: {DataScope.runs},
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
