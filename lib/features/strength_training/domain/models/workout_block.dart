import 'dart:convert';

class BlockExercise {
  final String id;
  final String name;
  final int defaultSets;
  final String? defaultReps;
  final double? defaultWeight;
  final bool isTimeBased;
  final int orderIndex;

  BlockExercise({
    required this.id,
    required this.name,
    this.defaultSets = 3,
    this.defaultReps,
    this.defaultWeight,
    this.isTimeBased = false,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'defaultSets': defaultSets,
      'defaultReps': defaultReps,
      'defaultWeight': defaultWeight,
      'isTimeBased': isTimeBased ? 1 : 0,
      'orderIndex': orderIndex,
    };
  }

  factory BlockExercise.fromMap(Map<String, dynamic> map) {
    return BlockExercise(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      defaultSets: map['defaultSets'] ?? 3,
      defaultReps: map['defaultReps'],
      defaultWeight: map['defaultWeight']?.toDouble(),
      isTimeBased: (map['isTimeBased'] ?? 0) == 1,
      orderIndex: map['orderIndex'] ?? 0,
    );
  }
}

class WorkoutBlock {
  final String id;
  final String name;
  final String? description;
  final List<BlockExercise> exercises;

  WorkoutBlock({
    required this.id,
    required this.name,
    this.description,
    this.exercises = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  factory WorkoutBlock.fromMap(Map<String, dynamic> map, {List<BlockExercise> exercises = const []}) {
    return WorkoutBlock(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      exercises: exercises,
    );
  }
}

enum TemplateItemType { block, exercise }

class TemplateItem {
  final String id;
  final TemplateItemType type;
  final String itemId; // ID do WorkoutBlock ou de um Exercício direto
  final int orderIndex;
  final Map<String, dynamic> overrides;

  TemplateItem({
    required this.id,
    required this.type,
    required this.itemId,
    this.orderIndex = 0,
    this.overrides = const {},
  });

  Map<String, dynamic> toMap(String templateId) {
    return {
      'id': id,
      'templateId': templateId,
      'type': type == TemplateItemType.block ? 'block' : 'exercise',
      'itemId': itemId,
      'orderIndex': orderIndex,
      'overrides': jsonEncode(overrides),
    };
  }

  factory TemplateItem.fromMap(Map<String, dynamic> map) {
    return TemplateItem(
      id: map['id'] ?? '',
      type: map['type'] == 'block' ? TemplateItemType.block : TemplateItemType.exercise,
      itemId: map['itemId'] ?? '',
      orderIndex: map['orderIndex'] ?? 0,
      overrides: jsonDecode(map['overrides'] ?? '{}'),
    );
  }
}

class StrengthWorkoutTemplate {
  final String id;
  final String name;
  final List<TemplateItem> items;

  StrengthWorkoutTemplate({
    required this.id,
    required this.name,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory StrengthWorkoutTemplate.fromMap(Map<String, dynamic> map, {List<TemplateItem> items = const []}) {
    return StrengthWorkoutTemplate(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      items: items,
    );
  }
}
