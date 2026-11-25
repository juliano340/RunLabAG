import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/data/data_change_hub.dart';
import '../../../../core/domain/models/run_model.dart';
import '../../../../core/domain/models/user_profile.dart';
import '../../../../core/domain/repositories/run_repository.dart';
import '../../../../core/domain/repositories/stats_repository.dart';
import '../../../../core/domain/repositories/user_repository.dart';
import '../../../../core/domain/services/pace_zone_service.dart';
import '../../../../core/services/recommendation_service.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/latest_request.dart';
import '../domain/history_period.dart';

enum HistoryLoadStatus { loading, ready, error }

/// Estado e regras do dashboard de histórico, sem conhecer widgets ou navegação.
class HistoryDashboardViewModel extends ChangeNotifier {
  final RunRepository _runRepository;
  final StatsRepository _statsRepository;
  final UserRepository _userRepository;
  final DataChangeHub _changes;
  final Clock _clock;
  final LatestRequest _latestRequest = LatestRequest();

  Listenable? _dataListenable;
  bool _initialized = false;
  bool _disposed = false;
  bool _isSaving = false;
  int _internalWrites = 0;

  HistoryPeriod _period;
  List<RunModel> _allRuns = [];
  List<RunModel> _filteredRuns = [];
  UserProfile? _profile;
  DateTime? _minDate;
  DateTime? _maxDate;
  double _currentPeriodGoal = 20;
  Map<PaceZone, double> _paceZoneTotals = {};
  RecommendationResult? _recommendation;
  List<HistoryChartBar> _chartBars = [];
  double _chartMaxDistance = 5;
  bool _canGoPrevious = false;
  bool _canGoNext = false;
  HistoryLoadStatus _status = HistoryLoadStatus.loading;
  Object? _error;
  HistorySummary _summary = const HistorySummary(
    totalKm: 0,
    totalSeconds: 0,
    totalCalories: 0,
    estimatedWeightLossKg: 0,
    rawGoalProgress: 0,
    goalProgress: 0,
  );

  HistoryDashboardViewModel({
    required RunRepository runRepository,
    required StatsRepository statsRepository,
    required UserRepository userRepository,
    required DataChangeHub changes,
    Clock clock = const SystemClock(),
  }) : _runRepository = runRepository,
       _statsRepository = statsRepository,
       _userRepository = userRepository,
       _changes = changes,
       _clock = clock,
       _period = HistoryPeriod.week(clock.now());

  HistoryLoadStatus get status => _status;
  Object? get error => _error;
  List<RunModel> get allRuns => _allRuns;
  List<RunModel> get filteredRuns => _filteredRuns;
  UserProfile? get profile => _profile;
  double get currentPeriodGoal => _currentPeriodGoal;
  Map<PaceZone, double> get paceZoneTotals => _paceZoneTotals;
  RecommendationResult? get recommendation => _recommendation;
  List<HistoryChartBar> get chartBars => _chartBars;
  double get chartMaxDistance => _chartMaxDistance;
  bool get canGoPrevious => _canGoPrevious;
  bool get canGoNext => _canGoNext;
  bool get isSaving => _isSaving;
  HistorySummary get summary => _summary;
  HistoryPeriod get period => _period;
  int get selectedPeriodIndex => _period.mode.index;

  double get defaultGoal => _defaultGoalFor(_period, _profile);

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _dataListenable = _changes.listenableFor({
      DataScope.runs,
      DataScope.profile,
      DataScope.goals,
      DataScope.paceZones,
    });
    _dataListenable!.addListener(_onDataChanged);
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final requestId = _latestRequest.begin();
    _error = null;
    if (_status == HistoryLoadStatus.error) {
      _status = HistoryLoadStatus.loading;
      notifyListeners();
    }

    try {
      // As duas consultas são independentes e compartilham o mesmo request id.
      final runsFuture = _runRepository.getSummaries();
      final profileFuture = _userRepository.getUserProfile();
      await Future.wait([runsFuture, profileFuture]);
      if (!_isCurrent(requestId)) return;

      final runs = List<RunModel>.unmodifiable(await runsFuture);
      final profile = await profileFuture;
      final snapshot = await _loadPeriod(requestId, runs, profile);
      if (!_isCurrent(requestId) || snapshot == null) return;

      // Só publica o novo conjunto depois de carregar também meta, ritmo e
      // agregações. Uma falha intermediária não deixa metade do dash no estado.
      _allRuns = runs;
      _profile = profile;
      _minDate = runs.isEmpty
          ? null
          : runs.map((run) => run.date).reduce((a, b) => a.isBefore(b) ? a : b);
      _maxDate = runs.isEmpty
          ? null
          : runs.map((run) => run.date).reduce((a, b) => a.isAfter(b) ? a : b);
      _applyPeriodSnapshot(snapshot);
      _status = HistoryLoadStatus.ready;
      notifyListeners();
    } catch (error) {
      if (!_isCurrent(requestId)) return;
      _error = error;
      _status = HistoryLoadStatus.error;
      notifyListeners();
    }
  }

  Future<void> selectWeek() => _selectMode(HistoryPeriodMode.week);

  Future<void> selectMonth() => _selectMode(HistoryPeriodMode.month);

  Future<void> _selectMode(HistoryPeriodMode mode) async {
    if (_disposed || _period.mode == mode) return;
    final now = _clock.now();
    _period = mode == HistoryPeriodMode.week
        ? HistoryPeriod.week(now)
        : HistoryPeriod.month(now);
    _status = HistoryLoadStatus.loading;
    _error = null;
    notifyListeners();
    await _loadCurrentPeriod();
  }

  Future<void> goToPreviousPeriod() async {
    if (!canGoPrevious || _disposed) return;
    _period = _period.previous;
    _status = HistoryLoadStatus.loading;
    _error = null;
    notifyListeners();
    await _loadCurrentPeriod();
  }

  Future<void> goToNextPeriod() async {
    if (!canGoNext || _disposed) return;
    _period = _period.next;
    _status = HistoryLoadStatus.loading;
    _error = null;
    notifyListeners();
    await _loadCurrentPeriod();
  }

  Future<void> _loadCurrentPeriod() async {
    final requestId = _latestRequest.begin();
    try {
      final snapshot = await _loadPeriod(requestId, _allRuns, _profile);
      if (!_isCurrent(requestId) || snapshot == null) return;
      _applyPeriodSnapshot(snapshot);
      _status = HistoryLoadStatus.ready;
      notifyListeners();
    } catch (error) {
      if (!_isCurrent(requestId)) return;
      _error = error;
      _status = HistoryLoadStatus.error;
      notifyListeners();
    }
  }

  Future<_HistoryPeriodSnapshot?> _loadPeriod(
    int requestId,
    List<RunModel> allRuns,
    UserProfile? profile,
  ) async {
    final selected = _period;
    var goal = await _statsRepository.getGoalHistory(
      selected.id,
      selected.goalType,
    );
    if (!_isCurrent(requestId)) return null;

    if (goal == null) {
      goal = _defaultGoalFor(selected, profile);
      _internalWrites++;
      try {
        await _statsRepository.saveGoalHistory(
          selected.id,
          selected.goalType,
          goal,
        );
      } finally {
        _internalWrites--;
      }
      if (!_isCurrent(requestId)) return null;
    }

    final filtered = allRuns
        .where((run) => selected.contains(run.date))
        .toList();
    final totals = await _runRepository.getPaceZoneTotals(
      selected.start,
      // O SQL usa `<= end`; subtrair 1µs mantém o fim exclusivo também nas
      // faixas de ritmo, evitando o treino da meia-noite seguinte.
      selected.end.subtract(const Duration(microseconds: 1)),
    );
    if (!_isCurrent(requestId)) return null;

    final zoneTotals = <PaceZone, double>{};
    for (final entry in totals.entries) {
      final zone = PaceZone.values.where((value) => value.name == entry.key);
      if (zone.isEmpty || entry.value <= 0) continue;
      final value = zone.first;
      zoneTotals[value] = (zoneTotals[value] ?? 0) + entry.value;
    }

    final recommendation = _recommendationFor(
      selected,
      filtered,
      goal,
      allRuns,
      profile,
    );
    final chart = _buildChart(allRuns, selected);
    return _HistoryPeriodSnapshot(
      filteredRuns: filtered,
      goal: goal,
      paceZoneTotals: zoneTotals,
      recommendation: recommendation,
      chartBars: chart.$1,
      chartMaxDistance: chart.$2,
    );
  }

  RecommendationResult? _recommendationFor(
    HistoryPeriod selected,
    List<RunModel> filtered,
    double goal,
    List<RunModel> allRuns,
    UserProfile? profile,
  ) {
    if (profile == null || selected.mode != HistoryPeriodMode.week) return null;

    final now = _clock.now();
    final currentWeek = HistoryPeriod.week(now);
    if (selected.start != currentWeek.start) return null;

    final cutoff = now.subtract(const Duration(days: 30));
    final previousRuns = allRuns
        .where(
          (run) =>
              run.date.isAfter(cutoff) && run.date.isBefore(selected.start),
        )
        .toList();
    return RecommendationService.calculateWeeklyRecommendation(
      profile: profile,
      runs: filtered,
      monthRuns: previousRuns,
      currentPeriodGoal: goal,
      now: now,
    );
  }

  (List<HistoryChartBar>, double) _buildChart(
    List<RunModel> runs,
    HistoryPeriod selected,
  ) {
    final values = <double>[];
    if (selected.mode == HistoryPeriodMode.week) {
      for (var i = 0; i < 7; i++) {
        final day = DateTime(
          selected.start.year,
          selected.start.month,
          selected.start.day + i,
        );
        values.add(
          runs
              .where(
                (run) =>
                    run.date.year == day.year &&
                    run.date.month == day.month &&
                    run.date.day == day.day,
              )
              .fold(0.0, (sum, run) => sum + run.distanceKm),
        );
      }
    } else {
      var currentStart = selected.start;
      while (currentStart.isBefore(selected.end)) {
        final currentEnd = currentStart.add(const Duration(days: 7));
        final effectiveEnd = currentEnd.isAfter(selected.end)
            ? selected.end
            : currentEnd;
        values.add(
          runs
              .where(
                (run) =>
                    !run.date.isBefore(currentStart) &&
                    run.date.isBefore(effectiveEnd),
              )
              .fold(0.0, (sum, run) => sum + run.distanceKm),
        );
        currentStart = currentEnd;
      }
    }

    final maxDistance = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final scale = maxDistance == 0 ? 5.0 : maxDistance;
    return (
      [
        for (var i = 0; i < values.length; i++)
          HistoryChartBar(
            index: i,
            distanceKm: values[i],
            colorRatio: values[i] / scale,
          ),
      ],
      scale,
    );
  }

  void _applyPeriodSnapshot(_HistoryPeriodSnapshot snapshot) {
    _filteredRuns = List<RunModel>.unmodifiable(snapshot.filteredRuns);
    _currentPeriodGoal = snapshot.goal;
    _paceZoneTotals = Map<PaceZone, double>.unmodifiable(
      snapshot.paceZoneTotals,
    );
    _recommendation = snapshot.recommendation;
    _chartBars = List<HistoryChartBar>.unmodifiable(snapshot.chartBars);
    _chartMaxDistance = snapshot.chartMaxDistance;
    _updatePagination();
    _rebuildSummary();
  }

  void _updatePagination() {
    final minDate = _minDate;
    _canGoPrevious = minDate != null && minDate.isBefore(_period.start);

    final now = _clock.now();
    var effectiveMax = _maxDate == null || now.isAfter(_maxDate!)
        ? now
        : _maxDate!;
    if (_period.mode == HistoryPeriodMode.week) {
      effectiveMax = effectiveMax.add(const Duration(days: 7));
    }
    _canGoNext = effectiveMax.isAfter(
      _period.end.subtract(const Duration(microseconds: 1)),
    );
  }

  void _rebuildSummary() {
    final totalKm = _filteredRuns.fold(0.0, (sum, run) => sum + run.distanceKm);
    final totalSeconds = _filteredRuns.fold(
      0,
      (sum, run) => sum + run.durationSeconds,
    );
    final totalCalories = _filteredRuns.fold(
      0,
      (sum, run) => sum + run.calories,
    );
    final rawProgress = _currentPeriodGoal > 0
        ? totalKm / _currentPeriodGoal
        : 0.0;
    _summary = HistorySummary(
      totalKm: totalKm,
      totalSeconds: totalSeconds,
      totalCalories: totalCalories,
      estimatedWeightLossKg: totalCalories / 7700,
      rawGoalProgress: rawProgress,
      goalProgress: rawProgress.clamp(0.0, 1.0),
    );
  }

  static double? parseGoalKm(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return parsed;
  }

  Future<bool> saveGoals({
    required String periodGoalText,
    required String futureGoalText,
  }) async {
    final periodGoal = parseGoalKm(periodGoalText);
    final futureGoal = parseGoalKm(futureGoalText);
    if (periodGoal == null || futureGoal == null || _disposed || _isSaving) {
      return false;
    }

    final selected = _period;
    final profile = _profile;
    final now = _clock.now();
    _isSaving = true;
    notifyListeners();
    _internalWrites++;
    try {
      await _statsRepository.saveGoalHistory(
        selected.id,
        selected.goalType,
        periodGoal,
      );
      if (profile != null) {
        final updated = profile.copyWith(
          weeklyGoal: selected.mode == HistoryPeriodMode.week
              ? futureGoal
              : profile.weeklyGoal,
          monthlyGoal: selected.mode == HistoryPeriodMode.month
              ? futureGoal
              : profile.monthlyGoal,
          lastGoalUpdate: now,
        );
        await _userRepository.saveUserProfile(updated);
        if (!_disposed) _profile = updated;
      }
      if (_disposed) return false;

      _error = null;
      // Se a navegação aconteceu durante o save, não aplica a meta antiga ao
      // período recém-aberto. O perfil futuro ainda foi salvo corretamente.
      if (_period.id == selected.id && _period.goalType == selected.goalType) {
        _currentPeriodGoal = periodGoal;
        _recommendation = null;
        _rebuildSummary();
      }
      return true;
    } catch (error) {
      if (!_disposed) _error = error;
      return false;
    } finally {
      _internalWrites--;
      _isSaving = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> applyRecommendation() async {
    final recommendation = _recommendation;
    final profile = _profile;
    if (recommendation == null || profile == null || _disposed || _isSaving) {
      return false;
    }

    final now = _clock.now();
    final nextWeek = _period.next;
    _isSaving = true;
    notifyListeners();
    _internalWrites++;
    try {
      await _statsRepository.saveGoalHistory(
        nextWeek.id,
        nextWeek.goalType,
        recommendation.recommendedGoal,
      );
      final updated = profile.copyWith(
        weeklyGoal: recommendation.recommendedGoal,
        lastGoalUpdate: now,
      );
      await _userRepository.saveUserProfile(updated);
      if (_disposed) return false;

      _profile = updated;
      _recommendation = null;
      _error = null;
      return true;
    } catch (error) {
      if (!_disposed) _error = error;
      return false;
    } finally {
      _internalWrites--;
      _isSaving = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _onDataChanged() {
    if (_internalWrites > 0 || _disposed) return;
    unawaited(refresh());
  }

  bool _isCurrent(int requestId) =>
      !_disposed && _latestRequest.isCurrent(requestId);

  double _defaultGoalFor(HistoryPeriod selected, UserProfile? profile) {
    return selected.mode == HistoryPeriodMode.week
        ? (profile?.weeklyGoal ?? 20)
        : (profile?.monthlyGoal ?? 80);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _latestRequest.begin();
    _dataListenable?.removeListener(_onDataChanged);
    _dataListenable = null;
    super.dispose();
  }
}

class _HistoryPeriodSnapshot {
  final List<RunModel> filteredRuns;
  final double goal;
  final Map<PaceZone, double> paceZoneTotals;
  final RecommendationResult? recommendation;
  final List<HistoryChartBar> chartBars;
  final double chartMaxDistance;

  const _HistoryPeriodSnapshot({
    required this.filteredRuns,
    required this.goal,
    required this.paceZoneTotals,
    required this.recommendation,
    required this.chartBars,
    required this.chartMaxDistance,
  });
}
