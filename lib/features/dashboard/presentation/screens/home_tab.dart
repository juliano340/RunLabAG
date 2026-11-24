import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../widgets/start_run_button.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:runlabag/core/providers/runs_provider.dart';
import '../../../../features/run/presentation/screens/active_run_screen.dart';

import 'package:runlabag/core/services/database_service.dart';
import '../../../history/presentation/screens/run_detail_screen.dart';
import 'package:runlabag/core/domain/models/run_model.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';

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
  DatabaseService get _dbService => context.read<DatabaseService>();
  Map<String, dynamic> _stats = {
    'totalDistance': '0.0',
    'totalRuns': '0',
    'avgPace': '0:00',
    'totalCalories': '0',
  };
  // Janela da Visão Geral: 0 = tudo, 1 = 30d, 2 = 60d, 3 = 90d.
  int _statsPeriod = 0;
  List<double> _weeklyProgress = List.filled(7, 0.0);
  UserProfile? _profile;
  RunModel? _lastRun;
  bool _isLoading = true;

  // Última janela selecionada na Visão Geral (persiste entre sessões).
  static const _statsPeriodKey = 'home_stats_period';

  @override
  void initState() {
    super.initState();
    _restoreStatsPeriod();
  }

  // Recarrega quando o banco muda por fora: treino salvo, reset de dados
  // ou restauração de backup. Sem isso a aba ficava com os dados do
  // usuário anterior até um refresh manual.
  RunsProvider? _runsProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runsProvider = Provider.of<RunsProvider>(context, listen: false);
    if (_runsProvider != runsProvider) {
      _runsProvider?.removeListener(_loadData);
      _runsProvider = runsProvider;
      _runsProvider!.addListener(_loadData);
    }
  }

  @override
  void dispose() {
    _runsProvider?.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _restoreStatsPeriod() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _statsPeriod = prefs.getInt(_statsPeriodKey) ?? 0;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    // Dispara em paralelo: o boot não deve esperar uma consulta por vez.
    final statsFuture = _dbService.getUserStats(since: _statsSince);
    final progressFuture = _dbService.getWeeklyProgress();
    final profileFuture = _dbService.getUserProfile();
    final lastRunFuture = _dbService.getLastRun();

    final stats = await statsFuture;
    final progress = await progressFuture;
    final profile = await profileFuture;
    final lastRun = await lastRunFuture;

    if (mounted) {
      setState(() {
        _stats = stats;
        _weeklyProgress = progress;
        _profile = profile;
        _lastRun = lastRun;
        _isLoading = false;
      });
      // No modo embutido há um treino vivo por definição: o sheet de
      // recuperação seria absurdo (o pill do modo navegação cobre).
      if (!widget.embedded) _checkForActiveRun();
    }
  }

  Future<void> _checkForActiveRun() async {
    // Só metadados aqui: a rota (centenas de KB) só é lida se o usuário
    // decidir retomar/salvar.
    final activeRun = await _dbService.getActiveRunMeta();
    if (activeRun != null && mounted) {
      _showRecoveryBottomSheet(activeRun);
    }
  }

  void _showRecoveryBottomSheet(Map<String, dynamic> activeRun) {
    final bool isFinished = (activeRun['finished'] ?? 0) == 1;

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
                          await _dbService.clearActiveRun();
                          if (context.mounted) Navigator.pop(context);
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
                          final full = await _dbService.getActiveRun();
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
                              .then((_) => _loadData());
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
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Bom dia,';
    if (hour >= 12 && hour < 18) return 'Boa tarde,';
    return 'Boa noite,';
  }

  double _getMaxY() {
    double maxDist = 0;
    for (var dist in _weeklyProgress) {
      if (dist > maxDist) maxDist = dist;
    }
    // Piso de 2 km para semanas leves + headroom para a barra não encostar
    // no teto. Sem o piso antigo de 10 km: treinos curtos usam a tela toda.
    return maxDist < 2 ? 2 : (maxDist * 1.2).ceilToDouble();
  }

  // Semana começa no domingo (mesma convenção de getWeeklyProgress).
  int get _todayIndex => DateTime.now().weekday % 7;

  // ── Visão Geral: janela dos totais ─────────────────────────────────────

  DateTime? get _statsSince {
    final days = switch (_statsPeriod) {
      1 => 7,
      2 => 15,
      3 => 30,
      4 => 60,
      5 => 90,
      _ => 0,
    };
    return days == 0 ? null : DateTime.now().subtract(Duration(days: days));
  }

  Future<void> _changeStatsPeriod(int index) async {
    if (index == _statsPeriod) return;
    setState(() => _statsPeriod = index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_statsPeriodKey, index);
    final stats = await _dbService.getUserStats(since: _statsSince);
    if (mounted) setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryNeon),
      );
    }

    double weeklyTotal = _weeklyProgress.fold(0, (sum, item) => sum + item);
    double weeklyGoal = _profile?.weeklyGoal ?? 20.0;
    double rawProgress = weeklyGoal > 0 ? weeklyTotal / weeklyGoal : 0.0;
    double goalProgress = rawProgress.clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
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
                                  _profile?.profilePicturePath != null
                                  ? FileImage(
                                      File(_profile!.profilePicturePath!),
                                    )
                                  : null,
                              child: _profile?.profilePicturePath == null
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
                            _getGreeting(),
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
                            _profile?.name ?? 'Atleta',
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
                      ).then((_) => _loadData());
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
                      ).then((_) => _loadData());
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
              if (_lastRun != null) ...[
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
                      builder: (_) => RunDetailScreen(run: _lastRun!),
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
                                '${_lastRun!.distanceKm.toStringAsFixed(2)} km em ${_formatRunDuration(_lastRun!.durationSeconds)}',
                                style: GoogleFonts.outfit(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Ritmo: ${_lastRun!.pace}/km | Calorias: ${_lastRun!.calories} kcal',
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
                  _buildStatsPeriodChip('Tudo', 0, isDark),
                  _buildStatsPeriodChip('7d', 1, isDark),
                  _buildStatsPeriodChip('15d', 2, isDark),
                  _buildStatsPeriodChip('30d', 3, isDark),
                  _buildStatsPeriodChip('60d', 4, isDark),
                  _buildStatsPeriodChip('90d', 5, isDark),
                ],
              ),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    _buildCompactStat(
                      icon: LucideIcons.map,
                      value: _stats['totalDistance'],
                      unit: 'km',
                    ),
                    _buildStatDivider(isDark),
                    _buildCompactStat(
                      icon: LucideIcons.activity,
                      value: _stats['totalRuns'],
                      unit: 'treinos',
                    ),
                    _buildStatDivider(isDark),
                    _buildCompactStat(
                      icon: LucideIcons.timer,
                      value: _stats['avgPace'],
                      unit: '/km',
                    ),
                    _buildStatDivider(isDark),
                    _buildCompactStat(
                      icon: LucideIcons.flame,
                      value: _stats['totalCalories'],
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
                    'Hoje: ${_weeklyProgress[_todayIndex].toStringAsFixed(1)} km',
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
                    maxY: _getMaxY(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            Theme.of(context).colorScheme.surface,
                        tooltipBorder: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
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
                        color: isDark
                            ? Colors.white10
                            : AppColors.borderLight,
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
                            final isToday = index == _todayIndex;
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
                              toY: _weeklyProgress[i],
                              color: i == _todayIndex
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

  String _formatRunDuration(int seconds) {
    if (seconds >= 3600) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return '${h}h ${m}m';
    } else {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return '${m}m ${s.toString().padLeft(2, '0')}s';
    }
  }

  Widget _buildStatsPeriodChip(String label, int index, bool isDark) {
    final selected = _statsPeriod == index;
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeStatsPeriod(index),
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
