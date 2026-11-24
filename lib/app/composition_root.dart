import '../core/data/repositories/active_run_repository.dart';
import '../core/data/repositories/caching_run_repository.dart';
import '../core/data/repositories/caching_stats_repository.dart';
import '../core/data/repositories/caching_user_repository.dart';
import '../core/data/read_model_cache.dart';
import '../core/data/repositories/run_repository.dart';
import '../core/data/repositories/sqflite_run_completion_store.dart';
import '../core/data/repositories/stats_repository.dart';
import '../core/data/repositories/user_repository.dart';
import '../core/domain/repositories/active_run_repository.dart';
import '../core/domain/repositories/run_repository.dart';
import '../core/domain/repositories/stats_repository.dart';
import '../core/domain/repositories/user_repository.dart';
import '../core/services/achievement_service.dart';
import '../core/services/analytics_service.dart';
import '../core/services/backup_service.dart';
import '../core/services/database_service.dart';
import '../features/run/application/run_persistence_coordinator.dart';
import '../features/strength_training/data/repositories/strength_workout_repository_impl.dart';
import '../features/strength_training/domain/repositories/strength_workout_repository.dart';

/// Grafo de dependências criado uma única vez no boot.
///
/// Nenhuma tela precisa saber construir SQLite, serviços ou efeitos colaterais.
class AppDependencies {
  final ReadModelCache cache;
  final DatabaseService databaseService;
  final RunRepository runRepository;
  final StatsRepository statsRepository;
  final UserRepository userRepository;
  final ActiveRunRepository activeRunRepository;
  final BackupService backupService;
  final RunPersistenceCoordinator runPersistenceCoordinator;
  final StrengthWorkoutRepository strengthWorkoutRepository;

  const AppDependencies({
    required this.cache,
    required this.databaseService,
    required this.runRepository,
    required this.statsRepository,
    required this.userRepository,
    required this.activeRunRepository,
    required this.backupService,
    required this.runPersistenceCoordinator,
    required this.strengthWorkoutRepository,
  });
}

AppDependencies buildAppDependencies() {
  final cache = ReadModelCache();
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
  final databaseService = DatabaseService(
    runRepository: runRepository,
    userRepository: userRepository,
    statsRepository: statsRepository,
    activeRunRepository: activeRunRepository,
  );
  final backupService = BackupService(databaseService: databaseService);
  final runPersistenceCoordinator = RunPersistenceCoordinator(
    dbService: databaseService,
    achievementService: AchievementService(dbService: databaseService),
    backupService: backupService,
    analyticsService: AnalyticsService(),
    completionStore: SqfliteRunCompletionStore(),
    onRunCommitted: cache.invalidate,
  );

  return AppDependencies(
    cache: cache,
    databaseService: databaseService,
    runRepository: runRepository,
    statsRepository: statsRepository,
    userRepository: userRepository,
    activeRunRepository: activeRunRepository,
    backupService: backupService,
    runPersistenceCoordinator: runPersistenceCoordinator,
    strengthWorkoutRepository: StrengthWorkoutRepositoryImpl(databaseService),
  );
}
