import 'dart:convert';

class ExerciseSet {
  final String id;
  final int reps;
  final double? weight;
  final bool isCompleted;

  ExerciseSet({
    required this.id,
    required this.reps,
    this.weight,
    this.isCompleted = false,
  });

  ExerciseSet copyWith({
    String? id,
    int? reps,
    double? weight,
    bool? isCompleted,
  }) {
    return ExerciseSet(
      id: id ?? this.id,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reps': reps,
      'weight': weight,
      'isCompleted': isCompleted,
    };
  }

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    return ExerciseSet(
      id: map['id'] ?? '',
      reps: map['reps']?.toInt() ?? 0,
      weight: map['weight']?.toDouble(),
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class WorkoutExercise {
  final String id;
  final String name;
  final List<ExerciseSet> sets;

  WorkoutExercise({
    required this.id,
    required this.name,
    this.sets = const [],
  });

  WorkoutExercise copyWith({
    String? id,
    String? name,
    List<ExerciseSet>? sets,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sets': sets.map((x) => x.toMap()).toList(),
    };
  }

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      sets: List<ExerciseSet>.from(map['sets']?.map((x) => ExerciseSet.fromMap(x)) ?? []),
    );
  }
}

class WorkoutMuscleGroup {
  final String id;
  final String name;
  final List<WorkoutExercise> exercises;

  WorkoutMuscleGroup({
    required this.id,
    required this.name,
    this.exercises = const [],
  });

  WorkoutMuscleGroup copyWith({
    String? id,
    String? name,
    List<WorkoutExercise>? exercises,
  }) {
    return WorkoutMuscleGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'exercises': exercises.map((x) => x.toMap()).toList(),
    };
  }

  factory WorkoutMuscleGroup.fromMap(Map<String, dynamic> map) {
    return WorkoutMuscleGroup(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      exercises: List<WorkoutExercise>.from(map['exercises']?.map((x) => WorkoutExercise.fromMap(x)) ?? []),
    );
  }
}

class StrengthWorkout {
  final String id;
  final String name;
  final DateTime? date;
  final String? notes;
  final List<WorkoutMuscleGroup> muscleGroups;

  StrengthWorkout({
    required this.id,
    required this.name,
    this.date,
    this.notes,
    this.muscleGroups = const [],
  });

  StrengthWorkout copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? notes,
    List<WorkoutMuscleGroup>? muscleGroups,
  }) {
    return StrengthWorkout(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      muscleGroups: muscleGroups ?? this.muscleGroups,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date?.millisecondsSinceEpoch,
      'notes': notes,
      'muscleGroups': muscleGroups.map((x) => x.toMap()).toList(),
    };
  }

  factory StrengthWorkout.fromMap(Map<String, dynamic> map) {
    return StrengthWorkout(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      date: map['date'] != null ? DateTime.fromMillisecondsSinceEpoch(map['date']) : null,
      notes: map['notes'],
      muscleGroups: List<WorkoutMuscleGroup>.from(map['muscleGroups']?.map((x) => WorkoutMuscleGroup.fromMap(x)) ?? []),
    );
  }

  String toJson() => json.encode(toMap());

  factory StrengthWorkout.fromJson(String source) => StrengthWorkout.fromMap(json.decode(source));
}
