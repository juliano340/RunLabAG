import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../features/dashboard/presentation/screens/home_tab.dart';
import '../../../../features/history/presentation/screens/history_tab.dart';
import '../../../../features/profile/presentation/screens/achievements_tab.dart';
import '../../../../features/profile/presentation/screens/profile_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeTab(),
    const Center(child: Text('Por favor, use o botão INICIAR CORRIDA no Início', style: TextStyle(color: Colors.white))),
    const HistoryTab(),
    const AchievementsTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: const Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
          color: AppColors.backgroundDarkGreen,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: AppColors.backgroundDarkGreen,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primaryNeon,
            unselectedItemColor: AppColors.textMuted,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            items: const [
              BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Início'),
              BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: 'Corrida'),
              BottomNavigationBarItem(icon: Icon(LucideIcons.history), label: 'Histórico'),
              BottomNavigationBarItem(icon: Icon(LucideIcons.award), label: 'Conquistas'),
              BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }
}
