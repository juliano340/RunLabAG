import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/domain/repositories/run_repository.dart';
import '../../../../core/domain/repositories/stats_repository.dart';
import '../../../../core/domain/repositories/user_repository.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/data/data_change_hub.dart';
import '../../../../core/utils/clock.dart';
import '../../application/history_dashboard_view_model.dart';
import '../../domain/history_period.dart';
import '../widgets/pace_distribution_card.dart';
import 'add_run_screen.dart';
import 'run_detail_screen.dart';
import 'package:runlabag/core/domain/models/run_model.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  static const _periods = ['Semana', 'Mês'];

  late final HistoryDashboardViewModel _viewModel;

  // Estado exclusivamente visual: a VM não sabe se a lista está expandida.
  bool _runsExpanded = false;

  @override
  void initState() {
    super.initState();
    _viewModel = HistoryDashboardViewModel(
      runRepository: context.read<RunRepository>(),
      statsRepository: context.read<StatsRepository>(),
      userRepository: context.read<UserRepository>(),
      changes: context.read<DataChangeHub>(),
      clock: const SystemClock(),
    );
    unawaited(_viewModel.initialize());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _showGoalSettings(HistoryDashboardViewModel vm) {
    final periodController = TextEditingController(
      text: vm.currentPeriodGoal.toStringAsFixed(1),
    );
    final globalController = TextEditingController(
      text: vm.defaultGoal.toStringAsFixed(1),
    );
    var isSaving = false;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            final cs = Theme.of(context).colorScheme;
            return AlertDialog(
              backgroundColor: cs.surface,
              title: Text(
                'Configurar Meta',
                style: GoogleFonts.outfit(color: cs.onSurface),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Per-period goal
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock_clock, color: cs.primary, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Meta deste período',
                              style: GoogleFonts.outfit(
                                color: cs.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Altera apenas este período. Não afeta o histórico.',
                          style: GoogleFonts.outfit(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: periodController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: cs.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Meta (km)',
                            labelStyle: TextStyle(color: cs.onSurfaceVariant),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: cs.outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Default / future goal
                  TextField(
                    controller: globalController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Meta padrão futura (km)',
                      helperText: 'Aplicada a novos períodos',
                      helperStyle: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      labelStyle: TextStyle(color: cs.onSurfaceVariant),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: cs.outline),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text(
                    'CANCELAR',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: cs.primary),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final navigator = Navigator.of(context);
                          final saved = await vm.saveGoals(
                            periodGoalText: periodController.text,
                            futureGoalText: globalController.text,
                          );
                          if (!mounted || !context.mounted) return;
                          setDialogState(() => isSaving = false);
                          if (saved) {
                            navigator.pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Não foi possível salvar as metas. Verifique os valores.',
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    'SALVAR',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ).whenComplete(() async {
        // O futuro do showDialog termina no início da animação de saída.
        // Aguardar a rota sair evita usar controllers já descartados.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        periodController.dispose();
        globalController.dispose();
      }),
    );
  }

  Future<void> _openAddRun() async {
    // Os repositórios emitem mudanças de perfil/meta e o histórico recarrega sozinho.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddRunScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final vm = _viewModel;
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dashboard',
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _openAddRun,
                          tooltip: 'Adicionar treino',
                          icon: Icon(
                            LucideIcons.plus,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showGoalSettings(vm),
                          icon: Icon(
                            LucideIcons.settings,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildPeriodSelector(vm),
              const SizedBox(height: 12),
              _buildPaginationHeader(vm),
              const SizedBox(height: 12),
              Expanded(child: _buildHistoryContent(vm)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryContent(HistoryDashboardViewModel vm) {
    if (vm.status == HistoryLoadStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryNeon),
      );
    }
    if (vm.status == HistoryLoadStatus.error) {
      return _buildErrorState(vm);
    }

    return SingleChildScrollView(
      key: const PageStorageKey('history_scroll'),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Atividades',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${vm.filteredRuns.length} treinos',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _buildActivitiesList(vm),
          const SizedBox(height: 24),
          _buildAnalyticsSummary(vm),
          const SizedBox(height: 24),
          if (vm.paceZoneTotals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PaceDistributionCard(
                distanceByZoneKm: vm.paceZoneTotals,
                totalKm: vm.summary.totalKm,
              ),
            ),
          if (vm.paceZoneTotals.isNotEmpty) const SizedBox(height: 24),
          // Dica de evolução no fim do scroll: contexto, não
          // obstáculo antes da lista.
          if (vm.recommendation != null && vm.selectedPeriodIndex == 0)
            _buildRecommendationCard(vm),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildErrorState(HistoryDashboardViewModel vm) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.history,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'Não foi possível carregar o histórico.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => unawaited(vm.refresh()),
              child: Text(
                'Tentar novamente',
                style: GoogleFonts.outfit(color: cs.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(HistoryDashboardViewModel vm) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: List.generate(_periods.length, (index) {
            final isSelected = vm.selectedPeriodIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (isSelected) return;
                  setState(() => _runsExpanded = false);
                  unawaited(index == 0 ? vm.selectWeek() : vm.selectMonth());
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: cs.primary.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Text(
                    _periods[index],
                    style: GoogleFonts.outfit(
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPaginationHeader(HistoryDashboardViewModel vm) {
    final canPrev = vm.canGoPrevious;
    final canNext = vm.canGoNext;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: canPrev
                ? () => _changePeriod(vm.goToPreviousPeriod)
                : null,
            icon: Icon(
              LucideIcons.chevronLeft,
              color: canPrev
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            vm.period.title,
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          IconButton(
            onPressed: canNext ? () => _changePeriod(vm.goToNextPeriod) : null,
            icon: Icon(
              LucideIcons.chevronRight,
              color: canNext
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _changePeriod(Future<void> Function() change) {
    setState(() => _runsExpanded = false);
    unawaited(change());
  }

  Widget _buildAnalyticsSummary(HistoryDashboardViewModel vm) {
    final summary = vm.summary;
    final totalKm = summary.totalKm;
    final totalDur = summary.totalSeconds;
    final totalCal = summary.totalCalories;
    final weightLossKg = summary.estimatedWeightLossKg;
    final goal = vm.currentPeriodGoal;
    final rawProgress = summary.rawGoalProgress;
    final progress = summary.goalProgress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Row 1: Chart & Circle
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Desempenho',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(height: 100, child: _buildBarChart(vm)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Meta',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 70,
                            width: 70,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              color: _getGoalColor(rawProgress),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          Text(
                            '${(rawProgress * 100).toInt()}%',
                            style: GoogleFonts.outfit(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : AppColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${totalKm.toStringAsFixed(1)} / ${goal.toInt()} km',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Stats
          Row(
            children: [
              _buildSmallStat(
                'Duração',
                TimeUtils.formatDuration(totalDur),
                LucideIcons.timer,
              ),
              const SizedBox(width: 12),
              _buildSmallStat('Calorias', '$totalCal kcal', LucideIcons.flame),
              const SizedBox(width: 12),
              _buildSmallStat(
                'Peso Est.',
                '${weightLossKg.toStringAsFixed(3)} kg',
                LucideIcons.scale,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: cs.primary, size: 16),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: cs.onSurfaceVariant,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(HistoryDashboardViewModel vm) {
    final barGroups = [for (final bar in vm.chartBars) _makeGroupData(bar)];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: vm.chartMaxDistance * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
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
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                String text = '';
                if (vm.selectedPeriodIndex == 0) {
                  const days = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
                  text = days[value.toInt() % 7];
                } else {
                  text = 'S${value.toInt() + 1}';
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    text,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  BarChartGroupData _makeGroupData(HistoryChartBar bar) {
    Color barColor = AppColors.primaryNeon;
    if (bar.colorRatio > 0.7) {
      barColor = Colors.purpleAccent;
    } else if (bar.colorRatio > 0.4) {
      barColor = Colors.orangeAccent;
    }

    return BarChartGroupData(
      x: bar.index,
      barRods: [
        BarChartRodData(
          toY: bar.distanceKm,
          color: barColor,
          width: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ],
    );
  }

  Widget _buildActivitiesList(HistoryDashboardViewModel vm) {
    final runs = vm.filteredRuns;
    if (runs.isEmpty) return _buildEmptyState();

    const previewCount = 3;
    final hasMore = runs.length > previewCount;
    final visibleCount = _runsExpanded || !hasMore ? runs.length : previewCount;

    return Column(
      children: [
        for (var i = 0; i < visibleCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildRunCard(runs[i], vm),
          ),
        if (hasMore) _buildRunsToggle(runs.length),
      ],
    );
  }

  /// "Ver mais / Ver menos" — mesmo idioma plano da lista, centralizado.
  Widget _buildRunsToggle(int runCount) {
    final cs = Theme.of(context).colorScheme;
    final hidden = runCount - 3;
    return GestureDetector(
      onTap: () => setState(() => _runsExpanded = !_runsExpanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _runsExpanded ? 'Ver menos' : 'Ver mais $hidden treinos',
              style: GoogleFonts.outfit(
                color: cs.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _runsExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 14,
              color: cs.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(HistoryDashboardViewModel vm) {
    final res = vm.recommendation!;
    final isAlert = res.emoji == '🔴' || res.emoji == '🟡';
    final isInfo = res.emoji == '📊' || res.emoji == '⏱️';
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        borderColor: res.isIncrease
            ? cs.primary.withValues(alpha: 0.3)
            : isAlert
            ? Colors.orangeAccent.withValues(alpha: 0.3)
            : cs.outline.withValues(alpha: 0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(res.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  isInfo ? 'Status da Semana' : 'Dica de Evolução',
                  style: GoogleFonts.outfit(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              res.message,
              style: GoogleFonts.outfit(
                color: cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            if (!isInfo && !isAlert) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: res.isIncrease
                        ? cs.primary
                        : cs.outline.withValues(alpha: 0.15),
                    foregroundColor: res.isIncrease
                        ? cs.onPrimary
                        : cs.onSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: vm.isSaving
                      ? null
                      : () => _applyRecommendation(vm),
                  child: Text(
                    'DEFINIR META PRÓX. SEMANA: ${res.recommendedGoal.toStringAsFixed(1)} KM',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _applyRecommendation(HistoryDashboardViewModel vm) async {
    if (vm.isSaving) return;
    final applied = await vm.applyRecommendation();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied
              ? 'Meta da próxima semana definida! 🚀'
              : 'Não foi possível definir a meta da próxima semana.',
        ),
      ),
    );
  }

  Widget _buildRunCard(RunModel run, HistoryDashboardViewModel vm) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = run.type == 'Caminhada' ? Colors.blueAccent : cs.primary;

    // Item plano estilo Strava: sem card, sem caixa de ícone — distância
    // manda, métricas em linha, data à direita. Divisor de 1px separa.
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RunDetailScreen(run: run)),
        ).then((_) => unawaited(vm.refresh()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.06,
              ),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Indicador fino do tipo de atividade
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${run.distanceKm.toStringAsFixed(2)} km',
                    style: GoogleFonts.outfit(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${TimeUtils.formatDuration(run.durationSeconds)}'
                    ' · ${run.pace}/km · ${run.calories} kcal',
                    style: GoogleFonts.outfit(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _relativeDate(run.date),
                  style: GoogleFonts.outfit(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (run.mood.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(run.mood, style: const TextStyle(fontSize: 14)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 'Hoje' / 'Ontem' / 'dd/MM' — datas recentes ficam mais humanas.
  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    return '${date.day.toString().padLeft(2, '0')}'
        '/${date.month.toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              LucideIcons.history,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma atividade neste período.',
              style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGoalColor(double progress) {
    if (progress <= 0) return AppColors.primaryNeon.withValues(alpha: 0.3);

    // Dragon chasing tail: Chromatic progression
    if (progress < 0.5) {
      // 0 to 0.5: Cyan to Neon Green
      return Color.lerp(
        Colors.cyanAccent,
        AppColors.primaryNeon,
        progress * 2,
      )!;
    } else if (progress < 1.0) {
      // 0.5 to 1.0: Neon Green to Orange
      return Color.lerp(
        AppColors.primaryNeon,
        Colors.orangeAccent,
        (progress - 0.5) * 2,
      )!;
    } else if (progress < 1.5) {
      // 1.0 to 1.5: Orange to Pink/Purple
      return Color.lerp(
        Colors.orangeAccent,
        Colors.pinkAccent,
        (progress - 1.0) * 2,
      )!;
    } else {
      // Over 1.5: Deep Purple
      return Colors.deepPurpleAccent;
    }
  }
}
