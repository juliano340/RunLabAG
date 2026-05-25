// Barrel file — re-exports split dialog modules for backward compatibility.
// Also provides ActiveRunDialogs facade to avoid breaking existing callers.
export 'active_run_confirm_dialogs.dart';
export 'active_run_training_type_picker.dart';
export 'active_run_mood_picker.dart';
export 'active_run_goal_dialog.dart';

import 'package:flutter/material.dart';
import 'active_run_confirm_dialogs.dart';
import 'active_run_training_type_picker.dart';
import 'active_run_mood_picker.dart';
import 'active_run_goal_dialog.dart';
import '../../../../../../core/services/pacing_service.dart';

/// Backward-compatible facade that delegates to the split modules.
class ActiveRunDialogs {
  static Future<bool?> showDiscardConfirmation(BuildContext context) {
    return ActiveRunConfirmDialogs.showDiscardConfirmation(context);
  }

  static Future<bool?> showExitConfirmation(BuildContext context) {
    return ActiveRunConfirmDialogs.showExitConfirmation(context);
  }

  static Future<bool?> showShortRunWarning(BuildContext context, int distanceMeters, int seconds) {
    return ActiveRunConfirmDialogs.showShortRunWarning(context, distanceMeters, seconds);
  }

  static Future<String?> showTrainingTypePicker(BuildContext context) {
    return ActiveRunTrainingTypePicker.show(context);
  }

  static Future<String?> showMoodPicker(BuildContext context) {
    return ActiveRunMoodPicker.show(context);
  }

  static void showGoalDialog(
    BuildContext context, {
    double? initialDistanceGoal,
    required Function(double distance, int? targetTimeSeconds, PacingService? pacingService) onGoalSet,
    required VoidCallback onNoGoal,
  }) {
    ActiveRunGoalDialog.show(
      context,
      initialDistanceGoal: initialDistanceGoal,
      onGoalSet: onGoalSet,
      onNoGoal: onNoGoal,
    );
  }
}
