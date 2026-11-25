import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runlabag/core/data/data_change_hub.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';
import 'package:runlabag/core/domain/models/user_stats.dart';
import 'package:runlabag/core/domain/models/user_totals.dart';
import 'package:runlabag/core/domain/repositories/active_run_repository.dart';
import 'package:runlabag/core/domain/repositories/run_repository.dart';
import 'package:runlabag/core/domain/repositories/stats_repository.dart';
import 'package:runlabag/core/domain/repositories/user_repository.dart';
import 'package:runlabag/core/utils/clock.dart';
import 'package:runlabag/features/dashboard/application/home_dashboard_view_model.dart';
import 'package:runlabag/features/dashboard/application/home_stats_window_store.dart';

class _FixedClock implements Clock {
  DateTime current;

  _FixedClock(this.current);

  @override
  DateTime now() => current;

  @override
  Timer periodic(Duration interval, void Function(Timer timer) callback) =>
      throw UnimplementedError();
}

class _MemoryHomeStatsWindowStore implements HomeStatsWindowStore {
  int? value;
  Object? readError;
  Object? writeError;
  int reads = 0;
  final List<int> writes = [];

  @override
  Future<int?> readStatsPeriod() async {
    reads++;
    final error = readError;
    if (error != null) throw error;
    return value;
  }

  @override
  Future<void> writeStatsPeriod(int statsPeriod) async {
    final error = writeError;
    if (error != null) throw error;
    writes.add(statsPeriod);
    value = statsPeriod;
  }
}

class _FakeStatsRepository implements StatsRepository {
  int calls = 0;
  int weeklyProgressCalls = 0;
  final List<DateTime?> requestedSince = [];
  final List<Completer<UserStats>> pendingStats = [];
  List<double> weeklyProgress = const [0, 1, 2, 3, 4, 5, 6];

  @override
  Future<UserStats> getUserStats({DateTime? since}) {
    calls++;
    requestedSince.add(since);
    final completer = Completer<UserStats>();
    pendingStats.add(completer);
    return completer.future;
  }

  @override
  Future<List<double>> getWeeklyProgress() async {
    weeklyProgressCalls++;
    return weeklyProgress;
  }

  void completeNext(UserStats stats) {
    expect(pendingStats, isNotEmpty);
    pendingStats.removeAt(0).complete(stats);
  }

  void failNext(Object error) {
    expect(pendingStats, isNotEmpty);
    pendingStats.removeAt(0).completeError(error, StackTrace.current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRepository implements UserRepository {
  int calls = 0;
  UserProfile? profile = _profile();

  @override
  Future<UserProfile?> getUserProfile() async {
    calls++;
    return profile;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRunRepository implements RunRepository {
  int calls = 0;
  RunModel? lastRun = _run();

  @override
  Future<RunModel?> getLastRunSummary() async {
    calls++;
    return lastRun;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActiveRunRepository implements ActiveRunRepository {
  int metaCalls = 0;
  int fullCalls = 0;
  int clearCalls = 0;
  Map<String, dynamic>? meta;
  Map<String, dynamic>? activeRun = <String, dynamic>{'id': 'active'};
  Object? metaError;
  Completer<Map<String, dynamic>?>? metaGate;

  @override
  Future<Map<String, dynamic>?> getActiveRunMeta() {
    metaCalls++;
    final error = metaError;
    if (error != null) return Future<Map<String, dynamic>?>.error(error);
    final gate = metaGate;
    if (gate != null) return gate.future;
    return Future<Map<String, dynamic>?>.value(meta);
  }

  @override
  Future<Map<String, dynamic>?> getActiveRun() async {
    fullCalls++;
    return activeRun;
  }

  @override
  Future<void> clearActiveRun() async {
    clearCalls++;
    meta = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fixture {
  final clock = _FixedClock(DateTime(2026, 11, 24, 23, 48));
  final windowStore = _MemoryHomeStatsWindowStore();
  final statsRepository = _FakeStatsRepository();
  final userRepository = _FakeUserRepository();
  final runRepository = _FakeRunRepository();
  final activeRunRepository = _FakeActiveRunRepository();
  late final HomeDashboardViewModel viewModel;
  bool _disposed = false;

  _Fixture({bool embedded = false, Listenable? dataChanges}) {
    viewModel = HomeDashboardViewModel(
      statsRepository: statsRepository,
      userRepository: userRepository,
      runRepository: runRepository,
      activeRunRepository: activeRunRepository,
      statsWindowStore: windowStore,
      clock: clock,
      embedded: embedded,
      dataChanges: dataChanges,
    );
  }

  Future<void> initializeSuccessfully({
    UserStats? stats,
    Map<String, dynamic>? activeRunMeta,
    bool initialize = true,
  }) async {
    activeRunRepository.meta = activeRunMeta;
    final loading = initialize ? viewModel.initialize() : viewModel.load();
    await _flushMicrotasks();
    statsRepository.completeNext(stats ?? _stats(10));
    await loading;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    viewModel.dispose();
  }
}

UserStats _stats(double distanceKm) => UserStats(
  totals: UserTotals(
    runCount: 1,
    totalDistanceKm: distanceKm,
    totalSeconds: 600,
    totalCalories: 50,
  ),
  averagePaceSecondsPerKm: 360,
);

UserProfile _profile({double weeklyGoal = 20}) => UserProfile(
  name: 'Atleta',
  age: 30,
  weight: 70,
  height: 175,
  weeklyGoal: weeklyGoal,
);

RunModel _run({String id = 'last', int durationSeconds = 125}) => RunModel(
  id: id,
  date: DateTime(2026, 11, 24, 10),
  distanceKm: 5,
  durationSeconds: durationSeconds,
  pace: '5:00',
  calories: 300,
);

Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _Fixture createFixture({bool embedded = false, Listenable? dataChanges}) {
    final fixture = _Fixture(embedded: embedded, dataChanges: dataChanges);
    addTearDown(fixture.dispose);
    return fixture;
  }

  test('rótulos das janelas mantêm a ordem e os valores existentes', () {
    expect(HomeDashboardViewModel.statsPeriodLabels, [
      'Tudo',
      '7d',
      '15d',
      '30d',
      '60d',
      '90d',
    ]);
  });

  test('store do SharedPreferences mantém a chave da janela', () async {
    SharedPreferences.setMockInitialValues({'home_stats_period': 4});
    const store = SharedPreferencesHomeStatsWindowStore();

    expect(await store.readStatsPeriod(), 4);
    await store.writeStatsPeriod(5);
    expect(
      await const SharedPreferencesHomeStatsWindowStore().readStatsPeriod(),
      5,
    );
  });

  test('janela persistida válida é restaurada e aplicada à consulta', () async {
    final now = DateTime(2026, 11, 24, 23, 48);
    const daysByPeriod = [0, 7, 15, 30, 60, 90];

    for (var period = 0; period < daysByPeriod.length; period++) {
      final fixture = createFixture();
      fixture.windowStore.value = period;

      await fixture.initializeSuccessfully();

      expect(fixture.viewModel.selectedStatsPeriod, period);
      expect(fixture.statsRepository.requestedSince, [
        daysByPeriod[period] == 0
            ? null
            : now.subtract(Duration(days: daysByPeriod[period])),
      ]);
      expect(fixture.windowStore.writes, isEmpty);
    }
  });

  test('janela persistida inválida cai para Tudo', () async {
    for (final invalidPeriod in [-1, 6, 99]) {
      final fixture = createFixture();
      fixture.windowStore.value = invalidPeriod;

      await fixture.initializeSuccessfully();

      expect(fixture.viewModel.selectedStatsPeriod, 0);
      expect(fixture.statsRepository.requestedSince, [null]);
    }
  });

  test('troca inválida ou repetida não consulta nem persiste', () async {
    final fixture = createFixture();
    await fixture.initializeSuccessfully();

    await fixture.viewModel.changeStatsPeriod(-1);
    await fixture.viewModel.changeStatsPeriod(6);
    await fixture.viewModel.changeStatsPeriod(0);

    expect(fixture.viewModel.selectedStatsPeriod, 0);
    expect(fixture.statsRepository.calls, 1);
    expect(fixture.windowStore.writes, isEmpty);
  });

  test('carga inicial dispara todas as consultas em paralelo', () async {
    final fixture = createFixture();
    final metaGate = Completer<Map<String, dynamic>?>();
    fixture.activeRunRepository.metaGate = metaGate;

    final loading = fixture.viewModel.initialize();
    await _flushMicrotasks();

    expect(fixture.windowStore.reads, 1);
    expect(fixture.statsRepository.calls, 1);
    expect(fixture.statsRepository.weeklyProgressCalls, 1);
    expect(fixture.userRepository.calls, 1);
    expect(fixture.runRepository.calls, 1);
    expect(fixture.activeRunRepository.metaCalls, 1);
    expect(fixture.viewModel.isLoading, isTrue);

    fixture.statsRepository.completeNext(_stats(12));
    await _flushMicrotasks();

    expect(fixture.viewModel.isLoading, isTrue);
    expect(fixture.viewModel.stats, UserStats.empty);

    metaGate.complete(null);
    await loading;

    expect(fixture.viewModel.isLoading, isFalse);
    expect(fixture.viewModel.stats.totals.totalDistanceKm, 12);
  });

  test('troca rápida não publica resultado antigo', () async {
    final fixture = createFixture();
    await fixture.initializeSuccessfully(stats: _stats(10));

    final firstChange = fixture.viewModel.changeStatsPeriod(1);
    await _flushMicrotasks();
    final secondChange = fixture.viewModel.changeStatsPeriod(2);
    await _flushMicrotasks();

    expect(fixture.viewModel.selectedStatsPeriod, 2);
    expect(fixture.statsRepository.requestedSince.skip(1), [
      DateTime(2026, 11, 17, 23, 48),
      DateTime(2026, 11, 9, 23, 48),
    ]);

    fixture.statsRepository.pendingStats.last.complete(_stats(20));
    await secondChange;
    expect(fixture.viewModel.stats.totals.totalDistanceKm, 20);

    fixture.statsRepository.pendingStats.first.complete(_stats(99));
    await firstChange;

    expect(fixture.viewModel.stats.totals.totalDistanceKm, 20);
    expect(fixture.windowStore.writes, [1, 2]);
    expect(fixture.windowStore.value, 2);
  });

  test('erro preserva o estado anterior e encerra o loading', () async {
    final fixture = createFixture();
    await fixture.initializeSuccessfully(stats: _stats(10));
    final previousStats = fixture.viewModel.stats;
    final previousProgress = fixture.viewModel.weeklyProgress;
    final previousProfile = fixture.viewModel.profile;
    final previousRun = fixture.viewModel.lastRun;
    final failure = StateError('falha ao carregar');

    final loading = fixture.viewModel.load();
    await _flushMicrotasks();
    fixture.statsRepository.failNext(failure);
    await loading;

    expect(fixture.viewModel.hasError, isTrue);
    expect(fixture.viewModel.error, same(failure));
    expect(fixture.viewModel.isLoading, isFalse);
    expect(fixture.viewModel.stats, same(previousStats));
    expect(fixture.viewModel.weeklyProgress, same(previousProgress));
    expect(fixture.viewModel.profile, same(previousProfile));
    expect(fixture.viewModel.lastRun, same(previousRun));

    await fixture.initializeSuccessfully(stats: _stats(30), initialize: false);

    expect(fixture.viewModel.hasError, isFalse);
    expect(fixture.viewModel.stats.totals.totalDistanceKm, 30);
  });

  test('falha na primeira carga não deixa spinner infinito', () async {
    final fixture = createFixture();
    final failure = StateError('boot falhou');

    final loading = fixture.viewModel.initialize();
    await _flushMicrotasks();
    fixture.statsRepository.failNext(failure);
    await loading;

    expect(fixture.viewModel.isLoading, isFalse);
    expect(fixture.viewModel.hasError, isTrue);
    expect(fixture.viewModel.error, same(failure));
    expect(fixture.viewModel.stats, UserStats.empty);
    expect(fixture.viewModel.weeklyProgress, hasLength(7));
  });

  test('falha na recuperação não bloqueia o dashboard', () async {
    final fixture = createFixture();
    fixture.activeRunRepository.metaError = StateError('meta indisponível');

    await fixture.initializeSuccessfully(stats: _stats(9));

    expect(fixture.viewModel.isLoading, isFalse);
    expect(fixture.viewModel.hasLoaded, isTrue);
    expect(fixture.viewModel.hasError, isFalse);
    expect(fixture.viewModel.stats.totals.totalDistanceKm, 9);
    expect(fixture.viewModel.hasPendingRecovery, isFalse);
  });

  test('falha ao restaurar preferência não impede a carga', () async {
    final fixture = createFixture();
    fixture.windowStore.readError = StateError('prefs indisponível');

    await fixture.initializeSuccessfully(stats: _stats(7));

    expect(fixture.viewModel.selectedStatsPeriod, 0);
    expect(fixture.viewModel.hasError, isFalse);
    expect(fixture.viewModel.stats.totals.totalDistanceKm, 7);
  });

  test('escopos irrelevantes não recarregam a Home', () async {
    final hub = DataChangeHub();
    addTearDown(hub.dispose);
    final fixture = createFixture(
      dataChanges: hub.listenableFor({
        DataScope.runs,
        DataScope.profile,
        DataScope.goals,
      }),
    );
    await fixture.initializeSuccessfully();

    hub.emit({DataScope.achievements});
    hub.emit({DataScope.monitoredDistances});
    hub.emit({DataScope.strength});
    await _flushMicrotasks();

    expect(fixture.statsRepository.calls, 1);
    expect(fixture.statsRepository.weeklyProgressCalls, 1);
    expect(fixture.userRepository.calls, 1);
    expect(fixture.runRepository.calls, 1);
    expect(fixture.activeRunRepository.metaCalls, 1);

    hub.emit({DataScope.goals});
    await _flushMicrotasks();

    expect(fixture.statsRepository.calls, 2);
    fixture.statsRepository.completeNext(_stats(11));
    await _flushMicrotasks();
    expect(fixture.viewModel.stats.totals.totalDistanceKm, 11);
  });

  test('modo embutido não verifica recuperação', () async {
    final fixture = createFixture(embedded: true);

    await fixture.initializeSuccessfully(activeRunMeta: const {'finished': 0});
    await fixture.initializeSuccessfully(initialize: false);

    expect(fixture.activeRunRepository.metaCalls, 0);
    expect(fixture.activeRunRepository.fullCalls, 0);
    expect(fixture.viewModel.hasPendingRecovery, isFalse);
    expect(fixture.viewModel.takePendingRecovery(), isNull);
  });

  test('recuperação pendente é consumida uma vez', () async {
    final fixture = createFixture();
    const meta = {'finished': 0, 'distance': 2.5};

    await fixture.initializeSuccessfully(activeRunMeta: meta);

    expect(fixture.viewModel.hasPendingRecovery, isTrue);
    expect(fixture.viewModel.takePendingRecovery(), meta);
    expect(fixture.viewModel.takePendingRecovery(), isNull);
    expect(fixture.viewModel.hasPendingRecovery, isFalse);
    expect(fixture.activeRunRepository.fullCalls, 0);
  });

  test('descarte e retomada usam o repositório apenas sob demanda', () async {
    final fixture = createFixture();
    final fullRun = <String, dynamic>{'id': 'active'};
    fixture.activeRunRepository.activeRun = fullRun;

    await fixture.initializeSuccessfully(activeRunMeta: const {'finished': 1});
    expect(fixture.activeRunRepository.fullCalls, 0);

    fixture.viewModel.takePendingRecovery();
    final restored = await fixture.viewModel.loadActiveRunForResume();

    expect(restored, same(fullRun));
    expect(fixture.activeRunRepository.fullCalls, 1);
    expect(fixture.activeRunRepository.clearCalls, 0);

    await fixture.initializeSuccessfully(
      activeRunMeta: const {'finished': 1},
      initialize: false,
    );
    await fixture.viewModel.discardActiveRun();

    expect(fixture.activeRunRepository.clearCalls, 1);
    expect(fixture.activeRunRepository.fullCalls, 1);
    expect(fixture.viewModel.hasPendingRecovery, isFalse);
  });

  test('dispose não notifica nem permite publicar carga antiga', () async {
    final hub = DataChangeHub();
    addTearDown(hub.dispose);
    final fixture = createFixture(
      dataChanges: hub.listenableFor({DataScope.runs}),
    );
    await fixture.initializeSuccessfully(stats: _stats(10));
    var notifications = 0;
    fixture.viewModel.addListener(() => notifications++);

    final loading = fixture.viewModel.load();
    notifications = 0;
    await _flushMicrotasks();
    fixture.dispose();
    fixture.statsRepository.completeNext(_stats(99));
    await loading;

    expect(notifications, 0);
    expect(fixture.viewModel.stats.totals.totalDistanceKm, 10);

    final callsBefore = fixture.statsRepository.calls;
    hub.emit({DataScope.runs});
    await _flushMicrotasks();
    expect(fixture.statsRepository.calls, callsBefore);
  });

  test(
    'progresso semanal é limitado e o gráfico tem piso e headroom',
    () async {
      final fixture = createFixture();
      fixture.statsRepository.weeklyProgress = [1, 2, 3, 4, 5, 6, 7];
      fixture.runRepository.lastRun = _run(durationSeconds: 3661);

      await fixture.initializeSuccessfully();

      expect(fixture.viewModel.weeklyTotal, 28);
      expect(fixture.viewModel.weeklyGoal, 20);
      expect(fixture.viewModel.rawGoalProgress, 1.4);
      expect(fixture.viewModel.goalProgress, 1.0);
      expect(fixture.viewModel.chartMaxY, 9);
      expect(fixture.viewModel.lastRunDurationLabel, '1h 1m');

      fixture.userRepository.profile = _profile(weeklyGoal: 0);
      await fixture.initializeSuccessfully(initialize: false);
      expect(fixture.viewModel.rawGoalProgress, 0);
      expect(fixture.viewModel.goalProgress, 0);

      fixture.userRepository.profile = _profile(weeklyGoal: 10);
      fixture.statsRepository.weeklyProgress = [-5, 0, 0, 0, 0, 0, 0];
      await fixture.initializeSuccessfully(initialize: false);
      expect(fixture.viewModel.rawGoalProgress, -0.5);
      expect(fixture.viewModel.goalProgress, 0);

      const chartCases = [(0.0, 2.0), (1.99, 2.0), (2.0, 3.0), (10.0, 12.0)];
      for (final (maxDistance, expectedMaxY) in chartCases) {
        fixture.statsRepository.weeklyProgress = [
          maxDistance,
          0,
          0,
          0,
          0,
          0,
          0,
        ];
        await fixture.initializeSuccessfully(initialize: false);
        expect(fixture.viewModel.chartMaxY, expectedMaxY);
      }
    },
  );

  test('saudação e dia da semana usam o relógio injetado', () async {
    final fixture = createFixture();
    final cases = <DateTime, String>{
      DateTime(2026, 11, 24, 4, 59): 'Boa noite,',
      DateTime(2026, 11, 24, 5): 'Bom dia,',
      DateTime(2026, 11, 24, 11, 59): 'Bom dia,',
      DateTime(2026, 11, 24, 12): 'Boa tarde,',
      DateTime(2026, 11, 24, 17, 59): 'Boa tarde,',
      DateTime(2026, 11, 24, 18): 'Boa noite,',
    };

    for (final entry in cases.entries) {
      fixture.clock.current = entry.key;
      expect(fixture.viewModel.greeting, entry.value);
    }

    fixture.clock.current = DateTime(2026, 11, 22);
    expect(fixture.viewModel.todayIndex, 0);
    fixture.clock.current = DateTime(2026, 11, 23);
    expect(fixture.viewModel.todayIndex, 1);
    fixture.clock.current = DateTime(2026, 11, 28);
    expect(fixture.viewModel.todayIndex, 6);
  });

  test('duração do último treino preserva a formatação', () async {
    final fixture = createFixture();
    final cases = <int, String>{
      0: '0m 00s',
      125: '2m 05s',
      3599: '59m 59s',
      3600: '1h 0m',
      3661: '1h 1m',
    };

    for (final entry in cases.entries) {
      fixture.runRepository.lastRun = _run(durationSeconds: entry.key);
      await fixture.initializeSuccessfully(initialize: false);
      expect(fixture.viewModel.lastRunDurationLabel, entry.value);
    }
  });
}
