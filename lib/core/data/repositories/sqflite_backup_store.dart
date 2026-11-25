import 'package:sqflite/sqflite.dart';

import '../../domain/models/backup_snapshot.dart';
import '../../domain/repositories/backup_store.dart';
import '../../services/database_helper.dart';

class SqfliteBackupStore implements BackupStore {
  static const _tableSpecs = <String, ({String table, bool replaceAll})>{
    'achievements': (table: 'achievements', replaceAll: false),
    'goalHistory': (table: 'goal_history', replaceAll: false),
    'monitoredDistances': (table: 'monitored_distances', replaceAll: true),
    'strengthWorkouts': (table: 'strength_workouts', replaceAll: false),
    'workoutBlocks': (table: 'workout_blocks', replaceAll: false),
    'blockExercises': (table: 'block_exercises', replaceAll: false),
    'strengthTemplates': (
      table: 'strength_workout_templates',
      replaceAll: false,
    ),
    'templateItems': (table: 'template_items', replaceAll: false),
    'trainingEnrollments': (
      table: 'user_training_enrollments',
      replaceAll: true,
    ),
    'paceZones': (table: 'run_pace_zones', replaceAll: false),
    'trainingPlans': (table: 'training_plans', replaceAll: false),
    'planSessions': (table: 'plan_sessions', replaceAll: false),
    'exerciseDictionary': (table: 'exercise_dictionary', replaceAll: false),
  };

  @override
  Future<BackupSnapshot> readSnapshot() async {
    final db = await DatabaseHelper.database;
    final profileRows = await db.query('user_profile');
    final runs = await db.query('runs');
    final tables = <String, List<Map<String, dynamic>>>{};

    for (final entry in _tableSpecs.entries) {
      tables[entry.key] = await db.query(entry.value.table);
    }

    return BackupSnapshot(
      version: BackupSnapshot.currentVersion,
      exportedAt: DateTime.now(),
      profile: profileRows.isEmpty
          ? null
          : Map<String, dynamic>.from(profileRows.first),
      runs: runs,
      tables: tables,
    );
  }

  @override
  Future<String?> getCurrentProfilePhotoPath() async {
    final db = await DatabaseHelper.database;
    final rows = await db.query(
      'user_profile',
      columns: ['profilePicturePath'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['profilePicturePath'] as String?;
  }

  @override
  Future<void> restoreSnapshot(
    BackupSnapshot snapshot, {
    String? restoredPhotoPath,
  }) async {
    final db = await DatabaseHelper.database;
    await db.transaction((txn) async {
      final profile = snapshot.profile;
      if (profile != null) {
        final row = Map<String, dynamic>.from(profile)..remove('photoData');
        if (restoredPhotoPath != null) {
          row['profilePicturePath'] = restoredPhotoPath;
        }
        await txn.insert(
          'user_profile',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await _upsertRows(txn, 'runs', snapshot.runs);

      for (final entry in snapshot.tables.entries) {
        final spec = _tableSpecs[entry.key];
        if (spec == null) continue;
        if (spec.replaceAll) {
          await txn.delete(spec.table);
        }
        await _upsertRows(txn, spec.table, entry.value);
      }
    });
  }

  Future<void> _upsertRows(
    Transaction txn,
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    for (final row in rows) {
      await txn.insert(
        table,
        Map<String, dynamic>.from(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
