import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/domain/models/auto_pause_event.dart';
import '../../../../core/domain/models/run_split.dart';

/// Snapshot tipado dos metadados persistidos de uma corrida.
class RunSessionSnapshot {
  final double distanceKm;
  final int secondsElapsed;
  final int pausedDurationSeconds;
  final int lastKmNotified;
  final double? distanceGoal;
  final int? targetTimeSeconds;
  final DateTime? startTime;
  final bool isPaused;
  final bool isFinished;
  final List<RunSplit> splits;
  final List<AutoPauseEvent> autoPauses;

  const RunSessionSnapshot({
    required this.distanceKm,
    required this.secondsElapsed,
    required this.pausedDurationSeconds,
    required this.lastKmNotified,
    required this.distanceGoal,
    required this.targetTimeSeconds,
    required this.startTime,
    required this.isPaused,
    required this.isFinished,
    required this.splits,
    required this.autoPauses,
  });

  factory RunSessionSnapshot.fromStored(Map<String, dynamic> state) {
    return RunSessionSnapshot(
      distanceKm: (state['distanceKm'] as num?)?.toDouble() ?? 0,
      secondsElapsed: (state['secondsElapsed'] as num?)?.toInt() ?? 0,
      pausedDurationSeconds:
          (state['pausedDurationSeconds'] as num?)?.toInt() ?? 0,
      lastKmNotified: (state['lastKmNotified'] as num?)?.toInt() ?? 0,
      distanceGoal: (state['distanceGoal'] as num?)?.toDouble(),
      targetTimeSeconds: (state['targetTimeSeconds'] as num?)?.toInt(),
      startTime: DateTime.tryParse('${state['startTime']}'),
      isPaused: (state['isPaused'] as num?)?.toInt() == 1,
      isFinished: (state['finished'] as num?)?.toInt() == 1,
      splits: decodeSplits(state['splits']),
      autoPauses: decodeAutoPauses(state['autoPauses']),
    );
  }

  Map<String, dynamic> toMeta({
    required bool finished,
    required DateTime fallbackStartTime,
  }) {
    return {
      'startTime': (startTime ?? fallbackStartTime).toIso8601String(),
      'distanceKm': distanceKm,
      'secondsElapsed': secondsElapsed,
      'pausedDurationSeconds': pausedDurationSeconds,
      'lastKmNotified': lastKmNotified,
      'distanceGoal': distanceGoal,
      'targetTimeSeconds': targetTimeSeconds,
      'isPaused': finished || isPaused ? 1 : 0,
      'finished': finished ? 1 : 0,
      'splits': jsonEncode([for (final split in splits) split.toMap()]),
      'autoPauses': jsonEncode([for (final pause in autoPauses) pause.toMap()]),
    };
  }

  static List<RunSplit> decodeSplits(String? splitsJson) {
    if (splitsJson == null || splitsJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(splitsJson) as List<dynamic>;
      return [
        for (final split in decoded)
          if (split is Map)
            RunSplit.fromMap(split.cast<String, dynamic>())
          else if (split is int)
            RunSplit(timeSeconds: split, calories: 0)
          else
            RunSplit(timeSeconds: 0, calories: 0),
      ];
    } catch (e) {
      debugPrint('RunSession: splits restaurados são inválidos: $e');
      return [];
    }
  }

  static List<AutoPauseEvent> decodeAutoPauses(String? autoPausesJson) {
    if (autoPausesJson == null || autoPausesJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(autoPausesJson) as List<dynamic>;
      return [
        for (final pause in decoded)
          if (pause is Map)
            AutoPauseEvent.fromMap(pause.cast<String, dynamic>())
          else
            throw const FormatException('Autopausa inválida'),
      ];
    } catch (e) {
      debugPrint('RunSession: autopausas restauradas são inválidas: $e');
      return [];
    }
  }
}
