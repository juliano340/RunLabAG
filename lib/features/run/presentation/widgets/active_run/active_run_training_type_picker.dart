import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../../core/theme/app_colors.dart';

class ActiveRunTrainingTypePicker {
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundDarkGreen
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          32,
          24,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como foi seu treino?',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Classifique sua atividade para melhor acompanhamento.',
              style: GoogleFonts.outfit(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textMuted
                    : AppColors.textMutedDark,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            _typeOption(
              context: context,
              type: 'Corrida',
              icon: LucideIcons.zap,
              color: AppColors.primaryNeon,
              description: 'Treino contínuo em ritmo de corrida.',
            ),
            const SizedBox(height: 16),
            _typeOption(
              context: context,
              type: 'Caminhada',
              icon: LucideIcons.footprints,
              color: Colors.blueAccent,
              description: 'Caminhada leve ou vigorosa.',
            ),
            const SizedBox(height: 16),
            _typeOption(
              context: context,
              type: 'Corrida/Caminhada',
              icon: LucideIcons.timer,
              color: Colors.orangeAccent,
              description: 'Alternância entre corrida e caminhada.',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCELAR',
                  style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _typeOption({
    required BuildContext context,
    required String type,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textMuted
                          : AppColors.textMutedDark,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
