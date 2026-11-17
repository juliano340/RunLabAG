import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/pace_series_point.dart';
import 'chart_axis_utils.dart';

/// Gráfico de tendência de pace.
///
/// Regras de leitura embutidas:
/// * eixo X cronológico (passado → presente);
/// * eixo Y invertido: quanto mais alto, mais rápido (menor pace);
/// * período sem treino vira guia vertical sutil, nunca pace 0:00;
/// * poucos rótulos no eixo X, sempre incluindo o período mais recente.
class PaceTrendChart extends StatelessWidget {
  const PaceTrendChart({super.key, required this.points});

  /// Série em ordem cronológica.
  final List<PaceSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    final muted = isDark ? AppColors.textMuted : AppColors.textMutedDark;
    final tooltipBg = isDark ? const Color(0xFF0E230D) : Colors.white;
    final labelIndexes = pickLabelIndexes(points.length);

    final activePaces = points
        .where((p) => p.hasRuns)
        .map((p) => p.paceMinPerKm!)
        .toList();

    if (activePaces.isEmpty) {
      return _EmptyState(muted: muted);
    }

    final fastest = activePaces.reduce(math.min);
    final slowest = activePaces.reduce(math.max);
    final span = slowest - fastest;
    final step = niceStep(span < 0.5 ? 1.0 : span, targetSteps: 3);

    var topPace = math.max(0.0, niceFloor(fastest - step * 0.35, step));
    var bottomPace = niceCeil(slowest + step * 0.35, step);
    if (bottomPace - topPace < step) bottomPace = topPace + step;

    // Eixo invertido: y = -pace. Assim "mais rápido" fica no topo.
    final minY = -bottomPace;
    final maxY = -topPace;

    final average =
        activePaces.reduce((a, b) => a + b) / activePaces.length;

    final lastActiveIndex = points.lastIndexWhere((p) => p.hasRuns);
    final line = _buildLine(
      accent: accent,
      isDark: isDark,
      lastActiveIndex: lastActiveIndex,
    );
    final gapLines = _buildGapGuides(muted: muted);

    final padX = points.length > 1 ? 0.4 : 0.6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: LineChart(
            LineChartData(
              minX: -padX,
              maxX: (points.length - 1) + padX,
              minY: minY,
              maxY: maxY,
              lineBarsData: [line],
              extraLinesData: ExtraLinesData(
                extraLinesOnTop: false,
                verticalLines: gapLines,
                horizontalLines: [
                  HorizontalLine(
                    y: -average,
                    color: muted.withValues(alpha: 0.45),
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      style: GoogleFonts.outfit(fontSize: 9, color: muted),
                      labelResolver: (_) =>
                          'média ${PaceSeriesPoint.formatPace(average)}',
                    ),
                  ),
                ],
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
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: step,
                    getTitlesWidget: (value, meta) {
                      // Rótulos nas bordas ficam cortados pela metade.
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          PaceSeriesPoint.formatPace(-value),
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: muted,
                          ),
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
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (!isIntegerTick(value)) {
                        return const SizedBox.shrink();
                      }
                      final index = value.round();
                      if (!labelIndexes.contains(index) ||
                          index < 0 ||
                          index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          points[index].axisLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: muted,
                          ),
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
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
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
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map<LineTooltipItem?>((spot) {
                      final index = spot.x.round();
                      if (index < 0 || index >= points.length) return null;
                      if (!points[index].hasRuns) return null;
                      return _tooltipItem(index, accent: accent, muted: muted);
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _Legend(accent: accent, muted: muted),
      ],
    );
  }

  LineTooltipItem _tooltipItem(
    int index, {
    required Color accent,
    required Color muted,
  }) {
    final point = points[index];
    final runsLabel = point.runCount == 1 ? 'treino' : 'treinos';
    return LineTooltipItem(
      '${point.rangeLabel}${point.isOngoing ? ' · em andamento' : ''}',
      GoogleFonts.outfit(
        fontSize: 10,
        color: muted,
        fontWeight: FontWeight.w500,
      ),
      children: [
        TextSpan(
          text: '\n${point.paceLabel} /km',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
        TextSpan(
          text: '\n${point.distanceKm.toStringAsFixed(1)} km · '
              '${point.runCount} $runsLabel',
          style: GoogleFonts.outfit(fontSize: 10, color: muted),
        ),
      ],
    );
  }

  /// Linha sólida passando por todos os períodos com treino. Períodos vazios
  /// entram como guias verticais sutis, não como queda de pace.
  LineChartBarData _buildLine({
    required Color accent,
    required bool isDark,
    required int lastActiveIndex,
  }) {
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final pace = points[i].paceMinPerKm;
      if (pace == null) continue;
      spots.add(FlSpot(i.toDouble(), -pace));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.18,
      preventCurveOverShooting: true,
      color: accent,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final isLatest = spot.x.round() == lastActiveIndex;
          return FlDotCirclePainter(
            radius: isLatest ? 4.5 : 2.8,
            color: accent,
            strokeColor: isDark ? AppColors.background : Colors.white,
            strokeWidth: 2,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  List<VerticalLine> _buildGapGuides({required Color muted}) {
    final lines = <VerticalLine>[];
    for (var i = 0; i < points.length; i++) {
      if (points[i].hasRuns) continue;
      lines.add(
        VerticalLine(
          x: i.toDouble(),
          color: muted.withValues(alpha: 0.14),
          strokeWidth: 1,
          dashArray: const [2, 4],
        ),
      );
    }
    return lines;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.accent,
    required this.muted,
  });

  final Color accent;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _item(
          marker: _LineMarker(color: accent),
          label: 'com treino',
        ),
        _item(
          marker: _GapMarker(color: muted),
          label: 'sem treino',
        ),
        _item(
          marker: Icon(LucideIcons.arrowUp, size: 10, color: muted),
          label: 'mais rápido',
        ),
      ],
    );
  }

  Widget _item({required Widget marker, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 5),
        Text(label, style: _style(muted)),
      ],
    );
  }

  TextStyle _style(Color color) =>
      GoogleFonts.outfit(fontSize: 9, color: color);
}

class _LineMarker extends StatelessWidget {
  const _LineMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 2.5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Marcador de "sem treino": guia vertical tracejada, igual à do gráfico.
class _GapMarker extends StatelessWidget {
  const _GapMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 1.2,
              height: 2,
              margin: const EdgeInsets.symmetric(vertical: 0.5),
              color: color.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.lineChart, size: 22, color: muted),
            const SizedBox(height: 8),
            Text(
              'Sem treinos nesse período',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Registre um treino ou troque o filtro acima',
              style: GoogleFonts.outfit(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
