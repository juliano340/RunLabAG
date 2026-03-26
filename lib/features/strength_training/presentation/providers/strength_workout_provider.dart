import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/strength_workout.dart';
import '../../domain/models/workout_block.dart';
import '../../domain/repositories/strength_workout_repository.dart';

class StrengthWorkoutProvider with ChangeNotifier {
  final StrengthWorkoutRepository _repository;

  List<StrengthWorkout> _workouts = [];
  List<WorkoutBlock> _blocks = [];
  List<StrengthWorkoutTemplate> _templates = [];
  bool _isLoading = false;

  StrengthWorkoutProvider(this._repository) {
    _initialLoad();
  }

  List<StrengthWorkout> get workouts => _workouts;
  List<WorkoutBlock> get blocks => _blocks;
  List<StrengthWorkoutTemplate> get templates => _templates;
  bool get isLoading => _isLoading;

  Future<void> _initialLoad() async {
    await loadWorkouts();
    await loadBlocks();
    await loadTemplates();
  }

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

  // --- Modular Blocks ---

  Future<void> loadBlocks() async {
    try {
      _blocks = await _repository.getWorkoutBlocks();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading blocks: $e');
    }
  }

  Future<void> saveBlock(WorkoutBlock block) async {
    try {
      await _repository.saveWorkoutBlock(block);
      await loadBlocks();
    } catch (e) {
      debugPrint('Error saving block: $e');
      rethrow;
    }
  }

  Future<void> deleteBlock(String id) async {
    try {
      await _repository.deleteWorkoutBlock(id);
      _blocks.removeWhere((b) => b.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting block: $e');
    }
  }

  // --- Modular Templates ---

  Future<void> loadTemplates() async {
    try {
      _templates = await _repository.getWorkoutTemplates();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading templates: $e');
    }
  }

  Future<void> saveTemplate(StrengthWorkoutTemplate template) async {
    try {
      await _repository.saveWorkoutTemplate(template);
      await loadTemplates();
    } catch (e) {
      debugPrint('Error saving template: $e');
      rethrow;
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      await _repository.deleteWorkoutTemplate(id);
      _templates.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting template: $e');
    }
  }

  /// Converts a template into a StrengthWorkout session object.
  /// Flattens blocks into muscle groups and exercises.
  StrengthWorkout createWorkoutFromTemplate(StrengthWorkoutTemplate template) {
    List<WorkoutMuscleGroup> muscleGroups = [];

    // Temporary map to group exercises by muscle group name from blocks
    Map<String, List<WorkoutExercise>> groupsMap = {};

    for (var item in template.items) {
      if (item.type == TemplateItemType.block) {
        final block = _blocks.firstWhere((b) => b.id == item.itemId, orElse: () => WorkoutBlock(id: '', name: ''));
        if (block.id.isEmpty) continue;

        // Use block name as the muscle group name for now, 
        // or we could have a more advanced mapping.
        // For simplicity, let's group by block name.
        final groupName = block.name;
        if (!groupsMap.containsKey(groupName)) {
          groupsMap[groupName] = [];
        }

        for (var ex in block.exercises) {
          // Check for overrides in item.overrides (TODO)
          
          final workoutEx = WorkoutExercise(
            id: const Uuid().v4(),
            name: ex.name,
            sets: List.generate(ex.defaultSets, (_) => ExerciseSet(
              id: const Uuid().v4(),
              reps: int.tryParse(ex.defaultReps ?? '10') ?? 10,
              weight: ex.defaultWeight,
            )),
          );
          groupsMap[groupName]!.add(workoutEx);
        }
      }
    }

    groupsMap.forEach((name, exercises) {
      muscleGroups.add(WorkoutMuscleGroup(
        id: const Uuid().v4(),
        name: name,
        exercises: exercises,
      ));
    });

    return StrengthWorkout(
      id: const Uuid().v4(),
      name: template.name,
      date: DateTime.now(),
      muscleGroups: muscleGroups,
    );
  }
}
