import '../models/consistency_stats.dart';
import '../models/monthly_evolution_stats.dart';
import '../models/personal_records.dart';
import '../models/record_history_entry.dart';
import '../models/user_stats.dart';
import '../models/user_totals.dart';
import '../models/weekly_evolution_stats.dart';

/// Contrato de consultas agregadas e recordes.
abstract interface class StatsRepository {
  Future<void> saveGoalHistory(
    String periodId,
    String goalType,
    double goalValue,
  );

  Future<double?> getGoalHistory(String periodId, String goalType);

  Future<List<WeeklyEvolutionStats>> getWeeklyEvolution(int numberOfWeeks);

  Future<UserTotals> getTotals({DateTime? since});

  Future<UserStats> getUserStats({DateTime? since});

  Future<List<double>> getMonitoredDistances();

  Future<void> addMonitoredDistance(double distance);

  Future<void> removeMonitoredDistance(double distance);

  Future<PersonalRecordsSnapshot> getPersonalRecords();

  Future<List<RecordHistoryEntry>> getRecordHistory(double targetDistanceKm);

  Future<List<LongestDistanceHistoryEntry>> getLongestDistanceHistory();

  Future<List<double>> getWeeklyProgress();

  Future<List<MonthlyEvolutionStats>> getMonthlyEvolution(int numberOfMonths);

  Future<Map<String, int>> getRunsByTypeBetween(DateTime start, DateTime end);

  Future<ConsistencyStats> getConsistencyStats(DateTime since);

  Future<Map<String, dynamic>> getPerformanceTrend(int weeks);

  Future<Map<String, dynamic>> comparePeriods(
    DateTime start1,
    DateTime end1,
    DateTime start2,
    DateTime end2,
  );
}
