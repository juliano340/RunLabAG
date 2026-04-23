import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/services/theme_service.dart';
import 'core/services/ad_service.dart';
import 'core/services/analytics_service.dart';
import 'features/onboarding/presentation/screens/welcome_screen.dart';
import 'features/dashboard/presentation/screens/main_screen.dart';
import 'features/profile/presentation/screens/onboarding_screen.dart';
import 'features/profile/presentation/screens/privacy_screen.dart';

import 'features/water/presentation/providers/water_provider.dart';
import 'features/strength_training/presentation/providers/strength_workout_provider.dart';
import 'features/strength_training/data/repositories/strength_workout_repository_impl.dart';
import 'core/services/database_service.dart';
import 'core/services/notification_service.dart';
import 'core/providers/runs_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloqueia a rotação da tela, permitindo apenas o modo vertical (portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Firebase (opcional — requer google-services.json em android/app/) ──────
  // Se o arquivo ainda não existir, o app continua funcionando sem analytics.
  await AnalyticsService().init();

  // ── Outros serviços ───────────────────────────────────────────────────────
  await AdService().init();
  await NotificationService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;

  // Registra ID anônimo para correlação de sessões no Analytics
  if (AnalyticsService().isInitialized) {
    final userId = prefs.getString('user_analytics_id') ?? _generateUserId(prefs);
    await AnalyticsService().setUserId(userId);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
        ChangeNotifierProvider(create: (_) => RunsProvider()),
        ChangeNotifierProvider(
          create: (_) => StrengthWorkoutProvider(
            StrengthWorkoutRepositoryImpl(DatabaseService()),
          )..loadWorkouts(),
        ),
      ],
      child: RunLabApp(
        hasCompletedOnboarding: hasCompletedOnboarding,
      ),
    ),
  );
}

String _generateUserId(SharedPreferences prefs) {
  final id = 'user_${DateTime.now().millisecondsSinceEpoch}';
  prefs.setString('user_analytics_id', id);
  return id;
}

class RunLabApp extends StatelessWidget {
  final bool hasCompletedOnboarding;

  const RunLabApp({
    super.key,
    required this.hasCompletedOnboarding,
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
        '/dashboard': (context) => const MainScreen(),
        '/privacy': (context) => const PrivacyScreen(),
      },
    );
  }
}
