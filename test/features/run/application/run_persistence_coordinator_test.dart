import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/repositories/run_completion_store.dart';
import 'package:runlabag/core/services/achievement_service.dart';
import 'package:runlabag/core/services/backup_service.dart';
import 'package:runlabag/core/services/database_service.dart';
import 'package:runlabag/features/run/application/run_persistence_coordinator.dart';
import 'package:runlabag/features/training/services/training_service.dart';

class _FakeCompletionStore implements RunCompletionStore {
  int calls = 0;
  bool shouldFail = false;

  @override
  Future<void> saveCompletedRun({
    required RunModel run,
    required Map<String, double> distanceByZone,
  }) async {
    calls++;
    if (shouldFail) throw StateError('commit failed');
  }
}

class _FailingBackupService extends BackupService {
  @override
  Future<bool> runAutoBackupIfEnabled() async {
    throw StateError('backup failed');
  }
}

class _FailingTrainingService extends TrainingService {
  _FailingTrainingService() : super(DatabaseService());

  @override
  Future<bool> matchRunToPlan(RunModel run) async {
    throw StateError('training failed');
  }
}

class _FailingAchievementService extends AchievementService {
  @override
  Future<List<Map<String, dynamic>>> checkAwards(RunModel latestRun) async {
    throw StateError('achievements failed');
  }
}

class _OrderCheckingAchievementService extends AchievementService {
  final bool Function() wasCommitted;

  _OrderCheckingAchievementService(this.wasCommitted);

  @override
  Future<List<Map<String, dynamic>>> checkAwards(RunModel latestRun) async {
    expect(wasCommitted(), isTrue);
    return [];
  }
}

void main() {
  Future<RunPersistenceResult> saveWith({
    required _FakeCompletionStore store,
    BackupService? backupService,
    TrainingService? trainingService,
    AchievementService? achievementService,
    void Function()? onRunCommitted,
  }) {
    final coordinator = RunPersistenceCoordinator(
      completionStore: store,
      backupService: backupService ?? _FailingBackupService(),
      trainingService: trainingService ?? _FailingTrainingService(),
      achievementService: achievementService ?? _FailingAchievementService(),
      onRunCommitted: onRunCommitted,
    );
    return coordinator.saveCompletedRun(
      startTime: DateTime(2026, 11, 24, 10),
      distanceKm: 5,
      durationSeconds: 1800,
      pausedDurationSeconds: 0,
      pace: '6:00',
      calories: 300,
      route: const [],
      type: 'Corrida',
      mood: '',
      splits: const [],
    );
  }

  test('falhas pós-commit não desfazem o sucesso do treino', () async {
    final store = _FakeCompletionStore();

    final result = await saveWith(store: store);
    await Future<void>.delayed(Duration.zero);

    expect(store.calls, 1);
    expect(result.run.id, isNotEmpty);
    expect(result.isPlanSuccessful, isFalse);
    expect(result.newAwards, isEmpty);
  });

  test('cache é invalidado antes dos efeitos pós-commit', () async {
    final store = _FakeCompletionStore();
    var committed = false;

    await saveWith(
      store: store,
      onRunCommitted: () => committed = true,
      achievementService: _OrderCheckingAchievementService(() => committed),
    );

    expect(committed, isTrue);
  });

  test('falha no commit atômico é propagada', () async {
    final store = _FakeCompletionStore()..shouldFail = true;

    await expectLater(saveWith(store: store), throwsStateError);
    expect(store.calls, 1);
  });
}
