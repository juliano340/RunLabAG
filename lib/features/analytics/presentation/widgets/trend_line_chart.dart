import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/domain/models/weekly_evolution_stats.dart';

class TrendLineChart extends StatelessWidget {
  final List<WeeklyEvolutionStats> data;
  final bool showTrendLine;

  const TrendLineChart({
    super.key,
    required this.data,
    this.showTrendLine = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Sem dados suficientes',
            style: GoogleFonts.outfit(
              color: isDark ? AppColors.textMuted : AppColors.textMutedDark,
            ),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].paceRaw));
    }

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15;
    minY = (minY - padding).clamp(0, double.infinity);
    maxY = maxY + padding;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  isDark ? Colors.black87 : Colors.white,
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final idx = spot.x.toInt();
                  final pace = data[idx].avgPace;
                  return LineTooltipItem(
                    pace,
                    GoogleFonts.outfit(
                      color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark
                  ? AppColors.textMuted.withValues(alpha: 0.15)
                  : AppColors.textMutedDark.withValues(alpha: 0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  int minutes = value.toInt();
                  int seconds = ((value - minutes) * 60).toInt();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '$minutes:${seconds.toString().padLeft(2, '0')}',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: isDark ? AppColors.textMuted : AppColors.textMutedDark,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final start = data[idx].startDate;
                  final label = '${start.day}/${start.month}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: isDark ? AppColors.textMuted : AppColors.textMutedDark,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary,
                    strokeColor: isDark ? Colors.black : Colors.white,
                    strokeWidth: 2,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? AppColors.primaryNeon : AppColors.lightPrimary)
                        .withValues(alpha: 0.3),
                    (isDark ? AppColors.primaryNeon : AppColors.lightPrimary)
                        .withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
