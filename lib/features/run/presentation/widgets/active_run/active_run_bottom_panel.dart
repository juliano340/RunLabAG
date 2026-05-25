import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/services/pacing_service.dart';
import 'active_run_metric_tile.dart';
import 'active_run_pacing_card.dart';

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
                _buildGoalProgress(context),
              const SizedBox(height: 20),
              if (isFinished)
                _buildFinishedButtons(context)
              else if (!isRunning)
                _buildPreRunButtons()
              else
                _buildRunningButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalProgress(BuildContext context) {
    final goal = distanceGoal!;
    final progress = (distanceKm / goal).clamp(0.0, 1.0);
    final remaining = (goal - distanceKm).clamp(0.0, goal);
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
              painter: _GoalRingPainter(progress: progress, color: goalColor),
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
                _goalStat('META', '${goal.toStringAsFixed(1)} km', Theme.of(context).colorScheme.onSurface, mutedColor),
                _goalStat('FALTAM', '${remaining.toStringAsFixed(2)} km', AppColors.primaryNeonLight, mutedColor),
                _goalStat('CHEGA EM', etaText, Theme.of(context).colorScheme.onSurface, mutedColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalStat(String label, String value, Color valueColor, Color labelColor) {
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

  Widget _buildFinishedButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () async => onDiscard(),
            child: const Text(
              'DESCARTAR',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primaryNeon,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: isSaving ? null : () async => onSave(),
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    'SALVAR TREINO',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreRunButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(
                color: distanceGoal != null
                    ? AppColors.primaryNeon
                    : Colors.white24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: onShowGoalDialog,
            icon: Icon(
              LucideIcons.target,
              color: distanceGoal != null
                  ? AppColors.primaryNeon
                  : Colors.white70,
            ),
            label: Text(
              distanceGoal != null
                  ? 'META: ${distanceGoal!.toInt()}KM'
                  : 'DEFINIR META',
              style: TextStyle(
                color: distanceGoal != null
                    ? AppColors.primaryNeon
                    : Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primaryNeon,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: onStart,
            child: const Text(
              'INICIAR',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRunningButtons(BuildContext context) {
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

// ─── CustomPainter para o anel de progresso da meta ───────────────────────────
class _GoalRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _GoalRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      3.14159 * 2 * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_GoalRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
