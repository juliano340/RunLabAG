import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';

class ComparisonCard extends StatelessWidget {
  final String period1Label;
  final String period2Label;
  final double distance1;
  final double distance2;
  final int runs1;
  final int runs2;
  final double pace1;
  final double pace2;
  final int calories1;
  final int calories2;

  const ComparisonCard({
    super.key,
    required this.period1Label,
    required this.period2Label,
    required this.distance1,
    required this.distance2,
    required this.runs1,
    required this.runs2,
    required this.pace1,
    required this.pace2,
    required this.calories1,
    required this.calories2,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.textMuted : AppColors.textMutedDark;
    final textColor = isDark ? AppColors.textLight : AppColors.textDark;
    final accentColor = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackground : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.cardBorder.withValues(alpha: 0.3)
              : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barChart3,
                  size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                'Comparativo',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Header com labels dos períodos
          Row(
            children: [
              const SizedBox(width: 72),
              Expanded(
                child: Center(
                  child: Text(
                    period2Label,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: mutedColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 44),
              Expanded(
                child: Center(
                  child: Text(
                    period1Label,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRow(context, 'Distância',
              '${distance1.toStringAsFixed(1)} km',
              '${distance2.toStringAsFixed(1)} km',
              distance1 - distance2, 'km', true),
          const SizedBox(height: 6),
          _buildRow(context, 'Pace',
              _formatPace(pace1), _formatPace(pace2),
              pace1 - pace2, 'min/km', false),
          const SizedBox(height: 6),
          _buildRow(context, 'Treinos',
              '$runs1', '$runs2',
              (runs1 - runs2).toDouble(), '', true),
          const SizedBox(height: 6),
          _buildRow(context, 'Calorias',
              '$calories1', '$calories2',
              (calories1 - calories2).toDouble(), 'kcal', true),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String valueCurrent,
    String valuePrevious,
    double delta,
    String unit,
    bool higherIsBetter,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.textMuted : AppColors.textMutedDark;
    final textColor = isDark ? AppColors.textLight : AppColors.textDark;
    final accentColor = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;

    final isPositive = delta > 0.01;
    final isNegative = delta < -0.01;
    final isNeutral = !isPositive && !isNegative;

    Color deltaColor;
    if (isNeutral) {
      deltaColor = mutedColor;
    } else if ((isPositive && higherIsBetter) || (!isPositive && !higherIsBetter)) {
      deltaColor = accentColor;
    } else {
      deltaColor = AppColors.error;
    }

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: mutedColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            valuePrevious,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: textColor,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Center(
            child: isNeutral
                ? Icon(LucideIcons.minus, size: 12, color: mutedColor)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                        size: 12,
                        color: deltaColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _formatDelta(delta, unit),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: deltaColor,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Expanded(
          child: Text(
            valueCurrent,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
      ],
    );
  }

  String _formatPace(double pace) {
    if (pace <= 0) return '-:--';
    int minutes = pace.toInt();
    int seconds = ((pace - minutes) * 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDelta(double delta, String unit) {
    final absDelta = delta.abs();
    if (unit == 'km') {
      return absDelta.toStringAsFixed(1);
    } else if (unit == 'min/km') {
      int min = absDelta.toInt();
      int sec = ((absDelta - min) * 60).toInt();
      return '$min:${sec.toString().padLeft(2, '0')}';
    } else if (unit.isEmpty) {
      return absDelta.toInt().toString();
    }
    return '${absDelta.toInt()}';
  }
}
