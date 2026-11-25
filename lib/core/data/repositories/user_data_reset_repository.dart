import 'package:flutter/foundation.dart';

import '../../domain/repositories/user_data_reset_repository.dart';
import '../../services/database_helper.dart';

class SqfliteUserDataResetRepository implements UserDataResetRepository {
  @override
  Future<void> resetAllData() async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      for (final table in [
        'runs',
        'run_pace_zones',
        'user_profile',
        'achievements',
        'active_run',
        'active_run_route',
        'goal_history',
        'training_plans',
        'plan_sessions',
        'user_training_enrollments',
        'strength_workouts',
        'workout_blocks',
        'block_exercises',
        'strength_workout_templates',
        'template_items',
      ]) {
        try {
          await txn.delete(table);
        } catch (e) {
          debugPrint('Reset: falha ao apagar $table: $e');
        }
      }

      try {
        await txn.delete('monitored_distances');
      } catch (e) {
        debugPrint('Reset: falha ao limpar monitored_distances: $e');
      }
      for (final distance in [1.0, 5.0, 10.0, 15.0]) {
        await txn.insert('monitored_distances', {'distanceKm': distance});
      }
    });
  }
}
