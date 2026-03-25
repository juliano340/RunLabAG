import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../features/dashboard/presentation/screens/home_tab.dart';
import '../../../../features/history/presentation/screens/history_tab.dart';
import '../../../../features/profile/presentation/screens/records_tab.dart';
import '../../../../features/profile/presentation/screens/profile_tab.dart';
import '../../../../features/training/presentation/screens/training_tab.dart';
import '../../../../features/strength_training/presentation/screens/strength_history_screen.dart';
import '../../../../core/widgets/ad_banner_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeTab(),
    const HistoryTab(),
    const TrainingTab(),
    const StrengthHistoryScreen(),
    const RecordsTab(),
    const ProfileTab(),
  ];

  DateTime? _lastBackPressTime;

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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Pressione novamente para sair', 
                  style: TextStyle(color: Colors.red),
                ),
                backgroundColor: AppColors.backgroundDarkGreen,                
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  side: BorderSide(color: Colors.white, width: 2),
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
        body: Column(
          children: [
            Expanded(child: _tabs[_currentIndex]),
            const AdBannerWidget(),
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
              onTap: (index) => setState(() => _currentIndex = index),
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
                BottomNavigationBarItem(icon: Icon(LucideIcons.award), label: 'Planos'),
                BottomNavigationBarItem(icon: Icon(LucideIcons.dumbbell), label: 'Força'),
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
