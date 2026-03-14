import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/services/theme_service.dart';
import 'features/onboarding/presentation/screens/welcome_screen.dart';
import 'features/dashboard/presentation/screens/main_screen.dart';
import 'features/profile/presentation/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: RunLabApp(
        hasCompletedOnboarding: hasCompletedOnboarding,
      ),
    ),
  );
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
      },
    );
  }
}
