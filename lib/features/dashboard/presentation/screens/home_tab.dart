import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../widgets/stat_card.dart';
import '../widgets/start_run_button.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../features/run/presentation/screens/active_run_screen.dart';

import 'package:runlabag/core/services/database_service.dart';
import 'package:runlabag/features/water/presentation/widgets/water_card.dart';
import '../../domain/models/weekly_evolution_stats.dart';
import 'package:intl/intl.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}


class _HomeTabState extends State<HomeTab> {
  final _dbService = DatabaseService();
  Map<String, dynamic> _stats = {
    'totalDistance': '0.0',
    'totalRuns': '0',
    'avgPace': '0:00',
    'totalCalories': '0',
  };
  List<double> _weeklyProgress = List.filled(7, 0.0);
  List<WeeklyEvolutionStats> _evolutionStats = [];
  UserProfile? _profile;
  RunModel? _lastRun;
  Map<String, dynamic>? _lastAchievement;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stats = await _dbService.getUserStats();
    final progress = await _dbService.getWeeklyProgress();
    final profile = await _dbService.getUserProfile();
    final lastRun = await _dbService.getLastRun();
    final lastAchievement = await _dbService.getLastAchievement();
    final evolution = await _dbService.getWeeklyEvolution(3);
    
    if (mounted) {
      setState(() {
        _stats = stats;
        _weeklyProgress = progress;
        _evolutionStats = evolution;
        _profile = profile;
        _lastRun = lastRun;
        _lastAchievement = lastAchievement;
        _isLoading = false;
      });
      _checkForActiveRun();
    }
  }

  Future<void> _checkForActiveRun() async {
    final activeRun = await _dbService.getActiveRun();
    if (activeRun != null && mounted) {
      _showRecoveryBottomSheet(activeRun);
    }
  }

  void _showRecoveryBottomSheet(Map<String, dynamic> activeRun) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.backgroundDarkGreen,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(LucideIcons.undo2, color: AppColors.primaryNeon, size: 48),
              const SizedBox(height: 16),
              Text(
                'Treino não Finalizado!',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Encontramos um treino que foi interrompido. Deseja retomar de onde parou?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () async {
                        await _dbService.clearActiveRun();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('DESCARTAR', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primaryNeon,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActiveRunScreen(restoredState: activeRun),
                          ),
                        ).then((_) => _loadData());
                      },
                      child: const Text('RETOMAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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
    return maxDist > 10 ? maxDist + 2 : 10;
  }  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
    }

    double weeklyTotal = _weeklyProgress.fold(0, (sum, item) => sum + item);
    double weeklyGoal = _profile?.weeklyGoal ?? 20.0;
    double rawProgress = weeklyGoal > 0 ? weeklyTotal / weeklyGoal : 0.0;
    double goalProgress = rawProgress.clamp(0.0, 1.0);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryNeon,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
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
                              backgroundColor: _getGoalColor(rawProgress).withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(_getGoalColor(rawProgress)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.cardBackground,
                              backgroundImage: _profile?.profilePicturePath != null
                                  ? FileImage(File(_profile!.profilePicturePath!))
                                  : null,
                              child: _profile?.profilePicturePath == null
                                  ? const Icon(LucideIcons.user, color: AppColors.primaryNeon)
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
                              color: Theme.of(context).brightness == Brightness.dark 
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
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '${weeklyTotal.toStringAsFixed(1)} / ${weeklyGoal.toInt()} km',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getGoalColor(rawProgress),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
  
              // Start Run Button (Center)
              Center(
                child: StartRunButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ActiveRunScreen()),
                    ).then((_) => _loadData());
                  },
                ),
              ),
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
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNeon.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.navigation, color: AppColors.primaryNeon),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_lastRun!.distanceKm.toStringAsFixed(2)} km em ${_formatRunDuration(_lastRun!.durationSeconds)}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Ritmo: ${_lastRun!.pace}/km | Calorias: ${_lastRun!.calories} kcal',
                              style: GoogleFonts.outfit(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
              
              // Water Intake Card
              const WaterCard(),
              const SizedBox(height: 32),
  
              // Stats Grid
              Text(
                'Visão Geral',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  StatCard(
                    title: 'Km Total',
                    value: _stats['totalDistance'],
                    unit: 'km',
                    icon: LucideIcons.map,
                  ),
                  StatCard(
                    title: 'Total Treinos',
                    value: _stats['totalRuns'],
                    unit: 'sessões',
                    icon: LucideIcons.activity,
                  ),
                  StatCard(
                    title: 'Ritmo Médio',
                    value: _stats['avgPace'],
                    unit: '/km',
                    icon: LucideIcons.timer,
                  ),
                  StatCard(
                    title: 'Kcal Total',
                    value: _stats['totalCalories'],
                    unit: 'kcal',
                    icon: LucideIcons.flame,
                  ),
                ],
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
                  const Icon(LucideIcons.trendingUp, color: AppColors.primaryNeon, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              GlassContainer(
                height: 220,
                padding: const EdgeInsets.only(top: 24, bottom: 8, left: 16, right: 24),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white10,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            const style = TextStyle(color: Colors.white54, fontSize: 10);
                            switch (value.toInt()) {
                              case 0: return const Text('Dom', style: style);
                              case 1: return const Text('Seg', style: style);
                              case 2: return const Text('Ter', style: style);
                              case 3: return const Text('Qua', style: style);
                              case 4: return const Text('Qui', style: style);
                              case 5: return const Text('Sex', style: style);
                              case 6: return const Text('Sáb', style: style);
                            }
                            return const Text('');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: _getMaxY(),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (int i = 0; i < 7; i++)
                            FlSpot(i.toDouble(), _weeklyProgress[i]),
                        ],
                        isCurved: true,
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryNeon,
                            Colors.orangeAccent,
                            Colors.purpleAccent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryNeon.withValues(alpha: 0.2),
                              Colors.orangeAccent.withValues(alpha: 0.1),
                              Colors.purpleAccent.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Evolution Analysis
              _buildEvolutionAnalysis(),
              const SizedBox(height: 32),

              // Achievement Spotlight
              if (_lastAchievement != null) ...[
                Text(
                  'Conquista Recente',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNeon.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.trophy, color: Colors.orange, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lastAchievement!['title'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _lastAchievement!['description'],
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getGoalColor(double progress) {
    if (progress >= 1.5) return Colors.purpleAccent;
    if (progress >= 1.25) return Colors.amberAccent;
    if (progress >= 1.0) return Colors.orangeAccent;
    return AppColors.primaryNeon;
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

  Widget _buildEvolutionAnalysis() {
    if (_evolutionStats.length < 2) return const SizedBox.shrink();

    final current = _evolutionStats[0];
    final previous = _evolutionStats[1];

    // Calculate Efficiency Trend (Pace)
    final paceDiff = current.paceRaw - previous.paceRaw;
    final isMoreEfficient = paceDiff < 0; // Lower pace = faster/more efficient
    final pacePctChange = previous.paceRaw > 0 ? (paceDiff.abs() / previous.paceRaw) * 100 : 0.0;

    // Calculate Duration Trend
    final durationDiff = current.totalDurationSeconds - previous.totalDurationSeconds;
    final durationIncreased = durationDiff > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Análise de Evolução',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isMoreEfficient ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isMoreEfficient ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                    size: 14,
                    color: isMoreEfficient ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${pacePctChange.toStringAsFixed(1)}% ${isMoreEfficient ? 'Eficiente' : 'Esforço'}',
                    style: GoogleFonts.outfit(
                      color: isMoreEfficient ? Colors.greenAccent : Colors.orangeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Current Week Row
              _buildEvolutionRow(
                current,
                isCurrent: true,
                distDiff: current.totalDistance - previous.totalDistance,
                durDiff: current.totalDurationSeconds - previous.totalDurationSeconds,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10),
              ),
              // Previous Week Row
              _buildEvolutionRow(
                previous,
                isCurrent: false,
              ),
              const SizedBox(height: 16),
              // Interpretation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMoreEfficient ? LucideIcons.sparkles : LucideIcons.info,
                      color: isMoreEfficient ? Colors.amberAccent : AppColors.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isMoreEfficient
                            ? 'Você está batendo suas metas com um ritmo melhor! Continue assim.'
                            : 'O esforço aumentou esta semana. Fique atento à sua recuperação.',
                        style: GoogleFonts.outfit(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEvolutionRow(WeeklyEvolutionStats stats, {required bool isCurrent, double? distDiff, int? durDiff}) {
    final dateFormat = DateFormat('dd/MM');
    final dateRange = '${dateFormat.format(stats.startDate)} - ${dateFormat.format(stats.endDate)}';

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCurrent ? 'Esta Semana' : 'Semana Passada',
              style: GoogleFonts.outfit(
                color: isCurrent ? AppColors.primaryNeon : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              dateRange,
              style: GoogleFonts.outfit(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const Spacer(),
        _buildEvolutionMetric(
          'Meta',
          '${stats.achievementPercentage.toInt()}%',
          stats.achievementPercentage >= 100 ? AppColors.primaryNeon : Colors.orangeAccent,
        ),
        const SizedBox(width: 20),
        _buildEvolutionMetric(
          'Distância',
          '${stats.totalDistance.toStringAsFixed(1)}km',
          Colors.white,
          trendArrow: distDiff != null ? (distDiff >= 0 ? LucideIcons.arrowUp : LucideIcons.arrowDown) : null,
          arrowColor: distDiff != null ? (distDiff >= 0 ? Colors.greenAccent : Colors.redAccent) : null,
        ),
        const SizedBox(width: 20),
        _buildEvolutionMetric(
          'Duração',
          _formatRunDuration(stats.totalDurationSeconds),
          Colors.white70,
          trendArrow: durDiff != null ? (durDiff >= 0 ? LucideIcons.arrowUp : LucideIcons.arrowDown) : null,
          arrowColor: durDiff != null ? (durDiff >= 0 ? Colors.greenAccent : Colors.redAccent) : null,
        ),
      ],
    );
  }

  Widget _buildEvolutionMetric(String label, String value, Color valueColor, {IconData? trendArrow, Color? arrowColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 10),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trendArrow != null) ...[
              Icon(trendArrow, size: 10, color: arrowColor ?? Colors.white),
              const SizedBox(width: 2),
            ],
            Text(
              value,
              style: GoogleFonts.outfit(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
