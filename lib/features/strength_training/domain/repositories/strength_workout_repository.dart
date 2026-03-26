import '../models/strength_workout.dart';
import '../models/workout_block.dart';

abstract class StrengthWorkoutRepository {
  Future<void> saveWorkout(StrengthWorkout workout);
  Future<List<StrengthWorkout>> getWorkouts();
  Future<void> deleteWorkout(String id);
  Future<void> saveToDictionary(String id, String name, String muscleGroupId);
  Future<List<Map<String, dynamic>>> getExerciseDictionary(String muscleGroupId);

  // Modular Blocks & Templates
  Future<void> saveWorkoutBlock(WorkoutBlock block);
  Future<List<WorkoutBlock>> getWorkoutBlocks();
  Future<void> deleteWorkoutBlock(String id);
  Future<void> saveWorkoutTemplate(StrengthWorkoutTemplate template);
  Future<List<StrengthWorkoutTemplate>> getWorkoutTemplates();
  Future<void> deleteWorkoutTemplate(String id);
}
