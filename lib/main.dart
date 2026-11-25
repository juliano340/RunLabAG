import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/services/theme_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/backup_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/pace_zone_backfill_service.dart';
import 'features/onboarding/presentation/screens/welcome_screen.dart';
import 'features/dashboard/presentation/screens/main_screen.dart';
import 'features/profile/presentation/screens/onboarding_screen.dart';
import 'features/profile/presentation/screens/privacy_screen.dart';

import 'features/strength_training/presentation/providers/strength_workout_provider.dart';
import 'core/data/data_change_hub.dart';
import 'core/data/read_model_cache.dart';
import 'core/domain/repositories/run_repository.dart';
import 'core/domain/repositories/stats_repository.dart';
import 'core/domain/repositories/user_repository.dart';
import 'core/domain/repositories/active_run_repository.dart';
import 'core/domain/repositories/achievement_repository.dart';
import 'core/domain/repositories/user_data_reset_repository.dart';
import 'features/run/application/run_persistence_coordinator.dart';
import 'features/training/services/training_service.dart';
import 'features/run/domain/repositories/active_run_store.dart';
import 'features/run/domain/repositories/run_profile_source.dart';
import 'app/composition_root.dart';

/// Contador de inicializações que não chegaram ao primeiro frame.
/// Duas seguidas = o boot anterior morreu; o app abre em modo seguro.
const _bootAttemptsKey = 'boot_attempts';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Fontes bundladas no pubspec: nunca baixar em runtime (cold start
      // previsível e app funcionando offline desde o primeiro frame).
      GoogleFonts.config.allowRuntimeFetching = false;

      // Erros que escapam do framework nunca devem virar tela preta.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AnalyticsService().recordError(
          details.exception,
          details.stack,
          reason: 'flutter_error',
        );
      };
      ErrorWidget.builder = (details) => _BootErrorWidget(details: details);

      // Bloqueia a rotação da tela, permitindo apenas o modo vertical (portrait)
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // SharedPreferences é local e rápido — mas se falhar, o app ainda abre.
      bool hasCompletedOnboarding = false;
      bool safeMode = false;
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        hasCompletedOnboarding =
            prefs.getBool('hasCompletedOnboarding') ?? false;
        final attempts = prefs.getInt(_bootAttemptsKey) ?? 0;
        safeMode = attempts >= 2;
        await prefs.setInt(_bootAttemptsKey, attempts + 1);
      } catch (e) {
        debugPrint('[Boot] SharedPreferences indisponível: $e');
      }

      final dependencies = buildAppDependencies();

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeService()),
            Provider<DataChangeHub>.value(value: dependencies.changes),
            Provider<ReadModelCache>.value(value: dependencies.cache),
            Provider<RunRepository>.value(value: dependencies.runRepository),
            Provider<StatsRepository>.value(
              value: dependencies.statsRepository,
            ),
            Provider<UserRepository>.value(value: dependencies.userRepository),
            Provider<ActiveRunRepository>.value(
              value: dependencies.activeRunRepository,
            ),
            Provider<AchievementRepository>.value(
              value: dependencies.achievementRepository,
            ),
            Provider<UserDataResetRepository>.value(
              value: dependencies.userDataResetRepository,
            ),
            Provider<BackupService>.value(value: dependencies.backupService),
            Provider<RunPersistenceCoordinator>.value(
              value: dependencies.runPersistenceCoordinator,
            ),
            Provider<TrainingService>.value(
              value: dependencies.trainingService,
            ),
            Provider<ActiveRunStore>.value(value: dependencies.activeRunStore),
            Provider<RunProfileSource>.value(
              value: dependencies.runProfileSource,
            ),
            ChangeNotifierProvider(
              create: (_) => StrengthWorkoutProvider(
                dependencies.strengthWorkoutRepository,
              )..loadWorkouts(),
            ),
          ],
          child: RunLabApp(
            hasCompletedOnboarding: hasCompletedOnboarding,
            safeMode: safeMode,
          ),
        ),
      );

      // Só depois do primeiro frame: nada aqui pode atrasar a abertura.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          _afterFirstFrame(prefs, dependencies.paceZoneBackfillService),
        );
      });
    },
    (error, stack) {
      debugPrint('[Boot] Erro não tratado: $error\n$stack');
      AnalyticsService().recordError(error, stack, reason: 'zone_error');
    },
  );
}

/// Boot concluído: zera o contador e inicializa serviços pesados sem bloquear.
Future<void> _afterFirstFrame(
  SharedPreferences? prefs,
  PaceZoneBackfillService paceZoneBackfillService,
) async {
  try {
    await prefs?.setInt(_bootAttemptsKey, 0);
  } catch (_) {}

  await AnalyticsService().init();

  if (AnalyticsService().isInitialized) {
    final id =
        prefs?.getString('user_analytics_id') ??
        'user_${DateTime.now().millisecondsSinceEpoch}';
    if (prefs?.getString('user_analytics_id') == null) {
      unawaited(prefs?.setString('user_analytics_id', id));
    }
    unawaited(AnalyticsService().setUserId(id));
  }

  // SDKs de anúncio e notificação: timeouts curtos, falha silenciosa.
  try {
    await AdService().init().timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('[Boot] AdService indisponível: $e');
  }

  try {
    await NotificationService.initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('[Boot] Notificações indisponíveis: $e');
  }

  // Faixas de ritmo dos treinos antigos, em lotes e em segundo plano.
  unawaited(() async {
    try {
      // Limite de segurança: nunca fica em loop se uma gravação falhar.
      for (var round = 0; round < 50; round++) {
        final processed = await paceZoneBackfillService.runBatch();
        if (processed == 0) break;
      }
    } catch (e) {
      debugPrint('[Boot] Backfill de faixas de ritmo interrompido: $e');
    }
  }());
}

class RunLabApp extends StatelessWidget {
  final bool hasCompletedOnboarding;
  final bool safeMode;

  const RunLabApp({
    super.key,
    required this.hasCompletedOnboarding,
    this.safeMode = false,
  });

  @override
  Widget build(BuildContext context) {
    String initialRoute = hasCompletedOnboarding ? '/dashboard' : '/welcome';

    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      title: 'RunLab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeService.themeMode,
      initialRoute: initialRoute,
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/dashboard': (context) => MainScreen(safeMode: safeMode),
        '/privacy': (context) => const PrivacyScreen(),
      },
    );
  }
}

/// Mostrado no lugar de um widget que falhou ao construir — legível, com
/// botão de recuperação, em vez de tela preta/vermelha.
class _BootErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;

  const _BootErrorWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: AppColors.backgroundDarkGreen,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Algo deu errado ao desenhar esta tela.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              details.exceptionAsString(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
