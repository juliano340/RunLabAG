import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../application/home_dashboard_view_model.dart';
import '../../application/home_stats_window_store.dart';
import '../widgets/start_run_button.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../../features/run/presentation/screens/active_run_screen.dart';

import 'package:runlabag/core/domain/repositories/run_repository.dart';
import 'package:runlabag/core/domain/repositories/stats_repository.dart';
import 'package:runlabag/core/domain/repositories/user_repository.dart';
import 'package:runlabag/core/domain/repositories/active_run_repository.dart';
import 'package:runlabag/core/data/data_change_hub.dart';
import '../../../history/presentation/screens/run_detail_screen.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;

  /// Modo embutido (navegar durante o treino): sem check de recuperação
  /// e o GO vira "Voltar ao treino" — uma corrida já está em andamento.
  final bool embedded;
  final VoidCallback? onReturnToRun;

  const HomeTab({
    super.key,
    this.onNavigateToProfile,
    this.embedded = false,
    this.onReturnToRun,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final HomeDashboardViewModel _viewModel;
  bool _isShowingRecoverySheet = false;

  @override
  void initState() {
    super.initState();
    _viewModel = HomeDashboardViewModel(
      statsRepository: context.read<StatsRepository>(),
      userRepository: context.read<UserRepository>(),
      runRepository: context.read<RunRepository>(),
      activeRunRepository: context.read<ActiveRunRepository>(),
      statsWindowStore: const SharedPreferencesHomeStatsWindowStore(),
      clock: const SystemClock(),
      embedded: widget.embedded,
    )..addListener(_onDashboardChanged);
    unawaited(_viewModel.initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final changes = context.read<DataChangeHub>();
    _viewModel.updateDataChanges(
      changes.listenableFor({
        DataScope.runs,
        DataScope.profile,
        DataScope.goals,
      }),
    );
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onDashboardChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onDashboardChanged() {
    if (!mounted || _isShowingRecoverySheet) return;
    final activeRun = _viewModel.takePendingRecovery();
    if (activeRun != null) _showRecoveryBottomSheet(activeRun);
  }

  void _showRecoveryBottomSheet(Map<String, dynamic> activeRun) {
    final bool isFinished = (activeRun['finished'] ?? 0) == 1;

    _isShowingRecoverySheet = true;
    unawaited(
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Icon(LucideIcons.undo2, color: cs.primary, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    isFinished ? 'Treino não salvo' : 'Treino não Finalizado!',
                    style: GoogleFonts.outfit(
                      color: cs.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFinished
                        ? 'Encontramos um treino finalizado que ainda não foi salvo. '
                              'Deseja salvá-lo agora?'
                        : 'Encontramos um treino que foi interrompido. Deseja retomar de onde parou?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: cs.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              await _viewModel.discardActiveRun();
                              if (context.mounted) Navigator.pop(context);
                            } catch (_) {
                              // A ViewModel registra o erro; mantém o sheet aberto.
                            }
                          },
                          child: Text(
                            'DESCARTAR',
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: cs.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () async {
                            // Agora sim: carrega metadados + rota.
                            final navigator = Navigator.of(context);
                            try {
                              final full = await _viewModel
                                  .loadActiveRunForResume();
                              if (!mounted) return;
                              navigator.pop();
                              if (full == null) return;
                              Navigator.of(this.context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ActiveRunScreen(restoredState: full),
                                    ),
                                  )
                                  .then((_) => _viewModel.load());
                            } catch (_) {
                              // A ViewModel registra o erro; mantém o sheet aberto.
                            }
                          },
                          child: Text(
                            isFinished ? 'SALVAR' : 'RETOMAR',
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ).whenComplete(() {
        _isShowingRecoverySheet = false;
        if (mounted) _onDashboardChanged();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryNeon),
          );
        }
        if (!_viewModel.hasLoaded && _viewModel.hasError) {
          return _buildDashboardError();
        }
        return _buildDashboard(context);
      },
    );
  }

  Widget _buildDashboardError() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cloudOff, size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar o dashboard.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _viewModel.load,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final weeklyTotal = _viewModel.weeklyTotal;
    final weeklyGoal = _viewModel.weeklyGoal;
    final rawProgress = _viewModel.rawGoalProgress;
    final goalProgress = _viewModel.goalProgress;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _viewModel.load,
        color: AppColors.primaryNeon,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          key: const PageStorageKey('home_scroll'),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Profile with Goal Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: goalProgress,
                              strokeWidth: 4,
                              backgroundColor: _getGoalColor(
                                rawProgress,
                                isDark,
                              ).withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getGoalColor(rawProgress, isDark),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onNavigateToProfile,
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.cardBackground,
                              backgroundImage:
                                  _viewModel.profile?.profilePicturePath != null
                                  ? FileImage(
                                      File(
                                        _viewModel.profile!.profilePicturePath!,
                                      ),
                                    )
                                  : null,
                              child:
                                  _viewModel.profile?.profilePicturePath == null
                                  ? const Icon(
                                      LucideIcons.user,
                                      color: AppColors.primaryNeon,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _viewModel.greeting,
                            style: GoogleFonts.outfit(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.textMuted
                                  : AppColors.textMutedDark,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _viewModel.profile?.name ?? 'Atleta',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Meta Semanal',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textMuted
                              : AppColors.textMutedDark,
                        ),
                      ),
                      Text(
                        '${weeklyTotal.toStringAsFixed(1)} / ${weeklyGoal.toInt()} km',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getGoalColor(rawProgress, isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              if (widget.embedded && widget.onReturnToRun != null) ...[
                // Modo embutido: o GO vira retorno ao treino vivo — nunca
                // uma segunda corrida sobre a primeira.
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: widget.onReturnToRun,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primaryNeon
                              : AppColors.lightPrimary,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.zap,
                              size: 16,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Voltar ao treino',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Start Run Button (Center)
                Center(
                  child: StartRunButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ActiveRunScreen(),
                        ),
                      ).then((_) => _viewModel.load());
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Início expresso: GO de um toque só, sem tela pré-início
                Center(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ActiveRunScreen(autoStart: true),
                        ),
                      ).then((_) => _viewModel.load());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.zap,
                            size: 14,
                            color: isDark
                                ? AppColors.primaryNeon
                                : AppColors.lightPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Início expresso',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Last Training Summary
              if (_viewModel.lastRun != null) ...[
                Text(
                  'Último Treino',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RunDetailScreen(run: _viewModel.lastRun!),
                    ),
                  ),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? AppColors.primaryNeon
                                        : AppColors.lightPrimary)
                                    .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.navigation,
                            color: isDark
                                ? AppColors.primaryNeon
                                : AppColors.lightPrimary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_viewModel.lastRun!.distanceKm.toStringAsFixed(2)} km em ${_viewModel.lastRunDurationLabel}',
                                style: GoogleFonts.outfit(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Ritmo: ${_viewModel.lastRun!.pace}/km | Calorias: ${_viewModel.lastRun!.calories} kcal',
                                style: GoogleFonts.outfit(
                                  color: isDark
                                      ? AppColors.textMuted
                                      : AppColors.textMutedDark,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          color: isDark
                              ? AppColors.primaryNeon
                              : AppColors.lightPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Stats Compact Row
              Text(
                'Visão Geral',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final entry
                      in HomeDashboardViewModel.statsPeriodLabels
                          .asMap()
                          .entries)
                    _buildStatsPeriodChip(entry.value, entry.key, isDark),
                ],
              ),
              const SizedBox(height: 12),
              if (_viewModel.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.cloudOff,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Não foi possível atualizar os dados.',
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _viewModel.load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    _buildCompactStat(
                      icon: LucideIcons.map,
                      value: _viewModel.stats.formattedTotalDistance,
                      unit: 'km',
                    ),
                    _buildStatDivider(isDark),
                    _buildCompactStat(
                      icon: LucideIcons.activity,
                      value: _viewModel.stats.formattedTotalRuns,
                      unit: 'treinos',
                    ),
                    _buildStatDivider(isDark),
                    _buildCompactStat(
                      icon: LucideIcons.timer,
                      value: _viewModel.stats.formattedAveragePace,
                      unit: '/km',
                    ),
                    _buildStatDivider(isDark),
                    _buildCompactStat(
                      icon: LucideIcons.flame,
                      value: _viewModel.stats.formattedTotalCalories,
                      unit: 'kcal',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Progress Chart
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Desempenho Semanal',
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Hoje: ${_viewModel.weeklyProgress[_viewModel.todayIndex].toStringAsFixed(1)} km',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.primaryNeon
                          : AppColors.lightPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassContainer(
                height: 220,
                padding: const EdgeInsets.only(
                  top: 24,
                  bottom: 8,
                  left: 16,
                  right: 24,
                ),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _viewModel.chartMaxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            Theme.of(context).colorScheme.surface,
                        tooltipBorder: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toStringAsFixed(1)} km',
                            GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: isDark ? Colors.white10 : AppColors.borderLight,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            const labels = [
                              'Dom',
                              'Seg',
                              'Ter',
                              'Qua',
                              'Qui',
                              'Sex',
                              'Sáb',
                            ];
                            final index = value.toInt();
                            if (index < 0 || index > 6) {
                              return const Text('');
                            }
                            final isToday = index == _viewModel.todayIndex;
                            return Text(
                              labels[index],
                              style: TextStyle(
                                color: isToday
                                    ? (isDark
                                          ? AppColors.primaryNeon
                                          : AppColors.lightPrimary)
                                    : (isDark
                                          ? Colors.white54
                                          : AppColors.textMutedDark),
                                fontSize: 10,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (int i = 0; i < 7; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: _viewModel.weeklyProgress[i],
                              color: i == _viewModel.todayIndex
                                  ? (isDark
                                        ? AppColors.primaryNeon
                                        : AppColors.lightPrimary)
                                  : (isDark
                                            ? AppColors.primaryNeon
                                            : AppColors.lightPrimary)
                                        .withValues(alpha: 0.35),
                              width: 14,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGoalColor(double progress, bool isDark) {
    if (progress >= 1.5) {
      return isDark ? Colors.purpleAccent : Colors.purple.shade700;
    }
    if (progress >= 1.25) {
      return isDark ? Colors.amberAccent : Colors.amber.shade700;
    }
    if (progress >= 1.0) {
      return isDark ? Colors.orangeAccent : Colors.orange.shade700;
    }
    return isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
  }

  Widget _buildStatsPeriodChip(String label, int index, bool isDark) {
    final selected = _viewModel.selectedStatsPeriod == index;
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: () => _viewModel.changeStatsPeriod(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.only(right: index < 5 ? 8 : 0),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? accent
                  : (isDark ? Colors.white24 : AppColors.borderLight),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? AppColors.textMuted : AppColors.textMutedDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStat({
    required IconData icon,
    required String value,
    required String unit,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    final valueColor = isDark ? Colors.white : AppColors.textDark;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                text: value,
                style: GoogleFonts.outfit(
                  color: valueColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.outfit(
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.textMutedDark,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : AppColors.borderLight,
    );
  }
}
