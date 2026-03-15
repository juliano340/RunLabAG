import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/services/database_service.dart';

class AchievementsTab extends StatefulWidget {
  const AchievementsTab({super.key});

  @override
  State<AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<AchievementsTab> {
  final DatabaseService _dbService = DatabaseService();
  List<String> _earnedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final earnedList = await _dbService.getEarnedAchievements();
    if (mounted) {
      setState(() {
        _earnedIds = earnedList.map((e) => e['id'] as String).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final achievements = [
      {'id': 'first_run', 'title': 'Primeiro Passo', 'desc': 'Complete sua primeira corrida', 'icon': LucideIcons.footprints},
      {'id': 'night_owl', 'title': 'Coruja Noturna', 'desc': 'Corra após as 20h', 'icon': LucideIcons.moon},
      {'id': 'finisher_5k', 'title': 'Finalizador 5K', 'desc': 'Corra 5 quilômetros em uma sessão', 'icon': LucideIcons.medal},
      {'id': 'master_10k', 'title': 'Mestre 10K', 'desc': 'Corra 10 quilômetros em uma sessão', 'icon': LucideIcons.trophy},
      {'id': 'marathon_training', 'title': 'Treino de Maratona', 'desc': 'Corra 100km de distância total', 'icon': LucideIcons.target},
      {'id': 'speed_demon', 'title': 'Demônio da Velocidade', 'desc': 'Ritmo abaixo de 4:30/km por 1km', 'icon': LucideIcons.zap},
    ];

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
    }

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
              '${_earnedIds.length} / ${achievements.length} Desbloqueado',
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
                  final bool earned = _earnedIds.contains(badge['id']);
                  
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
