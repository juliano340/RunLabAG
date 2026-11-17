import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/pace_series_point.dart';
import 'chart_axis_utils.dart';

/// Distância por período em barras, com a meta do período como referência.
/// Complementa a curva de pace: mostra *quanto* foi treinado, não só *como*.
class VolumeBarChart extends StatelessWidget {
  const VolumeBarChart({super.key, required this.points});

  final List<PaceSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    final muted = isDark ? AppColors.textMuted : AppColors.textMutedDark;
    final tooltipBg = isDark ? const Color(0xFF0E230D) : Colors.white;

    if (points.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Sem dados suficientes',
            style: GoogleFonts.outfit(fontSize: 12, color: muted),
          ),
        ),
      );
    }

    final maxDistance = points.map((p) => p.distanceKm).reduce(math.max);
    final goal = points.last.goalKm;
    final showGoal = goal > 0 && (maxDistance == 0 || goal <= maxDistance * 2.5);
    // Folga para a linha de meta não encostar na borda superior.
    final dataMax = math.max(maxDistance, showGoal ? goal * 1.05 : 0.0);
    final step = math.max(1.0, niceStep(dataMax <= 0 ? 5 : dataMax, targetSteps: 5));
    var maxY = niceCeil(dataMax <= 0 ? 5 : dataMax, step);
    if (maxY <= 0) maxY = step;

    final labelIndexes = pickLabelIndexes(points.length);
    final lastIndex = points.length - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 34;
        final barWidth =
            (available / points.length * 0.45).clamp(3.0, 14.0).toDouble();

        return SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              minY: 0,
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => tooltipBg,
                  tooltipBorderRadius: BorderRadius.circular(10),
                  tooltipBorder: BorderSide(
                    color: accent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  tooltipMargin: 12,
                  maxContentWidth: 190,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = points[groupIndex];
                    final runsLabel = point.runCount == 1 ? 'treino' : 'treinos';
                    return BarTooltipItem(
                      '${point.rangeLabel}'
                      '${point.isOngoing ? ' · em andamento' : ''}',
                      GoogleFonts.outfit(
                        fontSize: 10,
                        color: muted,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: '\n${point.distanceKm.toStringAsFixed(1)} km',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        TextSpan(
                          text: '\n${point.runCount} $runsLabel',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: muted,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: step,
                    getTitlesWidget: (value, meta) {
                      // Rótulos nas bordas ficam cortados pela metade.
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          value.toStringAsFixed(0),
                          style: GoogleFonts.outfit(fontSize: 9, color: muted),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 ||
                          index >= points.length ||
                          !labelIndexes.contains(index)) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          points[index].axisLabel,
                          style: GoogleFonts.outfit(fontSize: 9, color: muted),
                        ),
                      );
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: muted.withValues(alpha: isDark ? 0.14 : 0.12),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (showGoal)
                    HorizontalLine(
                      y: goal,
                      color: muted.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: const [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 2, bottom: 2),
                        style: GoogleFonts.outfit(fontSize: 9, color: muted),
                        labelResolver: (_) =>
                            'meta ${goal.toStringAsFixed(0)} km',
                      ),
                    ),
                ],
              ),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: points[i].distanceKm,
                        width: barWidth,
                        color: i == lastIndex
                            ? accent
                            : accent.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: accent.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Cabeçalho compacto com o total da janela analisada.
class VolumeHeader extends StatelessWidget {
  const VolumeHeader({
    super.key,
    required this.totalKm,
    required this.totalRuns,
    required this.mutedColor,
    required this.accentColor,
  });

  final double totalKm;
  final int totalRuns;
  final Color mutedColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.mapPin, size: 13, color: mutedColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${totalKm.toStringAsFixed(1)} km',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '$totalRuns ${totalRuns == 1 ? 'treino' : 'treinos'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 11, color: mutedColor),
          ),
        ),
      ],
    );
  }
}
