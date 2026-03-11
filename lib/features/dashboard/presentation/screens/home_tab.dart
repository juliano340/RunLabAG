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

import '../../../../core/services/database_service.dart';

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
  UserProfile? _profile;
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
    if (mounted) {
      setState(() {
        _stats = stats;
        _weeklyProgress = progress;
        _profile = profile;
        _isLoading = false;
      });
    }
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryNeon,
        backgroundColor: AppColors.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Profile
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Opcional: Navegar para a tab de perfil
                        },
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
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: GoogleFonts.outfit(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _profile?.name ?? 'Atleta',
                            style: GoogleFonts.outfit(
                              color: AppColors.textLight,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.bell, color: AppColors.textLight),
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
                    ).then((_) => _loadData()); // Refresh on return
                  },
                ),
              ),
              const SizedBox(height: 32),
  
              // Stats Grid
              Text(
                'Suas Estatísticas',
                style: GoogleFonts.outfit(
                  color: AppColors.textLight,
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
                    title: 'Distância Total',
                    value: _stats['totalDistance'],
                    unit: 'km',
                    icon: LucideIcons.map,
                  ),
                  StatCard(
                    title: 'Total de Corridas',
                    value: _stats['totalRuns'],
                    unit: 'treinos',
                    icon: LucideIcons.activity,
                  ),
                  StatCard(
                    title: 'Ritmo Médio',
                    value: _stats['avgPace'],
                    unit: '/km',
                    icon: LucideIcons.timer,
                  ),
                  StatCard(
                    title: 'Calorias',
                    value: _stats['totalCalories'],
                    unit: 'kcal',
                    icon: LucideIcons.flame,
                  ),
                ],
              ),
              const SizedBox(height: 32),
  
              // Progress Chart (Mock fl_chart)
              Text(
                'Progresso Semanal',
                style: GoogleFonts.outfit(
                  color: AppColors.textLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GlassContainer(
                height: 200,
                padding: const EdgeInsets.only(top: 24, bottom: 16, left: 16, right: 16),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxY(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => AppColors.background.withValues(alpha: 0.8),
                        tooltipBorderRadius: BorderRadius.circular(8),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toStringAsFixed(1)} km',
                            const TextStyle(color: AppColors.primaryNeon, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            const style = TextStyle(color: AppColors.textMuted, fontSize: 10);
                            String text;
                            switch (value.toInt()) {
                              case 0: text = 'Seg'; break;
                              case 1: text = 'Ter'; break;
                              case 2: text = 'Qua'; break;
                              case 3: text = 'Qui'; break;
                              case 4: text = 'Sex'; break;
                              case 5: text = 'Sáb'; break;
                              case 6: text = 'Dom'; break;
                              default: text = ''; break;
                            }
                            return SideTitleWidget(
                              meta: meta,
                              space: 4, 
                              child: Text(text, style: style)
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (int i = 0; i < 7; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: _weeklyProgress[i],
                              color: AppColors.primaryNeon,
                              width: 14,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: _getMaxY(),
                                color: AppColors.primaryNeon.withValues(alpha: 0.05),
                              ),
                            )
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
