import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AchievementsTab extends StatelessWidget {
  const AchievementsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final achievements = [
      {'title': 'Primeiro Passo', 'desc': 'Complete sua primeira corrida', 'icon': LucideIcons.footprints, 'earned': true},
      {'title': 'Coruja Noturna', 'desc': 'Corra após as 20h', 'icon': LucideIcons.moon, 'earned': true},
      {'title': 'Finalizador 5K', 'desc': 'Corra 5 quilômetros em uma sessão', 'icon': LucideIcons.medal, 'earned': true},
      {'title': 'Mestre 10K', 'desc': 'Corra 10 quilômetros em uma sessão', 'icon': LucideIcons.trophy, 'earned': false},
      {'title': 'Treino de Maratona', 'desc': 'Corra 100km de distância total', 'icon': LucideIcons.target, 'earned': false},
      {'title': 'Demônio da Velocidade', 'desc': 'Ritmo abaixo de 4:30/km por 1km', 'icon': LucideIcons.zap, 'earned': false},
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conquistas',
              style: GoogleFonts.outfit(
                color: AppColors.textLight,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '3 / 6 Desbloqueado',
              style: GoogleFonts.outfit(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final badge = achievements[index];
                  final bool earned = badge['earned'] as bool;
                  
                  return GlassContainer(
                    hasNeonBorder: earned,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          badge['icon'] as IconData,
                          size: 48,
                          color: earned ? AppColors.primaryNeon : AppColors.textMuted.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          badge['title'] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: earned ? AppColors.textLight : AppColors.textMuted.withValues(alpha: 0.5),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge['desc'] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: earned ? AppColors.textMuted : AppColors.textMuted.withValues(alpha: 0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
