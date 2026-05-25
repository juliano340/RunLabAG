import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/glass_container.dart';
import '../../../../../../core/services/pacing_service.dart';

class ActiveRunPacingCard extends StatelessWidget {
  final PacingFeedback feedback;
  final bool isDark;

  const ActiveRunPacingCard({
    super.key,
    required this.feedback,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _pacingColor(feedback.status);

    return GlassContainer(
      borderColor: statusColor.withValues(alpha: 0.5),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _pacingIcon(feedback.status),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feedback.message,
                      style: GoogleFonts.outfit(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'IDEAL: ${feedback.idealPace}/km',
                          style: GoogleFonts.outfit(
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.textMutedDark,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'ATUAL: ${feedback.currentPace}/km',
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white70 : AppColors.textDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _pacingColor(PacingStatus status) {
    switch (status) {
      case PacingStatus.behind:
        return Colors.redAccent;
      case PacingStatus.ahead:
        return Colors.orange;
      case PacingStatus.onTrack:
        return AppColors.primaryNeon;
      case PacingStatus.none:
        return Colors.grey;
    }
  }

  IconData _pacingIcon(PacingStatus status) {
    switch (status) {
      case PacingStatus.onTrack:
        return LucideIcons.checkCircle;
      case PacingStatus.ahead:
        return LucideIcons.trendingUp;
      case PacingStatus.behind:
        return LucideIcons.trendingDown;
      case PacingStatus.none:
        return LucideIcons.info;
    }
  }
}
