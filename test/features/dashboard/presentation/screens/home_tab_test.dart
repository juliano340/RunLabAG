import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runlabag/core/data/data_change_hub.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';
import 'package:runlabag/core/domain/models/user_stats.dart';
import 'package:runlabag/core/domain/repositories/active_run_repository.dart';
import 'package:runlabag/core/domain/repositories/run_repository.dart';
import 'package:runlabag/core/domain/repositories/stats_repository.dart';
import 'package:runlabag/core/domain/repositories/user_repository.dart';
import 'package:runlabag/features/dashboard/presentation/screens/home_tab.dart';

class _Stats implements StatsRepository {
  bool fail = false;

  @override
  Future<UserStats> getUserStats({DateTime? since}) async {
    if (fail) throw StateError('falha');
    return UserStats.empty;
  }

  @override
  Future<List<double>> getWeeklyProgress() async => List<double>.filled(7, 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Users implements UserRepository {
  @override
  Future<UserProfile?> getUserProfile() async =>
      UserProfile(name: 'Atleta', age: 30, weight: 70, height: 170);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runs implements RunRepository {
  @override
  Future<RunModel?> getLastRunSummary() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ActiveRuns implements ActiveRunRepository {
  @override
  Future<Map<String, dynamic>?> getActiveRunMeta() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildHome(_Stats stats) {
  final hub = DataChangeHub();
  return MultiProvider(
    providers: [
      Provider<DataChangeHub>.value(value: hub),
      Provider<StatsRepository>.value(value: stats),
      Provider<UserRepository>.value(value: _Users()),
      Provider<RunRepository>.value(value: _Runs()),
      Provider<ActiveRunRepository>.value(value: _ActiveRuns()),
    ],
    child: const MaterialApp(home: Scaffold(body: HomeTab())),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Home renderiza o dashboard após a carga', (tester) async {
    await tester.pumpWidget(_buildHome(_Stats()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Visão Geral'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Home mostra erro inicial e permite retentar', (tester) async {
    final stats = _Stats()..fail = true;
    await tester.pumpWidget(_buildHome(stats));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Não foi possível carregar o dashboard.'), findsOneWidget);
    stats.fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Visão Geral'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
