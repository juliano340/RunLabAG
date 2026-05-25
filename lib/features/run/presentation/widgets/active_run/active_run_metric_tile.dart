import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/theme/app_colors.dart';

class ActiveRunMetricTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  const ActiveRunMetricTile({
    super.key,
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = isDark
        ? AppColors.primaryNeon
        : AppColors.lightPrimary;
    final Color labelColor = isDark
        ? AppColors.textMuted
        : AppColors.textMutedDark;
    final Color valueColor = isDark ? Colors.white : AppColors.textDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: labelColor,
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: valueColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.outfit(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
