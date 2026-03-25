import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../providers/strength_workout_provider.dart';
import '../../domain/models/strength_workout.dart';
import 'new_workout_screen.dart';

class StrengthHistoryScreen extends StatelessWidget {
  const StrengthHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Diário de Força',
          style: GoogleFonts.outfit(
            color: AppColors.textLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, color: AppColors.primaryNeon),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NewWorkoutScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<StrengthWorkoutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
          }

          final workouts = provider.workouts.where((w) => w.date != null).toList();

          if (workouts.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewWorkoutScreen(
                        template: workouts[index],
                        isEditing: true,
                      ),
                    ),
                  );
                },
                child: _buildWorkoutCard(context, workouts[index]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryNeon,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewWorkoutScreen()),
          );
        },
        icon: const Icon(LucideIcons.dumbbell, color: Colors.black),
        label: Text(
          'Novo Treino',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.dumbbell, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Nenhum treino registrado',
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Comece a registrar seus treinos de\nmusculação hoje mesmo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(BuildContext context, StrengthWorkout workout) {
    final dateFormat = '${workout.date!.day.toString().padLeft(2, '0')}/${workout.date!.month.toString().padLeft(2, '0')}/${workout.date!.year}';
    
    int totalExercises = 0;
    int totalSets = 0;
    for (var group in workout.muscleGroups) {
      totalExercises += group.exercises.length;
      for (var ex in group.exercises) {
        totalSets += ex.sets.length;
      }
    }

    final groupsText = workout.muscleGroups.map((g) => g.name).join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  workout.name.isNotEmpty ? workout.name : 'Treino de Força',
                  style: GoogleFonts.outfit(
                    color: AppColors.textLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  dateFormat,
                  style: GoogleFonts.outfit(
                    color: AppColors.primaryNeon.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (workout.muscleGroups.isNotEmpty) ...[
              Text(
                'Foco: $groupsText',
                style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                _buildStatBadge(LucideIcons.activitySquare, '$totalExercises exercícios'),
                const SizedBox(width: 8),
                _buildStatBadge(LucideIcons.layers, '$totalSets séries'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBorder.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
