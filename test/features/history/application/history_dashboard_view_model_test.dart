import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/data/data_change_hub.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';
import 'package:runlabag/core/domain/services/pace_zone_service.dart';
import 'package:runlabag/features/history/application/history_dashboard_view_model.dart';
import 'package:runlabag/features/history/domain/history_period.dart';

import '../history_dashboard_test_support.dart';

void main() {
  HistoryDashboardHarness buildHarness({
    required DateTime now,
    List<RunModel> runs = const [],
    UserProfile? profile,
    Map<String, double> goals = const {},
  }) {
    final harness = HistoryDashboardHarness(
      now: now,
      runs: runs,
      profile: profile,
      goals: goals,
    );
    addTearDown(harness.close);
    return harness;
  }

  group('HistoryPeriod', () {
    test('semana começa no domingo e troca o ano no ID seguinte', () {
      final period = HistoryPeriod.week(DateTime(2025, 12, 31, 23, 59));

      expect(period.start, DateTime(2025, 12, 28));
      expect(period.end, DateTime(2026, 1, 4));
      expect(period.id, '2025-W52');
      expect(period.contains(period.start), isTrue);
      expect(period.contains(period.end), isFalse);

      final next = period.next;
      expect(next.start, DateTime(2026, 1, 4));
      expect(next.id, '2026-W01');
    });

    test('mês de fevereiro inclui o dia 29 em ano bissexto', () {
      final period = HistoryPeriod.month(DateTime(2024, 2, 29, 12));

      expect(period.start, DateTime(2024, 2, 1));
      expect(period.end, DateTime(2024, 3, 1));
      expect(period.end.difference(period.start).inDays, 29);
      expect(period.contains(DateTime(2024, 2, 29, 23, 59)), isTrue);
      expect(period.contains(DateTime(2024, 3, 1)), isFalse);
      expect(period.previous.id, '2024-01');
      expect(period.next.id, '2024-03');
    });
  });

  group('HistoryDashboardViewModel', () {
    test('não sobrescreve meta histórica existente', () async {
      final now = DateTime(2026, 11, 24, 12);
      final current = HistoryPeriod.week(now);
      final harness = buildHarness(
        now: now,
        profile: historyTestProfile(weeklyGoal: 20),
        goals: {'weekly:${current.id}': 33.5},
      );

      await harness.viewModel.initialize();

      expect(harness.viewModel.status, HistoryLoadStatus.ready);
      expect(harness.viewModel.currentPeriodGoal, 33.5);
      expect(harness.stats.writes, isEmpty);
    });

    test('cria meta ausente uma única vez sem loop de notificações', () async {
      final now = DateTime(2026, 11, 24, 12);
      final current = HistoryPeriod.week(now);
      final harness = buildHarness(
        now: now,
        profile: historyTestProfile(weeklyGoal: 27.5),
      );
      harness.stats.onSave = () async => harness.hub.emit({DataScope.goals});

      await harness.viewModel.initialize();
      await flushHistoryEvents();
      await flushHistoryEvents();

      expect(harness.stats.writes, hasLength(1));
      expect(harness.stats.writes.single.periodId, current.id);
      expect(harness.stats.writes.single.goalType, 'weekly');
      expect(harness.stats.writes.single.value, 27.5);
      expect(harness.viewModel.currentPeriodGoal, 27.5);
      expect(harness.runs.summariesCalls, 1);
    });

    test('fallback mensal usa monthlyGoal', () async {
      final now = DateTime(2026, 11, 24, 12);
      final currentWeek = HistoryPeriod.week(now);
      final harness = buildHarness(
        now: now,
        profile: historyTestProfile(weeklyGoal: 20, monthlyGoal: 123.5),
        goals: {'weekly:${currentWeek.id}': 20},
      );
      await harness.viewModel.initialize();

      await harness.viewModel.selectMonth();

      expect(harness.viewModel.period.id, '2026-11');
      expect(harness.viewModel.defaultGoal, 123.5);
      expect(harness.viewModel.currentPeriodGoal, 123.5);
      expect(harness.stats.writes, hasLength(1));
      expect(harness.stats.writes.single.periodId, '2026-11');
      expect(harness.stats.writes.single.goalType, 'monthly');
      expect(harness.stats.writes.single.value, 123.5);
    });

    test('navegação rápida descarta o resultado do período antigo', () async {
      final now = DateTime(2026, 11, 24, 12);
      final current = HistoryPeriod.week(now);
      final previous = current.previous;
      final harness = buildHarness(
        now: now,
        runs: [
          historyTestRun(id: 'old', date: DateTime(2026, 11, 1)),
          historyTestRun(id: 'current', date: DateTime(2026, 11, 24)),
        ],
        goals: {'weekly:${current.id}': 20, 'weekly:${previous.id}': 12},
      );
      final previousGoal = Completer<double?>();
      harness.stats.goalGates['weekly:${previous.id}'] = previousGoal;
      await harness.viewModel.initialize();

      final oldNavigation = harness.viewModel.goToPreviousPeriod();
      await flushHistoryEvents();
      expect(harness.viewModel.period.id, previous.id);

      await harness.viewModel.goToNextPeriod();
      expect(harness.viewModel.period.id, current.id);
      expect(harness.viewModel.filteredRuns.single.id, 'current');

      previousGoal.complete(12);
      await oldNavigation;

      expect(harness.viewModel.status, HistoryLoadStatus.ready);
      expect(harness.viewModel.period.id, current.id);
      expect(harness.viewModel.filteredRuns.single.id, 'current');
      expect(harness.viewModel.summary.totalKm, 5);
    });

    test('falha não publica estado parcial', () async {
      final now = DateTime(2026, 11, 24, 12);
      final current = HistoryPeriod.week(now);
      final harness = buildHarness(
        now: now,
        runs: [historyTestRun(id: 'stable', date: DateTime(2026, 11, 24))],
        profile: historyTestProfile(weeklyGoal: 20),
        goals: {'weekly:${current.id}': 20},
      );
      harness.runs.paceZoneTotals = {'running': 5};
      await harness.viewModel.initialize();
      final originalProfile = harness.viewModel.profile;

      harness.runs.runs.add(
        historyTestRun(id: 'partial', date: DateTime(2026, 11, 24, 18)),
      );
      harness.users.profile = historyTestProfile(weeklyGoal: 99);
      harness.runs.paceZonesLoader = (start, end) async {
        throw StateError('falha nas faixas de ritmo');
      };

      await harness.viewModel.refresh();

      expect(harness.viewModel.status, HistoryLoadStatus.error);
      expect(harness.viewModel.error, isA<StateError>());
      expect(harness.viewModel.allRuns.map((run) => run.id), ['stable']);
      expect(harness.viewModel.filteredRuns.map((run) => run.id), ['stable']);
      expect(identical(harness.viewModel.profile, originalProfile), isTrue);
      expect(harness.viewModel.summary.totalKm, 5);
      expect(harness.viewModel.paceZoneTotals[PaceZone.running], 5);
      expect(harness.viewModel.currentPeriodGoal, 20);
    });

    test(
      'saveGoals aceita vírgula, preserva perfil e bloqueia submit repetido',
      () async {
        final now = DateTime(2026, 11, 24, 12);
        final current = HistoryPeriod.week(now);
        final previousUpdate = DateTime(2026, 1, 1);
        final harness = buildHarness(
          now: now,
          profile: historyTestProfile(
            weeklyGoal: 20,
            monthlyGoal: 99,
            lastGoalUpdate: previousUpdate,
            kmNotificationsEnabled: false,
          ),
          goals: {'weekly:${current.id}': 20},
        );
        await harness.viewModel.initialize();
        final saveGate = Completer<void>();
        harness.users.saveProfileHandler = (_) => saveGate.future;

        final firstSave = harness.viewModel.saveGoals(
          periodGoalText: '25,5',
          futureGoalText: '30,5',
        );
        await flushHistoryEvents();

        expect(harness.viewModel.isSaving, isTrue);
        expect(
          await harness.viewModel.saveGoals(
            periodGoalText: '40,0',
            futureGoalText: '50,0',
          ),
          isFalse,
        );
        expect(harness.stats.writes, hasLength(1));

        saveGate.complete();
        expect(await firstSave, isTrue);

        final saved = harness.users.savedProfiles.single;
        expect(saved.weeklyGoal, 30.5);
        expect(saved.monthlyGoal, 99);
        expect(saved.kmNotificationsEnabled, isFalse);
        expect(saved.lastGoalUpdate, now);
        expect(harness.viewModel.currentPeriodGoal, 25.5);
        expect(harness.viewModel.isSaving, isFalse);
      },
    );

    test('recomendação aplica a meta no ID da semana seguinte', () async {
      final now = DateTime(2026, 11, 28, 12); // sábado
      final current = HistoryPeriod.week(now);
      final harness = buildHarness(
        now: now,
        runs: [
          historyTestRun(
            id: 'current',
            date: DateTime(2026, 11, 28, 8),
            distanceKm: 21,
          ),
        ],
        profile: historyTestProfile(
          weeklyGoal: 20,
          monthlyGoal: 111,
          kmNotificationsEnabled: false,
        ),
        goals: {'weekly:${current.id}': 20},
      );
      await harness.viewModel.initialize();
      final recommendation = harness.viewModel.recommendation;

      expect(recommendation, isNotNull);
      expect(recommendation!.recommendedGoal, 21);
      expect(await harness.viewModel.applyRecommendation(), isTrue);

      final nextWeek = harness.viewModel.period.next;
      expect(nextWeek.start, DateTime(2026, 11, 29));
      expect(harness.stats.writes, hasLength(1));
      expect(harness.stats.writes.single.periodId, nextWeek.id);
      expect(harness.stats.writes.single.goalType, 'weekly');
      expect(harness.stats.writes.single.value, 21);
      expect(harness.stats.goals['weekly:${nextWeek.id}'], 21);

      final saved = harness.users.savedProfiles.single;
      expect(saved.weeklyGoal, 21);
      expect(saved.monthlyGoal, 111);
      expect(saved.kmNotificationsEnabled, isFalse);
      expect(saved.lastGoalUpdate, now);
      expect(harness.viewModel.recommendation, isNull);
    });

    test('barras mensais usam o máximo final para cor e escala', () async {
      final now = DateTime(2026, 11, 24, 12);
      final currentWeek = HistoryPeriod.week(now);
      final harness = buildHarness(
        now: now,
        runs: [
          historyTestRun(
            id: 'first',
            date: DateTime(2026, 11, 1),
            distanceKm: 2,
          ),
          historyTestRun(
            id: 'last',
            date: DateTime(2026, 11, 29),
            distanceKm: 10,
          ),
        ],
        goals: {'weekly:${currentWeek.id}': 20, 'monthly:2026-11': 80},
      );
      await harness.viewModel.initialize();

      await harness.viewModel.selectMonth();

      expect(harness.viewModel.chartBars, hasLength(5));
      expect(harness.viewModel.chartMaxDistance, 10);
      expect(harness.viewModel.chartBars.first.distanceKm, 2);
      expect(
        harness.viewModel.chartBars.first.colorRatio,
        closeTo(0.2, 0.0001),
      );
      expect(harness.viewModel.chartBars.last.distanceKm, 10);
      expect(harness.viewModel.chartBars.last.colorRatio, 1);
    });

    test('consulta de pace zones mantém o fim do período exclusivo', () async {
      final now = DateTime(2026, 11, 24, 12);
      final current = HistoryPeriod.week(now);
      final harness = buildHarness(
        now: now,
        runs: [
          historyTestRun(
            id: 'before',
            date: DateTime(2026, 11, 21, 23, 59),
            distanceKm: 1,
          ),
          historyTestRun(
            id: 'start',
            date: DateTime(2026, 11, 22),
            distanceKm: 2,
          ),
          historyTestRun(
            id: 'inside',
            date: DateTime(2026, 11, 28, 23, 59),
            distanceKm: 3,
          ),
          historyTestRun(
            id: 'end',
            date: DateTime(2026, 11, 29),
            distanceKm: 4,
          ),
        ],
        goals: {'weekly:${current.id}': 20},
      );
      harness.runs.paceZonesLoader = (start, end) async {
        final includedKm = harness.runs.runs
            .where((run) => !run.date.isBefore(start) && !run.date.isAfter(end))
            .fold(0.0, (sum, run) => sum + run.distanceKm);
        return {'running': includedKm, 'unknown': 100, 'fast': 0, 'slow': -1};
      };

      await harness.viewModel.initialize();

      final range = harness.runs.paceZoneRanges.single;
      expect(range.$1, DateTime(2026, 11, 22));
      expect(
        range.$2,
        DateTime(2026, 11, 29).subtract(const Duration(microseconds: 1)),
      );
      expect(harness.viewModel.filteredRuns.map((run) => run.id), [
        'start',
        'inside',
      ]);
      expect(harness.viewModel.paceZoneTotals, {PaceZone.running: 5});
    });

    test('escopo irrelevante não recarrega o histórico', () async {
      final now = DateTime(2026, 11, 24, 12);
      final current = HistoryPeriod.week(now);
      final harness = buildHarness(
        now: now,
        goals: {'weekly:${current.id}': 20},
      );
      await harness.viewModel.initialize();
      expect(harness.runs.summariesCalls, 1);

      harness.hub.emit({DataScope.strength, DataScope.achievements});
      await flushHistoryEvents();
      expect(harness.runs.summariesCalls, 1);

      harness.hub.emit({DataScope.runs});
      await flushHistoryEvents();
      expect(harness.runs.summariesCalls, 2);
    });

    test('dispose invalida carga pendente sem notificar', () async {
      final now = DateTime(2026, 11, 24, 12);
      final current = HistoryPeriod.week(now);
      final harness = buildHarness(
        now: now,
        goals: {'weekly:${current.id}': 20},
      );
      await harness.viewModel.initialize();
      var notifications = 0;
      harness.viewModel.addListener(() => notifications++);
      final paceGate = Completer<Map<String, double>>();
      harness.runs.paceZonesLoader = (start, end) => paceGate.future;

      final refresh = harness.viewModel.refresh();
      await flushHistoryEvents();
      harness.viewModel.dispose();
      final notificationsAfterDispose = notifications;

      paceGate.complete({'running': 5});
      await refresh;
      await flushHistoryEvents();

      expect(notifications, notificationsAfterDispose);
    });

    test('parseGoalKm aceita vírgula e rejeita valores inválidos', () {
      expect(HistoryDashboardViewModel.parseGoalKm(' 25,5 '), 25.5);
      expect(HistoryDashboardViewModel.parseGoalKm('0'), isNull);
      expect(HistoryDashboardViewModel.parseGoalKm('-1'), isNull);
      expect(HistoryDashboardViewModel.parseGoalKm('abc'), isNull);
      expect(HistoryDashboardViewModel.parseGoalKm('Infinity'), isNull);
    });
  });
}
