import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:runlabag/core/data/data_change_hub.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';
import 'package:runlabag/core/domain/repositories/run_repository.dart';
import 'package:runlabag/core/domain/repositories/stats_repository.dart';
import 'package:runlabag/core/domain/repositories/user_repository.dart';
import 'package:runlabag/core/utils/clock.dart';
import 'package:runlabag/features/history/application/history_dashboard_view_model.dart';

class HistoryGoalWrite {
  final String periodId;
  final String goalType;
  final double value;

  const HistoryGoalWrite({
    required this.periodId,
    required this.goalType,
    required this.value,
  });
}

class FakeRunRepository implements RunRepository {
  List<RunModel> runs;
  Future<List<RunModel>> Function()? summariesLoader;
  Future<Map<String, double>> Function(DateTime start, DateTime end)?
  paceZonesLoader;
  Map<String, double> paceZoneTotals = {};

  int summariesCalls = 0;
  final List<(DateTime, DateTime)> paceZoneRanges = [];

  FakeRunRepository({List<RunModel>? runs}) : runs = List.of(runs ?? const []);

  @override
  Future<List<RunModel>> getSummaries() async {
    summariesCalls++;
    final loader = summariesLoader;
    if (loader != null) return loader();
    return List.of(runs);
  }

  @override
  Future<Map<String, double>> getPaceZoneTotals(
    DateTime start,
    DateTime end,
  ) async {
    paceZoneRanges.add((start, end));
    final loader = paceZonesLoader;
    if (loader != null) return loader(start, end);
    return Map<String, double>.of(paceZoneTotals);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStatsRepository implements StatsRepository {
  final Map<String, double> goals = {};
  final Map<String, Completer<double?>> goalGates = {};
  final List<HistoryGoalWrite> writes = [];
  Future<void> Function()? onSave;

  int goalReads = 0;

  static String _key(String goalType, String periodId) => '$goalType:$periodId';

  @override
  Future<double?> getGoalHistory(String periodId, String goalType) async {
    goalReads++;
    final gate = goalGates[_key(goalType, periodId)];
    if (gate != null) return gate.future;
    return goals[_key(goalType, periodId)];
  }

  @override
  Future<void> saveGoalHistory(
    String periodId,
    String goalType,
    double goalValue,
  ) async {
    writes.add(
      HistoryGoalWrite(
        periodId: periodId,
        goalType: goalType,
        value: goalValue,
      ),
    );
    goals[_key(goalType, periodId)] = goalValue;
    await onSave?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserRepository implements UserRepository {
  UserProfile? profile;
  Future<UserProfile?> Function()? profileLoader;
  Future<void> Function(UserProfile profile)? saveProfileHandler;
  final List<UserProfile> savedProfiles = [];

  FakeUserRepository({this.profile});

  @override
  Future<UserProfile?> getUserProfile() async {
    final loader = profileLoader;
    if (loader != null) return loader();
    return profile;
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    final handler = saveProfileHandler;
    if (handler != null) await handler(profile);
    savedProfiles.add(profile);
    this.profile = profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDataChangeHub implements DataChangeHub {
  final Map<DataScope, ValueNotifier<int>> _signals = {
    for (final scope in DataScope.values) scope: ValueNotifier<int>(0),
  };
  final Map<String, Listenable> _listenables = {};
  bool _disposed = false;

  @override
  Listenable listenableFor(Set<DataScope> scopes) {
    final ordered = ({...scopes, DataScope.all}.toList())
      ..sort((a, b) => a.index.compareTo(b.index));
    final key = ordered.map((scope) => scope.name).join('|');
    return _listenables.putIfAbsent(
      key,
      () => Listenable.merge([for (final scope in ordered) _signals[scope]!]),
    );
  }

  @override
  void emit(Set<DataScope> scopes) {
    if (_disposed || scopes.isEmpty) return;
    final normalized = scopes.contains(DataScope.all)
        ? const {DataScope.all}
        : scopes;
    for (final scope in normalized) {
      _signals[scope]!.value++;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final signal in _signals.values) {
      signal.dispose();
    }
    _listenables.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClock implements Clock {
  DateTime current;

  FakeClock(this.current);

  @override
  DateTime now() => current;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class HistoryDashboardHarness {
  final FakeClock clock;
  final FakeRunRepository runs;
  final FakeStatsRepository stats;
  final FakeUserRepository users;
  final FakeDataChangeHub hub;
  late final HistoryDashboardViewModel viewModel;

  HistoryDashboardHarness({
    required DateTime now,
    List<RunModel> runs = const [],
    UserProfile? profile,
    Map<String, double> goals = const {},
  }) : clock = FakeClock(now),
       runs = FakeRunRepository(runs: runs),
       stats = FakeStatsRepository()..goals.addAll(goals),
       users = FakeUserRepository(profile: profile),
       hub = FakeDataChangeHub() {
    viewModel = HistoryDashboardViewModel(
      runRepository: this.runs,
      statsRepository: stats,
      userRepository: users,
      changes: hub,
      clock: clock,
    );
  }

  void close() {
    viewModel.dispose();
    hub.dispose();
  }
}

UserProfile historyTestProfile({
  double weeklyGoal = 20,
  double monthlyGoal = 80,
  DateTime? lastGoalUpdate,
  bool kmNotificationsEnabled = true,
}) {
  return UserProfile(
    name: 'Runner',
    age: 30,
    weight: 70,
    height: 170,
    profilePicturePath: 'profile.jpg',
    weeklyGoal: weeklyGoal,
    monthlyGoal: monthlyGoal,
    lastGoalUpdate: lastGoalUpdate,
    kmNotificationsEnabled: kmNotificationsEnabled,
  );
}

RunModel historyTestRun({
  required String id,
  required DateTime date,
  double distanceKm = 5,
  int durationSeconds = 1800,
  int calories = 350,
  String mood = '',
}) {
  return RunModel(
    id: id,
    date: date,
    distanceKm: distanceKm,
    durationSeconds: durationSeconds,
    pace: '6:00',
    calories: calories,
    mood: mood,
  );
}

Future<void> flushHistoryEvents() => Future<void>.delayed(Duration.zero);
