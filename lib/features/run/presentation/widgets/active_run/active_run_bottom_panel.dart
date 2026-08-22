import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/services/pacing_service.dart';
import '../../../../../../core/utils/time_utils.dart';
import 'active_run_finished_actions.dart';
import 'active_run_goal_progress.dart';
import 'active_run_metric_tile.dart';
import 'active_run_pre_start_actions.dart';
import 'active_run_running_actions.dart';

class ActiveRunBottomPanel extends StatelessWidget {
  final bool isDark;
  final bool isRunning;
  final bool isPaused;
  final bool isAutoPaused;
  final bool isFinished;
  final bool isSaving;
  final double distanceKm;
  final double? distanceGoal;
  final String formattedTime;
  final String pace;
  final String calories;
  final String eta;
  final PacingFeedback? pacingFeedback;
  final int pausedSeconds;

  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onShowGoalDialog;
  final Future<void> Function() onDiscard;
  final Future<void> Function() onSave;

  const ActiveRunBottomPanel({
    super.key,
    required this.isDark,
    required this.isRunning,
    required this.isPaused,
    required this.isAutoPaused,
    required this.isFinished,
    required this.isSaving,
    required this.distanceKm,
    required this.distanceGoal,
    required this.formattedTime,
    required this.pace,
    required this.calories,
    required this.eta,
    this.pacingFeedback,
    required this.pausedSeconds,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onShowGoalDialog,
    required this.onDiscard,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0A120A).withValues(alpha: 0.97)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? AppColors.primaryNeon.withValues(alpha: 0.15)
                  : AppColors.primaryNeon.withValues(alpha: 0.3),
            ),
            boxShadow: [
              if (isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle bar ──
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // ── DURAÇÃO label ──
              Text(
                'DURAÇÃO',
                style: GoogleFonts.outfit(
                  color: isDark
                      ? AppColors.textMuted
                      : AppColors.textMutedDark,
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              // ── Timer grande ──
              Text(
                formattedTime,
                style: GoogleFonts.outfit(
                  color: isDark
                      ? AppColors.primaryNeon
                      : AppColors.lightPrimary,
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  height: 1.1,
                ),
              ),
              if (pausedSeconds > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F120A) : const Color(0xFFFDF2E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.orange.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.pause,
                        size: 11,
                        color: isDark ? Colors.orange : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'EM PAUSA: ${TimeUtils.formatDuration(pausedSeconds)}',
                        style: GoogleFonts.outfit(
                          color: isDark ? Colors.orange : Colors.orange.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else
                const SizedBox(height: 20),
              // ── 3 métricas em linha ──
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: ActiveRunMetricTile(
                        isDark: isDark,
                        icon: LucideIcons.footprints,
                        label: 'DISTÂNCIA',
                        value: distanceKm.toStringAsFixed(2),
                        unit: 'km',
                      ),
                    ),
                    VerticalDivider(
                      color: isDark ? Colors.white12 : Colors.black12,
                      thickness: 1,
                      width: 1,
                    ),
                    Expanded(
                      child: ActiveRunMetricTile(
                        isDark: isDark,
                        icon: LucideIcons.timer,
                        label: 'RITMO',
                        value: pace,
                        unit: 'min/km',
                      ),
                    ),
                    VerticalDivider(
                      color: isDark ? Colors.white12 : Colors.black12,
                      thickness: 1,
                      width: 1,
                    ),
                    Expanded(
                      child: ActiveRunMetricTile(
                        isDark: isDark,
                        icon: LucideIcons.zap,
                        label: 'CALORIAS',
                        value: calories,
                        unit: 'kcal',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Circular Goal Progress (only when goal is set)
              if (distanceGoal != null && distanceGoal! > 0 && !isFinished)
                ActiveRunGoalProgress(
                  isDark: isDark,
                  distanceKm: distanceKm,
                  distanceGoal: distanceGoal!,
                  eta: eta,
                ),
              const SizedBox(height: 20),
              if (isFinished)
                ActiveRunFinishedActions(
                  isSaving: isSaving,
                  onDiscard: onDiscard,
                  onSave: onSave,
                )
              else if (!isRunning)
                ActiveRunPreStartActions(
                  distanceGoal: distanceGoal,
                  onStart: onStart,
                  onShowGoalDialog: onShowGoalDialog,
                )
              else
                ActiveRunRunningActions(
                  isDark: isDark,
                  isPaused: isPaused,
                  isAutoPaused: isAutoPaused,
                  distanceGoal: distanceGoal,
                  eta: eta,
                  pacingFeedback: pacingFeedback,
                  onPause: onPause,
                  onResume: onResume,
                  onStop: onStop,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
