import '../models/strength_workout.dart';

abstract class StrengthWorkoutRepository {
  Future<void> saveWorkout(StrengthWorkout workout);
  Future<List<StrengthWorkout>> getWorkouts();
  Future<void> deleteWorkout(String id);
  Future<void> saveToDictionary(String id, String name, String muscleGroupId);
  Future<List<Map<String, dynamic>>> getExerciseDictionary(String muscleGroupId);
}
