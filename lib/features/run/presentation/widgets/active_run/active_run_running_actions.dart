import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../../core/services/pacing_service.dart';
import '../../../../../../core/theme/app_colors.dart';
import 'active_run_pacing_card.dart';

class ActiveRunRunningActions extends StatelessWidget {
  final bool isDark;
  final bool isPaused;
  final bool isAutoPaused;
  final double? distanceGoal;
  final String eta;
  final PacingFeedback? pacingFeedback;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const ActiveRunRunningActions({
    super.key,
    required this.isDark,
    required this.isPaused,
    required this.isAutoPaused,
    required this.distanceGoal,
    required this.eta,
    required this.pacingFeedback,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (pacingFeedback != null && pacingFeedback!.status != PacingStatus.none)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ActiveRunPacingCard(
              feedback: pacingFeedback!,
              isDark: isDark,
            ),
          )
        else if (distanceGoal != null && eta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.clock,
                  size: 16,
                  color: AppColors.primaryNeon,
                ),
                const SizedBox(width: 8),
                Text(
                  'CHEGADA ESTIMADA: $eta',
                  style: const TextStyle(
                    color: AppColors.primaryNeon,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            if (isPaused || isAutoPaused)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF1E3D1A)
                        : AppColors.lightPrimary,
                    foregroundColor: isDark
                        ? AppColors.primaryNeon
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onResume,
                  icon: const Icon(LucideIcons.play, size: 20),
                  label: const Text(
                    'RETOMAR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF3D2B0E)
                        : Colors.orange.shade700,
                    foregroundColor: isDark
                        ? const Color(0xFFFFA726)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onPause,
                  icon: const Icon(LucideIcons.pause, size: 20),
                  label: const Text(
                    'PAUSAR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF2B0E0E)
                      : Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: onStop,
                icon: const Icon(LucideIcons.square, size: 20),
                label: const Text(
                  'PARAR',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
