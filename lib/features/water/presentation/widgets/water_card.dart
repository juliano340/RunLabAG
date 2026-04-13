import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:runlabag/core/theme/app_colors.dart';
import 'package:runlabag/core/widgets/glass_container.dart';
import 'package:runlabag/features/water/presentation/providers/water_provider.dart';
import 'add_water_dialog.dart';

class WaterCard extends StatelessWidget {
  const WaterCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<WaterProvider>(
      builder: (context, provider, child) {
        final percentage = provider.progress;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hidratação Diária',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AddWaterDialog(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.lightPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.plus,
                          color: AppColors.lightPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Adicionar',
                          style: GoogleFonts.outfit(
                            color: AppColors.lightPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: percentage,
                          strokeWidth: 6,
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.blueAccent : Colors.blue.shade700,
                          ),
                        ),
                      ),
                      Icon(
                        LucideIcons.droplets,
                        color: isDark
                            ? Colors.blueAccent
                            : Colors.blue.shade700,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${provider.dailyIntake} ml / ${provider.dailyGoal.toInt()} ml',
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white : AppColors.textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: isDark
                                ? Colors.white10
                                : AppColors.borderLight,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? Colors.blueAccent : Colors.blue.shade700,
                            ),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          percentage >= 1.0
                              ? 'Meta batida! Parabéns! 🎉'
                              : 'Faltam ${(provider.dailyGoal - provider.dailyIntake).clamp(0, double.infinity).toInt()} ml para a meta.',
                          style: GoogleFonts.outfit(
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.textMutedDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
