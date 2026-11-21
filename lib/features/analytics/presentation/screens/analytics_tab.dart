import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../dashboard/domain/models/weekly_evolution_stats.dart';
import '../../domain/models/monthly_evolution_stats.dart';
import '../../domain/models/pace_series_point.dart';
import '../../domain/models/performance_alert.dart';
import '../../domain/services/pace_series_service.dart';
import '../../domain/services/performance_alert_service.dart';
import '../widgets/alert_card.dart';
import '../widgets/consistency_card.dart';
import '../widgets/pace_summary_strip.dart';
import '../widgets/pace_trend_chart.dart';
import '../widgets/period_comparison_section.dart';
import '../widgets/volume_bar_chart.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final _dbService = DatabaseService();
  int _selectedPeriod = 0;

  List<WeeklyEvolutionStats> _weeklyData = [];
  List<MonthlyEvolutionStats> _monthlyData = [];
  List<RunModel> _weekRuns = [];
  List<PerformanceAlert> _alerts = [];
  Map<String, dynamic> _consistency = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    // "Semana" = dias da semana corrente: começa no domingo.
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday % 7));

    // Dispara em paralelo: quatro consultas independentes.
    // "Mês" = últimas 5 semanas; Trimestre/Semestre/Ano usam meses
    // agregados (12 meses cobrem as três janelas mensais).
    final weeklyFuture = _dbService.getWeeklyEvolution(5);
    final monthlyFuture = _dbService.getMonthlyEvolution(12);
    final weekRunsFuture = _dbService.getRunSummariesBetween(startOfWeek, now);
    final consistencyFuture = _dbService.getConsistencyStats(
      now.subtract(const Duration(days: 90)),
    );

    final weekly = await weeklyFuture;
    final monthly = await monthlyFuture;
    final weekRuns = await weekRunsFuture;
    final consistency = await consistencyFuture;

    // Alertas seguem na granularidade semanal — só semanas completas.
    final alerts = PerformanceAlertService.analyze(evolution: weekly);

    if (mounted) {
      setState(() {
        _weeklyData = weekly;
        _monthlyData = monthly;
        _weekRuns = weekRuns;
        _consistency = consistency;
        _alerts = alerts;
        _isLoading = false;
      });
    }
  }

  /// Série exibida nos gráficos, sempre em ordem cronológica (passado → presente).
  /// O seletor é a JANELA: semana corrente, últimas 5 semanas ou últimos 3 meses.
  List<PaceSeriesPoint> get _series {
    switch (_selectedPeriod) {
      case 1:
        // "Mês": últimas 5 semanas
        return PaceSeriesService.fromWeekly(_weeklyData.take(5).toList());
      case 2:
        // "Trimestre": últimos 3 meses
        return PaceSeriesService.fromMonthly(_monthlyData.take(3).toList());
      case 3:
        // "Semestre": últimos 6 meses
        return PaceSeriesService.fromMonthly(_monthlyData.take(6).toList());
      case 4:
        // "Ano": últimos 12 meses
        return PaceSeriesService.fromMonthly(_monthlyData.toList());
      case 0:
      default:
        // "Semana": dias da semana corrente (domingo → sábado)
        final now = DateTime.now();
        final startOfWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday % 7));
        return PaceSeriesService.fromDays(
          runs: _weekRuns,
          startOfWeek: startOfWeek,
          goalKm: _weeklyData.isNotEmpty ? _weeklyData[0].goalDistance / 7 : 0,
        );
    }
  }

  String get _periodCaption {
    return switch (_selectedPeriod) {
      1 => 'últimas 5 semanas',
      2 => 'últimos 3 meses',
      3 => 'últimos 6 meses',
      4 => 'últimos 12 meses',
      _ => 'semana corrente, dia a dia',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
        body: Center(
          child: CircularProgressIndicator(
            color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary,
          backgroundColor:
              isDark ? AppColors.background : AppColors.backgroundLight,
          child: SingleChildScrollView(
            key: const PageStorageKey('analytics-scroll'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildPeriodSelector(context),
                const SizedBox(height: 20),
                _buildTrendSection(context),
                const SizedBox(height: 20),
                _buildVolumeSection(context),
                const SizedBox(height: 20),
                _buildComparisonSection(context),
                const SizedBox(height: 20),
                if (_alerts.isNotEmpty) ...[
                  _buildAlertsSection(context),
                  const SizedBox(height: 20),
                ],
                _buildConsistencySection(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(LucideIcons.barChart3,
            size: 24,
            color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary),
        const SizedBox(width: 10),
        Text(
          'Análises',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textLight : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final periods = ['Semana', 'Mês', 'Trimestre', 'Semestre', 'Ano'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackground
            : AppColors.surfaceContainerLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.primaryNeon : AppColors.lightPrimary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    periods[index],
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? AppColors.textMuted : AppColors.textMutedDark),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTrendSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.textMutedDark;
    final series = _series;
    final summary = PaceSeriesService.summarize(series);
    final currentIsLatest = series.isNotEmpty && series.last.hasRuns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tendência de Pace',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                _periodCaption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GoogleFonts.outfit(fontSize: 10, color: muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Pace médio por período · menor é melhor',
          style: GoogleFonts.outfit(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: summary.hasData
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaceSummaryStrip(
                      summary: summary,
                      currentIsLatest: currentIsLatest,
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: (isDark ? AppColors.textMuted : AppColors.textMutedDark)
                          .withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 12),
                    PaceTrendChart(points: series),
                  ],
                )
              : PaceTrendChart(points: series),
        ),
      ],
    );
  }

  Widget _buildVolumeSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.textMutedDark;
    final series = _series;

    var totalKm = 0.0;
    var totalRuns = 0;
    for (final point in series) {
      totalKm += point.distanceKm;
      totalRuns += point.runCount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Volume de treino',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                _periodCaption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GoogleFonts.outfit(fontSize: 10, color: muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Distância por período (km)',
          style: GoogleFonts.outfit(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          padding: const EdgeInsets.fromLTRB(10, 14, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Totais em linha própria: no header apertavam e truncavam
              // ("32 trei...") em telas estreitas.
              Align(
                alignment: Alignment.centerLeft,
                child: VolumeHeader(
                  totalKm: totalKm,
                  totalRuns: totalRuns,
                  mutedColor: muted,
                  accentColor: isDark
                      ? AppColors.primaryNeon
                      : AppColors.lightPrimary,
                ),
              ),
              const SizedBox(height: 4),
              VolumeBarChart(points: series),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.bell,
                size: 18,
                color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary),
            const SizedBox(width: 8),
            Text(
              'Alertas',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AlertCard(alert: alert),
            )),
      ],
    );
  }

  /// Comparativo de blocos mensais com janela deslizante.
  Widget _buildComparisonSection(BuildContext context) {
    return PeriodComparisonSection(monthlyData: _monthlyData);
  }

  Widget _buildConsistencySection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.textMutedDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consistência',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textLight : AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'últimos 90 dias',
          style: GoogleFonts.outfit(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 12),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: ConsistencyCard(
            currentStreak: _consistency['currentStreak'] ?? 0,
            bestStreak: _consistency['bestStreak'] ?? 0,
            trainedDays: _consistency['trainedDays'] ?? 0,
            totalDays: _consistency['totalDays'] ?? 0,
            taxaFrequencia:
                (_consistency['taxaFrequencia'] as num?)?.toDouble() ?? 0.0,
          ),
        ),
      ],
    );
  }
}
