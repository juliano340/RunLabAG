import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/database_service.dart';
import '../../../dashboard/domain/models/weekly_evolution_stats.dart';
import '../../domain/models/monthly_evolution_stats.dart';
import '../../domain/models/pace_series_point.dart';
import '../../domain/models/performance_alert.dart';
import '../../domain/services/pace_series_service.dart';
import '../../domain/services/performance_alert_service.dart';
import '../widgets/comparison_card.dart';
import '../widgets/alert_card.dart';
import '../widgets/consistency_card.dart';
import '../widgets/pace_summary_strip.dart';
import '../widgets/pace_trend_chart.dart';
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
  List<PerformanceAlert> _alerts = [];
  Map<String, dynamic> _consistency = {};
  Map<String, dynamic> _comparison = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final weekly = await _dbService.getWeeklyEvolution(12);
    // 12 meses: 6 alimentam a visão "Mês" e todos alimentam a visão "Trimestre".
    final monthly = await _dbService.getMonthlyEvolution(12);

    final now = DateTime.now();
    final startOfCurrentWeek = now.subtract(Duration(days: now.weekday % 7));
    final startOfPrevWeek = startOfCurrentWeek.subtract(const Duration(days: 7));
    final endOfPrevWeek = startOfCurrentWeek.subtract(const Duration(seconds: 1));

    final comparison = await _dbService.comparePeriods(
      startOfCurrentWeek,
      now,
      startOfPrevWeek,
      endOfPrevWeek,
    );

    final records = await _dbService.getPersonalRecords();
    final recentRuns = await _dbService.getRunsBetween(
      now.subtract(const Duration(days: 30)),
      now,
    );

    final alerts = PerformanceAlertService.analyze(
      recentRuns: recentRuns,
      evolution: weekly,
      personalRecords: records,
    );

    final consistency = await _dbService.getConsistencyStats(
      now.subtract(const Duration(days: 90)),
    );

    if (mounted) {
      setState(() {
        _weeklyData = weekly;
        _monthlyData = monthly;
        _alerts = alerts;
        _consistency = consistency;
        _comparison = comparison;
        _isLoading = false;
      });
    }
  }

  /// Série exibida nos gráficos, sempre em ordem cronológica (passado → presente).
  List<PaceSeriesPoint> get _series {
    switch (_selectedPeriod) {
      case 1:
        return PaceSeriesService.fromMonthly(
          _monthlyData.take(6).toList(),
        );
      case 2:
        return PaceSeriesService.quarters(_monthlyData);
      case 0:
      default:
        return PaceSeriesService.fromWeekly(_weeklyData);
    }
  }

  String get _periodCaption {
    final unit = switch (_selectedPeriod) {
      1 => 'meses',
      2 => 'trimestres',
      _ => 'semanas',
    };
    return 'últimas ${_series.length} $unit';
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
              if (_alerts.isNotEmpty) ...[
                _buildAlertsSection(context),
                const SizedBox(height: 20),
              ],
              _buildComparisonSection(context),
              const SizedBox(height: 20),
              _buildConsistencySection(context),
              const SizedBox(height: 24),
            ],
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
    final periods = ['Semana', 'Mês', 'Trimestre'];

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
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackground : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.cardBorder.withValues(alpha: 0.3)
                  : AppColors.borderLight,
            ),
          ),
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
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
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
              child: VolumeHeader(
                totalKm: totalKm,
                totalRuns: totalRuns,
                mutedColor: muted,
                accentColor: accent,
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
        Container(
          padding: const EdgeInsets.fromLTRB(10, 14, 14, 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackground : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.cardBorder.withValues(alpha: 0.3)
                  : AppColors.borderLight,
            ),
          ),
          child: VolumeBarChart(points: series),
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

  Widget _buildComparisonSection(BuildContext context) {
    if (_comparison.isEmpty) return const SizedBox();

    final p1 = _comparison['period1'] as Map<String, dynamic>;
    final p2 = _comparison['period2'] as Map<String, dynamic>;

    return ComparisonCard(
      subtitle: 'Esta semana vs. semana anterior',
      period1Label: 'Esta Sem.',
      period2Label: 'Sem Ant.',
      distance1: (p1['distance'] as num).toDouble(),
      distance2: (p2['distance'] as num).toDouble(),
      runs1: p1['runs'] as int,
      runs2: p2['runs'] as int,
      pace1: (p1['pace'] as num).toDouble(),
      pace2: (p2['pace'] as num).toDouble(),
      calories1: p1['calories'] as int,
      calories2: p2['calories'] as int,
    );
  }

  Widget _buildConsistencySection(BuildContext context) {
    return ConsistencyCard(
      currentStreak: _consistency['currentStreak'] ?? 0,
      bestStreak: _consistency['bestStreak'] ?? 0,
      trainedDays: _consistency['trainedDays'] ?? 0,
      totalDays: _consistency['totalDays'] ?? 0,
      taxaFrequencia: (_consistency['taxaFrequencia'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
