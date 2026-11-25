import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:runlabag/core/data/data_change_hub.dart';
import 'package:runlabag/core/domain/repositories/run_repository.dart';
import 'package:runlabag/core/domain/repositories/stats_repository.dart';
import 'package:runlabag/core/domain/repositories/user_repository.dart';
import 'package:runlabag/features/history/presentation/screens/history_tab.dart';

import '../../history_dashboard_test_support.dart';

Widget buildHistoryTab({
  required FakeRunRepository runs,
  required FakeStatsRepository stats,
  required FakeUserRepository users,
  required FakeDataChangeHub hub,
}) {
  return MultiProvider(
    providers: [
      Provider<DataChangeHub>.value(value: hub),
      Provider<RunRepository>.value(value: runs),
      Provider<StatsRepository>.value(value: stats),
      Provider<UserRepository>.value(value: users),
    ],
    child: const MaterialApp(home: Scaffold(body: HistoryTab())),
  );
}

void main() {
  testWidgets('mostra erro com retry e recupera o dashboard', (tester) async {
    final runs = FakeRunRepository();
    final stats = FakeStatsRepository();
    final users = FakeUserRepository(profile: historyTestProfile());
    final hub = FakeDataChangeHub();
    addTearDown(hub.dispose);
    runs.summariesLoader = () async => throw StateError('falha ao carregar');

    await tester.pumpWidget(
      buildHistoryTab(runs: runs, stats: stats, users: users, hub: hub),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Não foi possível carregar o histórico.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    runs.summariesLoader = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Nenhuma atividade neste período.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('diálogo de metas salva vírgula através da VM', (tester) async {
    final runs = FakeRunRepository();
    final stats = FakeStatsRepository();
    final users = FakeUserRepository(
      profile: historyTestProfile(kmNotificationsEnabled: false),
    );
    final hub = FakeDataChangeHub();
    addTearDown(hub.dispose);

    await tester.pumpWidget(
      buildHistoryTab(runs: runs, stats: stats, users: users, hub: hub),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.settings));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '25,5');
    await tester.enterText(find.byType(TextField).at(1), '30,5');
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Configurar Meta'), findsNothing);
    expect(stats.writes.last.value, 25.5);
    expect(users.savedProfiles.single.weeklyGoal, 30.5);
    expect(users.savedProfiles.single.kmNotificationsEnabled, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
