import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../features/dashboard/presentation/screens/home_tab.dart';
import '../../../../features/history/presentation/screens/history_tab.dart';
import '../../../../features/profile/presentation/screens/records_tab.dart';
import '../../../../features/profile/presentation/screens/profile_tab.dart';
// import '../../../../features/training/presentation/screens/training_tab.dart';
// import '../../../../features/strength_training/presentation/screens/strength_history_screen.dart';
import '../../../../core/widgets/ad_banner_widget.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/services/analytics_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _tabSwitchCount = 0;
  DateTime? _lastBackPressTime;

  // Mostra intersticial no máximo 1x por dia, somente a cada 3 trocas de aba.
  // Nunca interrompe ação ativa — só em navegação passiva.
  Future<void> _onTabChanged(int newIndex) async {
    setState(() {
      _currentIndex = newIndex;
      _tabSwitchCount++;
    });

    if (_tabSwitchCount < 3) return;

    final prefs = await SharedPreferences.getInstance();
    final lastShownMs = prefs.getInt('last_interstitial_day') ?? 0;
    final today = DateTime.now();
    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMs);

    final isSameDay = lastShown.year == today.year &&
        lastShown.month == today.month &&
        lastShown.day == today.day;

    if (isSameDay) return;

    // Resetar contador e registrar o dia
    _tabSwitchCount = 0;
    await prefs.setInt('last_interstitial_day', today.millisecondsSinceEpoch);

    AnalyticsService().logInterstitialShown();
    AdService().showInterstitialAd(onAdDismissed: () {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPressTime == null || 
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          
          if (mounted) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.logOut, 
                      size: 18, 
                      color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Pressione novamente para sair',
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : AppColors.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                elevation: 4,
                width: 280,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: BorderSide(
                    color: isDark ? AppColors.cardBorder.withValues(alpha: 0.2) : AppColors.borderLight,
                    width: 0.5,
                  ),
                ),
              ),
            );
          }
        } else {
          // Se pressionou novamente dentro de 2 segundos, sai do app
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: ValueKey(Theme.of(context).brightness),
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  HomeTab(
                    key: PageStorageKey('tab_home'),
                    onNavigateToProfile: () => _onTabChanged(3),
                  ),
                  HistoryTab(key: PageStorageKey('tab_history')),
                  RecordsTab(key: PageStorageKey('tab_records')),
                  ProfileTab(key: PageStorageKey('tab_profile')),
                ],
              ),
            ),
            AdBannerWidget(key: ValueKey('ad_banner_${Theme.of(context).brightness}')),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
            color: Theme.of(context).brightness == Brightness.dark 
                ? AppColors.backgroundDarkGreen 
                : AppColors.cardLight,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabChanged,
              backgroundColor: Colors.transparent, // Uses container background
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.textMuted 
                  : AppColors.textMutedDark,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: const [
                BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Início'),
                BottomNavigationBarItem(icon: Icon(LucideIcons.history), label: 'Histórico'),
                // BottomNavigationBarItem(icon: Icon(LucideIcons.award), label: 'Planos'),
                // BottomNavigationBarItem(icon: Icon(LucideIcons.dumbbell), label: 'Força'),
                BottomNavigationBarItem(icon: Icon(LucideIcons.trophy), label: 'Recordes'),
                BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Perfil'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
