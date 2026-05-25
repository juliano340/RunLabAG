import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/theme/app_colors.dart';
import 'active_run_goal_ring_painter.dart';

class ActiveRunGoalProgress extends StatelessWidget {
  final bool isDark;
  final double distanceKm;
  final double distanceGoal;
  final String eta;

  const ActiveRunGoalProgress({
    super.key,
    required this.isDark,
    required this.distanceKm,
    required this.distanceGoal,
    required this.eta,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (distanceKm / distanceGoal).clamp(0.0, 1.0);
    final remaining = (distanceGoal - distanceKm).clamp(0.0, distanceGoal);
    final goalColor = progress >= 1.0
        ? Colors.greenAccent
        : AppColors.primaryNeon;

    String etaText = '--:--';
    if (distanceKm > 0.05 && eta.isNotEmpty) {
      etaText = eta;
    }

    final mutedColor = isDark
        ? AppColors.textMuted
        : AppColors.textMutedDark;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: goalColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goalColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CustomPaint(
              painter: ActiveRunGoalRingPainter(
                progress: progress,
                color: goalColor,
              ),
              child: Center(
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: GoogleFonts.outfit(
                    color: goalColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _GoalStat(
                  label: 'META',
                  value: '${distanceGoal.toStringAsFixed(1)} km',
                  valueColor: Theme.of(context).colorScheme.onSurface,
                  labelColor: mutedColor,
                ),
                _GoalStat(
                  label: 'FALTAM',
                  value: '${remaining.toStringAsFixed(2)} km',
                  valueColor: AppColors.primaryNeonLight,
                  labelColor: mutedColor,
                ),
                _GoalStat(
                  label: 'CHEGA EM',
                  value: etaText,
                  valueColor: Theme.of(context).colorScheme.onSurface,
                  labelColor: mutedColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;

  const _GoalStat({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: labelColor,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
