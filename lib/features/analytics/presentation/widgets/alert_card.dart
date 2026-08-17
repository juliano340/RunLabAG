import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/performance_alert.dart';

class AlertCard extends StatelessWidget {
  final PerformanceAlert alert;

  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color borderColor;
    Color iconColor;

    switch (alert.severity) {
      case AlertSeverity.success:
        bgColor = isDark
            ? AppColors.primaryNeon.withValues(alpha: 0.1)
            : AppColors.lightPrimary.withValues(alpha: 0.1);
        borderColor = isDark
            ? AppColors.primaryNeon.withValues(alpha: 0.3)
            : AppColors.lightPrimary.withValues(alpha: 0.3);
        iconColor = isDark ? AppColors.primaryNeon : AppColors.lightPrimary;
      case AlertSeverity.warning:
        bgColor = isDark
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.orange.shade50;
        borderColor = isDark
            ? Colors.orange.withValues(alpha: 0.3)
            : Colors.orange.withValues(alpha: 0.3);
        iconColor = Colors.orange;
      case AlertSeverity.info:
        bgColor = isDark
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.blue.shade50;
        borderColor = isDark
            ? Colors.blue.withValues(alpha: 0.3)
            : Colors.blue.withValues(alpha: 0.3);
        iconColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_getIcon(), size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textLight : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.description,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: isDark ? AppColors.textMuted : AppColors.textMutedDark,
                  ),
                ),
                if (alert.suggestion != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    alert.suggestion!,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: iconColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (alert.type) {
      case AlertType.plateau:
        return LucideIcons.pause;
      case AlertType.newRecord:
        return LucideIcons.trophy;
      case AlertType.performanceDrop:
        return LucideIcons.trendingDown;
      case AlertType.streakAtRisk:
        return LucideIcons.flame;
    }
  }
}
