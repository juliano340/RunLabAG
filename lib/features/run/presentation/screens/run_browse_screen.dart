import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/presentation/screens/home_tab.dart';
import '../../../history/presentation/screens/history_tab.dart';
import '../../../analytics/presentation/screens/analytics_tab.dart';
import '../../../profile/presentation/screens/records_tab.dart';
import '../../../profile/presentation/screens/profile_tab.dart';

/// Modo "navegar durante o treino": um clone leve das abas SEM anúncios,
/// SEM intersticiais e SEM lógica de corrida (o GO vira "Voltar ao treino"
/// e o check de recuperação fica suprimido).
///
/// É empurrado POR CIMA do [ActiveRunScreen], que permanece vivo na pilha:
/// GPS, timers e persistência continuam rodando de verdade enquanto o
/// usuário navega. A pill fixa devolve ao treino com um toque (pop).
class RunBrowseScreen extends StatefulWidget {
  const RunBrowseScreen({super.key});

  @override
  State<RunBrowseScreen> createState() => _RunBrowseScreenState();
}

class _RunBrowseScreenState extends State<RunBrowseScreen> {
  int _currentIndex = 0;
  late final List<bool> _built = [true, false, false, false, false];

  void _onTabChanged(int newIndex) {
    setState(() {
      _currentIndex = newIndex;
      _built[newIndex] = true;
    });
  }

  /// Monta a aba só na primeira visita e silencia os tickers das invisíveis.
  Widget _buildTab(int index, Widget child) {
    return TickerMode(
      enabled: index == _currentIndex,
      child: _built[index] ? child : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildTab(
                  0,
                  HomeTab(
                    key: const PageStorageKey('browse_home'),
                    embedded: true,
                    onReturnToRun: () => Navigator.pop(context),
                    onNavigateToProfile: () => _onTabChanged(4),
                  ),
                ),
                _buildTab(
                  1,
                  const HistoryTab(key: PageStorageKey('browse_history')),
                ),
                _buildTab(
                  2,
                  const AnalyticsTab(key: PageStorageKey('browse_analytics')),
                ),
                _buildTab(
                  3,
                  const RecordsTab(key: PageStorageKey('browse_records')),
                ),
                _buildTab(
                  4,
                  const ProfileTab(key: PageStorageKey('browse_profile')),
                ),
              ],
            ),
          ),
          _buildReturnPill(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
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
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor:
                Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textMuted
                    : AppColors.textMutedDark,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            items: const [
              BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Início'),
              BottomNavigationBarItem(icon: Icon(LucideIcons.history), label: 'Histórico'),
              BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: 'Análises'),
              BottomNavigationBarItem(icon: Icon(LucideIcons.trophy), label: 'Recordes'),
              BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  /// Pill fixa acima da barra: o treino tá vivo embaixo — toque volta.
  Widget _buildReturnPill() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.activity, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Treino em andamento — toque para voltar',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
