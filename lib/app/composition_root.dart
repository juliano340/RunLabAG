import '../core/data/repositories/active_run_repository.dart';
import '../core/data/repositories/achievement_repository.dart';
import '../core/data/repositories/caching_run_repository.dart';
import '../core/data/repositories/caching_stats_repository.dart';
import '../core/data/repositories/caching_user_repository.dart';
import '../core/data/data_change_hub.dart';
import '../core/data/read_model_cache.dart';
import '../core/data/repositories/run_repository.dart';
import '../core/data/repositories/sqflite_backup_store.dart';
import '../core/data/repositories/sqflite_run_completion_store.dart';
import '../core/data/repositories/stats_repository.dart';
import '../core/data/repositories/user_repository.dart';
import '../core/data/repositories/user_data_reset_repository.dart';
import '../core/domain/repositories/active_run_repository.dart';
import '../core/domain/repositories/achievement_repository.dart';
import '../core/domain/repositories/run_repository.dart';
import '../core/domain/repositories/stats_repository.dart';
import '../core/domain/repositories/user_repository.dart';
import '../core/domain/repositories/user_data_reset_repository.dart';
import '../core/services/achievement_service.dart';
import '../core/services/analytics_service.dart';
import '../core/services/backup_service.dart';
import '../core/services/database_service.dart';
import '../core/services/pace_zone_backfill_service.dart';
import '../features/run/application/run_persistence_coordinator.dart';
import '../features/run/data/repositories/database_active_run_store.dart';
import '../features/run/data/repositories/database_run_profile_source.dart';
import '../features/run/domain/repositories/active_run_store.dart';
import '../features/run/domain/repositories/run_profile_source.dart';
import '../features/training/services/training_service.dart';
import '../features/strength_training/data/repositories/strength_workout_repository_impl.dart';
import '../features/strength_training/domain/repositories/strength_workout_repository.dart';

/// Grafo de dependências criado uma única vez no boot.
///
/// Nenhuma tela precisa saber construir SQLite, serviços ou efeitos colaterais.
class AppDependencies {
  final DataChangeHub changes;
  final ReadModelCache cache;
  final PaceZoneBackfillService paceZoneBackfillService;
  final RunRepository runRepository;
  final StatsRepository statsRepository;
  final UserRepository userRepository;
  final ActiveRunRepository activeRunRepository;
  final AchievementRepository achievementRepository;
  final UserDataResetRepository userDataResetRepository;
  final BackupService backupService;
  final RunPersistenceCoordinator runPersistenceCoordinator;
  final TrainingService trainingService;
  final ActiveRunStore activeRunStore;
  final RunProfileSource runProfileSource;
  final StrengthWorkoutRepository strengthWorkoutRepository;

  const AppDependencies({
    required this.changes,
    required this.cache,
    required this.paceZoneBackfillService,
    required this.runRepository,
    required this.statsRepository,
    required this.userRepository,
    required this.activeRunRepository,
    required this.achievementRepository,
    required this.userDataResetRepository,
    required this.backupService,
    required this.runPersistenceCoordinator,
    required this.trainingService,
    required this.activeRunStore,
    required this.runProfileSource,
    required this.strengthWorkoutRepository,
  });
}

AppDependencies buildAppDependencies() {
  final changes = DataChangeHub();
  final cache = ReadModelCache(hub: changes);
  final runRepository = CachingRunRepository(SqfliteRunRepository(), cache);
  final userRepository = CachingUserRepository(SqfliteUserRepository(), cache);
  final statsRepository = CachingStatsRepository(
    SqfliteStatsRepository(
      runRepository: runRepository,
      userRepository: userRepository,
    ),
    cache,
  );
  final activeRunRepository = SqfliteActiveRunRepository();
  final achievementRepository = SqfliteAchievementRepository();
  final resetRepository = SqfliteUserDataResetRepository();
  final databaseService = DatabaseService(
    runRepository: runRepository,
    userRepository: userRepository,
    statsRepository: statsRepository,
    activeRunRepository: activeRunRepository,
    achievementRepository: achievementRepository,
    resetRepository: resetRepository,
  );
  final backupService = BackupService(store: SqfliteBackupStore());
  final trainingService = TrainingService(databaseService);
  final activeRunStore = DatabaseActiveRunStore(activeRunRepository);
  final runProfileSource = DatabaseRunProfileSource(userRepository);
  final runPersistenceCoordinator = RunPersistenceCoordinator(
    achievementService: AchievementService(
      statsRepository: statsRepository,
      achievementRepository: achievementRepository,
    ),
    backupService: backupService,
    analyticsService: AnalyticsService(),
    completionStore: SqfliteRunCompletionStore(),
    trainingService: trainingService,
    onRunCommitted: () => changes.emit({DataScope.runs, DataScope.paceZones}),
  );

  return AppDependencies(
    changes: changes,
    cache: cache,
    paceZoneBackfillService: PaceZoneBackfillService(runRepository),
    runRepository: runRepository,
    statsRepository: statsRepository,
    userRepository: userRepository,
    activeRunRepository: activeRunRepository,
    achievementRepository: achievementRepository,
    userDataResetRepository: resetRepository,
    backupService: backupService,
    runPersistenceCoordinator: runPersistenceCoordinator,
    trainingService: trainingService,
    activeRunStore: activeRunStore,
    runProfileSource: runProfileSource,
    strengthWorkoutRepository: StrengthWorkoutRepositoryImpl(databaseService),
  );
}
