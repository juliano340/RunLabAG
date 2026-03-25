import 'package:flutter/material.dart';

enum PlanLevel {
  beginner,
  intermediate,
  advanced;

  String get label {
    switch (this) {
      case PlanLevel.beginner: return 'Iniciante';
      case PlanLevel.intermediate: return 'Intermediário';
      case PlanLevel.advanced: return 'Avançado';
    }
  }

  Color get color {
    switch (this) {
      case PlanLevel.beginner: return Colors.greenAccent;
      case PlanLevel.intermediate: return Colors.orangeAccent;
      case PlanLevel.advanced: return Colors.redAccent;
    }
  }
}

enum SessionType {
  easy,
  long,
  intervals,
  tempo,
  rest;

  String get label {
    switch (this) {
      case SessionType.easy: return 'Rodagem Leve';
      case SessionType.long: return 'Longão';
      case SessionType.intervals: return 'Intervalado / Tiros';
      case SessionType.tempo: return 'Tempo Run';
      case SessionType.rest: return 'Descanso';
    }
  }
}

class TrainingPlan {
  final String id;
  final String title;
  final String description;
  final int totalWeeks;
  final PlanLevel level;
  final String goal; // e.g. "Concluir 5km"

  TrainingPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.totalWeeks,
    required this.level,
    required this.goal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'totalWeeks': totalWeeks,
      'level': level.index,
      'goal': goal,
    };
  }

  factory TrainingPlan.fromMap(Map<String, dynamic> map) {
    return TrainingPlan(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      totalWeeks: map['totalWeeks'],
      level: PlanLevel.values[map['level'] ?? 0],
      goal: map['goal'],
    );
  }
}

class PlanSession {
  final String id;
  final String planId;
  final int week; // 1-indexed
  final int day; // 1-indexed (1=Monday, 7=Sunday)
  final String title;
  final SessionType type;
  final double targetDistance; // in km
  final String description;

  PlanSession({
    required this.id,
    required this.planId,
    required this.week,
    required this.day,
    required this.title,
    required this.type,
    required this.targetDistance,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planId': planId,
      'week': week,
      'day': day,
      'title': title,
      'type': type.index,
      'targetDistance': targetDistance,
      'description': description,
    };
  }

  factory PlanSession.fromMap(Map<String, dynamic> map) {
    return PlanSession(
      id: map['id'],
      planId: map['planId'],
      week: map['week'],
      day: map['day'],
      title: map['title'],
      type: SessionType.values[map['type'] ?? 0],
      targetDistance: (map['targetDistance'] as num).toDouble(),
      description: map['description'],
    );
  }
}

class UserPlanEnrollment {
  final String planId;
  final DateTime startDate;
  final int currentWeek;
  final int currentDay;
  final bool isActive;

  UserPlanEnrollment({
    required this.planId,
    required this.startDate,
    this.currentWeek = 1,
    this.currentDay = 1,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'planId': planId,
      'startDate': startDate.toIso8601String(),
      'currentWeek': currentWeek,
      'currentDay': currentDay,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory UserPlanEnrollment.fromMap(Map<String, dynamic> map) {
    return UserPlanEnrollment(
      planId: map['planId'],
      startDate: DateTime.parse(map['startDate']),
      currentWeek: map['currentWeek'] ?? 1,
      currentDay: map['currentDay'] ?? 1,
      isActive: (map['isActive'] ?? 1) == 1,
    );
  }
}
