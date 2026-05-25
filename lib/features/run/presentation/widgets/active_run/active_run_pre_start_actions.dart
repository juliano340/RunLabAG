import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../../core/theme/app_colors.dart';

class ActiveRunPreStartActions extends StatelessWidget {
  final double? distanceGoal;
  final VoidCallback onStart;
  final VoidCallback onShowGoalDialog;

  const ActiveRunPreStartActions({
    super.key,
    required this.distanceGoal,
    required this.onStart,
    required this.onShowGoalDialog,
  });

  @override
  Widget build(BuildContext context) {
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
}
