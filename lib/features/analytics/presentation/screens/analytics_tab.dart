import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/database_service.dart';
import '../../../dashboard/domain/models/weekly_evolution_stats.dart';
import '../../domain/models/monthly_evolution_stats.dart';
import '../../domain/models/performance_alert.dart';
import '../../domain/services/performance_alert_service.dart';
import '../widgets/trend_line_chart.dart';
import '../widgets/comparison_card.dart';
import '../widgets/alert_card.dart';
import '../widgets/consistency_card.dart';

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
    final monthly = await _dbService.getMonthlyEvolution(6);

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
    final data = _selectedPeriod == 0
        ? _weeklyData
        : _selectedPeriod == 1
            ? _monthlyData.map((m) => WeeklyEvolutionStats(
                  periodId: m.periodId,
                  startDate: m.startDate,
                  endDate: m.endDate,
                  totalDistance: m.totalDistance,
                  totalDurationSeconds: m.totalDurationSeconds,
                  goalDistance: m.goalDistance,
                  runCount: m.runCount,
                )).toList()
            : _weeklyData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tendência de Pace',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textLight : AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackground : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.cardBorder.withValues(alpha: 0.3)
                  : AppColors.borderLight,
            ),
          ),
          child: TrendLineChart(data: data),
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
