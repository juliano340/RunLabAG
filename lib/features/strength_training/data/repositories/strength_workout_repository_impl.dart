import '../../../../core/services/database_service.dart';
import '../../domain/models/strength_workout.dart';
import '../../domain/models/workout_block.dart';
import '../../domain/repositories/strength_workout_repository.dart';

class StrengthWorkoutRepositoryImpl implements StrengthWorkoutRepository {
  final DatabaseService _databaseService;

  StrengthWorkoutRepositoryImpl(this._databaseService);

  @override
  Future<void> saveWorkout(StrengthWorkout workout) async {
    await _databaseService.saveStrengthWorkout(workout);
  }

  @override
  Future<List<StrengthWorkout>> getWorkouts() async {
    return await _databaseService.getStrengthWorkouts();
  }

  @override
  Future<void> deleteWorkout(String id) async {
    await _databaseService.deleteStrengthWorkout(id);
  }

  @override
  Future<void> saveToDictionary(String id, String name, String muscleGroupId) async {
    await _databaseService.saveToDictionary(id, name, muscleGroupId);
  }

  @override
  Future<List<Map<String, dynamic>>> getExerciseDictionary(String muscleGroupId) async {
    return await _databaseService.getExerciseDictionary(muscleGroupId);
  }

  // Modular Blocks & Templates
  @override
  Future<void> saveWorkoutBlock(WorkoutBlock block) async {
    await _databaseService.saveWorkoutBlock(block);
  }

  @override
  Future<List<WorkoutBlock>> getWorkoutBlocks() async {
    return await _databaseService.getWorkoutBlocks();
  }

  @override
  Future<void> deleteWorkoutBlock(String id) async {
    await _databaseService.deleteWorkoutBlock(id);
  }

  @override
  Future<void> saveWorkoutTemplate(StrengthWorkoutTemplate template) async {
    await _databaseService.saveWorkoutTemplate(template);
  }

  @override
  Future<List<StrengthWorkoutTemplate>> getWorkoutTemplates() async {
    return await _databaseService.getWorkoutTemplates();
  }

  @override
  Future<void> deleteWorkoutTemplate(String id) async {
    await _databaseService.deleteWorkoutTemplate(id);
  }
}
