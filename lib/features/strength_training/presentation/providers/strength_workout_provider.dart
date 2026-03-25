import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/strength_workout.dart';
import '../../domain/repositories/strength_workout_repository.dart';

class StrengthWorkoutProvider with ChangeNotifier {
  final StrengthWorkoutRepository _repository;

  List<StrengthWorkout> _workouts = [];
  bool _isLoading = false;

  StrengthWorkoutProvider(this._repository);

  List<StrengthWorkout> get workouts => _workouts;
  bool get isLoading => _isLoading;

  Future<void> loadWorkouts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _workouts = await _repository.getWorkouts();
    } catch (e) {
      debugPrint('Error loading workouts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveWorkout(StrengthWorkout workout) async {
    try {
      await _repository.saveWorkout(workout);
      
      // Update dictionary
      for (var group in workout.muscleGroups) {
        for (var exercise in group.exercises) {
          await _repository.saveToDictionary(
            const Uuid().v4(), 
            exercise.name, 
            group.name, // Using name as group ID for simplicity, or we can use predefined IDs
          );
        }
      }
      
      await loadWorkouts(); // Reload to refresh the list
    } catch (e) {
      debugPrint('Error saving workout: $e');
      rethrow;
    }
  }

  Future<void> deleteWorkout(String id) async {
    try {
      await _repository.deleteWorkout(id);
      _workouts.removeWhere((w) => w.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting workout: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> getExerciseSuggestions(String muscleGroup) async {
    try {
      return await _repository.getExerciseDictionary(muscleGroup);
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
      return [];
    }
  }
}
