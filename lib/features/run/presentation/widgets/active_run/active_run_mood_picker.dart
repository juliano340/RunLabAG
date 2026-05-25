import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/theme/app_colors.dart';

class ActiveRunMoodPicker {
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
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Como você se sentiu?',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Avalie sua experiência neste treino.',
              style: GoogleFonts.outfit(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textMuted
                    : AppColors.textMutedDark,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _moodOption(context, '😣', 'Ruim'),
                _moodOption(context, '😐', 'Médio'),
                _moodOption(context, '🙂', 'Bom'),
                _moodOption(context, '🤩', 'Excelente'),
              ],
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(
                'PULAR',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textMuted
                      : AppColors.textMutedDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _moodOption(BuildContext context, String emoji, String label) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, emoji),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textMuted
                  : AppColors.textMutedDark,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
