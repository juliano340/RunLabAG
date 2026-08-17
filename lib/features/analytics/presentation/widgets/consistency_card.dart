import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';

class ConsistencyCard extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final int trainedDays;
  final int totalDays;
  final double taxaFrequencia;

  const ConsistencyCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.trainedDays,
    required this.totalDays,
    required this.taxaFrequencia,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final freqPct = (taxaFrequencia * 100).toInt();

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendar,
                  size: 18,
                  color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary),
              const SizedBox(width: 8),
              Text(
                'Consistência',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(
                context,
                icon: LucideIcons.flame,
                label: 'Streak Atual',
                value: '$currentStreak dias',
                color: currentStreak > 0
                    ? (isDark ? AppColors.primaryNeon : AppColors.lightPrimary)
                    : null,
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                context,
                icon: LucideIcons.award,
                label: 'Melhor Streak',
                value: '$bestStreak dias',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(
                context,
                icon: LucideIcons.calendarCheck,
                label: 'Dias Treinados',
                value: '$trainedDays / $totalDays',
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                context,
                icon: LucideIcons.percent,
                label: 'Frequência',
                value: '$freqPct%',
                color: _getFreqColor(freqPct, isDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProgressBar(context, freqPct / 100),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? AppColors.textLight : AppColors.textDark);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: effectiveColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: isDark ? AppColors.textMuted : AppColors.textMutedDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, double progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: isDark
            ? AppColors.textMuted.withValues(alpha: 0.15)
            : AppColors.textMutedDark.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation<Color>(
          _getFreqColor((progress * 100).toInt(), isDark),
        ),
      ),
    );
  }

  Color _getFreqColor(int pct, bool isDark) {
    if (pct >= 70) return isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
    if (pct >= 40) return Colors.orange;
    return AppColors.error;
  }
}
