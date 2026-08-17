import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'run_split.dart';
import 'auto_pause_event.dart';

class RunModel {
  final String id;
  final DateTime date;
  final double distanceKm;
  final int durationSeconds;
  final int pausedDurationSeconds;
  final String pace;
  final int calories;
  final List<List<LatLng>> route;
  final String type;
  final String mood;
  final List<RunSplit> splits;
  final List<AutoPauseEvent> autoPauses;

  RunModel({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.durationSeconds,
    this.pausedDurationSeconds = 0,
    required this.pace,
    required this.calories,
    this.route = const [],
    this.type = 'Corrida',
    this.mood = '',
    this.splits = const [],
    this.autoPauses = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'pausedDurationSeconds': pausedDurationSeconds,
      'pace': pace,
      'calories': calories,
      'route': jsonEncode(route.map((segment) =>
        segment.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()
      ).toList()),
      'type': type,
      'mood': mood,
      'splits': jsonEncode(splits.map((s) => s.toMap()).toList()),
      'autoPauses': jsonEncode(autoPauses.map((ap) => ap.toMap()).toList()),
    };
  }

  factory RunModel.fromMap(Map<String, dynamic> map) {
    List<dynamic> routeList = jsonDecode(map['route'] ?? '[]');
    List<dynamic> splitList = jsonDecode(map['splits'] ?? '[]');
    List<dynamic> autoPauseList = jsonDecode(map['autoPauses'] ?? '[]');
    return RunModel(
      id: map['id'],
      date: DateTime.parse(map['date']),
      distanceKm: map['distanceKm'],
      durationSeconds: map['durationSeconds'],
      pausedDurationSeconds: map['pausedDurationSeconds'] ?? 0,
      pace: map['pace'],
      calories: map['calories'],
      route: _decodeRoute(routeList),
      type: map['type'] ?? 'Corrida',
      mood: map['mood'] ?? '',
      splits: splitList.map((s) {
        if (s is Map) return RunSplit.fromMap(s.cast<String, dynamic>());
        if (s is int) return RunSplit(timeSeconds: s, calories: 0);
        return RunSplit(timeSeconds: 0, calories: 0);
      }).toList(),
      autoPauses: autoPauseList.map((ap) => AutoPauseEvent.fromMap(ap.cast<String, dynamic>())).toList(),
    );
  }

  static List<List<LatLng>> _decodeRoute(List<dynamic> list) {
    if (list.isEmpty) return [];

    if (list.first is List) {
      return list.map((segment) {
        return (segment as List).map((p) => LatLng(p['lat'], p['lng'])).toList();
      }).toList();
    }

    return [
      list.map((p) => LatLng(p['lat'], p['lng'])).toList()
    ];
  }
}
