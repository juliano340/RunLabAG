import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/pace_series_point.dart';
import '../../domain/services/pace_series_service.dart';

/// Três números que respondem de imediato "como estou?" — pace recente, média
/// da janela e melhor período — mais um chip com a direção da tendência.
class PaceSummaryStrip extends StatelessWidget {
  const PaceSummaryStrip({
    super.key,
    required this.summary,
    this.currentIsLatest = true,
  });

  final TrendSummary summary;

  /// `false` quando o período mais recente não teve treino; nesse caso o
  /// primeiro número representa o último treino, não "atual".
  final bool currentIsLatest;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    final muted = isDark ? AppColors.textMuted : AppColors.textMutedDark;
    final textColor = isDark ? AppColors.textLight : AppColors.textDark;
    final divider = (isDark ? AppColors.textMuted : AppColors.textMutedDark)
        .withValues(alpha: 0.18);

    if (!summary.hasData) {
      return Text(
        'Sem treinos registrados nesse período.',
        style: GoogleFonts.outfit(fontSize: 12, color: muted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  label: currentIsLatest ? 'Atual' : 'Último',
                  value: PaceSeriesPoint.formatPace(summary.currentPace),
                  caption: summary.currentLabel,
                  valueColor: accent,
                ),
              ),
              VerticalDivider(width: 1, thickness: 1, color: divider),
              Expanded(
                child: _Metric(
                  label: 'Média',
                  value: PaceSeriesPoint.formatPace(summary.averagePace),
                  caption: '${summary.activePeriods} período(s)',
                  valueColor: textColor,
                ),
              ),
              VerticalDivider(width: 1, thickness: 1, color: divider),
              Expanded(
                child: _Metric(
                  label: 'Melhor',
                  value: PaceSeriesPoint.formatPace(summary.bestPace),
                  caption: summary.bestLabel,
                  valueColor: textColor,
                ),
              ),
            ],
          ),
        ),
        if (summary.paceDelta != null) ...[
          const SizedBox(height: 12),
          _TrendChip(summary: summary),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.valueColor,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.textMutedDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: muted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: valueColor,
            height: 1.1,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: GoogleFonts.outfit(fontSize: 10, color: muted),
          ),
        ],
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.summary});

  final TrendSummary summary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    final muted = isDark ? AppColors.textMuted : AppColors.textMutedDark;

    final delta = summary.paceDelta!;
    final isUp = summary.isImproving;
    final isDown = summary.isDeclining;

    final color = isUp
        ? accent
        : isDown
            ? (isDark ? AppColors.error : AppColors.errorLight)
            : muted;

    final icon = isUp
        ? LucideIcons.trendingDown
        : isDown
            ? LucideIcons.trendingUp
            : LucideIcons.minus;

    final suffix = isUp
        ? 'mais rápido'
        : isDown
            ? 'mais lento'
            : 'estável';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isUp || isDown ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${PaceSeriesPoint.formatPace(delta.abs())} $suffix '
              'nos últimos 3 períodos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
