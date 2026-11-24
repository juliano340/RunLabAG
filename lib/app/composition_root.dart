import '../core/data/repositories/active_run_repository.dart';
import '../core/data/repositories/run_repository.dart';
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
  final DatabaseService databaseService;
  final RunRepository runRepository;
  final StatsRepository statsRepository;
  final UserRepository userRepository;
  final ActiveRunRepository activeRunRepository;
  final BackupService backupService;
  final RunPersistenceCoordinator runPersistenceCoordinator;
  final StrengthWorkoutRepository strengthWorkoutRepository;

  const AppDependencies({
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
  final runRepository = SqfliteRunRepository();
  final userRepository = SqfliteUserRepository();
  final statsRepository = SqfliteStatsRepository(
    runRepository: runRepository,
    userRepository: userRepository,
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
  );

  return AppDependencies(
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
