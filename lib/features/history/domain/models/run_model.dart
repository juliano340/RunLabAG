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
  /// Segundos ativos decorridos por ponto, paralelo a [route].
  /// Vazio quando não há dados de tempo (treinos antigos ou rotas desenhadas).
  final List<List<int>> routeTimes;
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
    this.routeTimes = const [],
    this.type = 'Corrida',
    this.mood = '',
    this.splits = const [],
    this.autoPauses = const [],
  });

  RunModel copyWith({
    double? distanceKm,
    String? pace,
    int? calories,
    int? durationSeconds,
    List<List<LatLng>>? route,
    List<List<int>>? routeTimes,
  }) {
    return RunModel(
      id: id,
      date: date,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pausedDurationSeconds: pausedDurationSeconds,
      pace: pace ?? this.pace,
      calories: calories ?? this.calories,
      route: route ?? this.route,
      // Trocar a rota sem informar novos tempos invalida os tempos antigos.
      routeTimes: route != null && routeTimes == null
          ? const []
          : (routeTimes ?? this.routeTimes),
      type: type,
      mood: mood,
      splits: splits,
      autoPauses: autoPauses,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'pausedDurationSeconds': pausedDurationSeconds,
      'pace': pace,
      'calories': calories,
      'route': jsonEncode(_encodeRoute(route, routeTimes)),
      'type': type,
      'mood': mood,
      'splits': jsonEncode(splits.map((s) => s.toMap()).toList()),
      'autoPauses': jsonEncode(autoPauses.map((ap) => ap.toMap()).toList()),
    };
  }

  /// Codifica a rota como segmentos de {lat, lng} e, quando existem,
  /// inclui o tempo ativo 't' de cada ponto (formato retrocompatível).
  static List<List<Map<String, dynamic>>> _encodeRoute(
    List<List<LatLng>> route,
    List<List<int>> times,
  ) {
    final hasTimes = times.length == route.length;
    return route.asMap().entries.map((entry) {
      final segTimes = hasTimes ? times[entry.key] : null;
      return entry.value.asMap().entries.map((p) {
        return {
          'lat': p.value.latitude,
          'lng': p.value.longitude,
          if (segTimes != null && p.key < segTimes.length) 't': segTimes[p.key],
        };
      }).toList();
    }).toList();
  }

  factory RunModel.fromMap(Map<String, dynamic> map) {
    List<dynamic> routeList = jsonDecode(map['route'] ?? '[]');
    List<dynamic> splitList = jsonDecode(map['splits'] ?? '[]');
    List<dynamic> autoPauseList = jsonDecode(map['autoPauses'] ?? '[]');
    return RunModel(
      id: map['id'],
      date: DateTime.parse(map['date']),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      pausedDurationSeconds: (map['pausedDurationSeconds'] as num?)?.toInt() ?? 0,
      pace: map['pace'] ?? '0:00',
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      route: _decodeRoute(routeList),
      routeTimes: _decodeRouteTimes(routeList),
      type: map['type'] ?? 'Corrida',
      mood: map['mood'] ?? '',
      splits: _decodeSplits(splitList),
      autoPauses: autoPauseList.map((ap) => AutoPauseEvent.fromMap(ap.cast<String, dynamic>())).toList(),
    );
  }

  /// Versão leve, usada em listas/gráficos: **não decodifica a rota**.
  /// [route] e [routeTimes] ficam vazios — quem precisar desenhar o mapa deve
  /// carregar o treino completo (RunRepository.getById).
  factory RunModel.fromSummaryMap(Map<String, dynamic> map) {
    return RunModel(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      pausedDurationSeconds: (map['pausedDurationSeconds'] as num?)?.toInt() ?? 0,
      pace: map['pace'] ?? '0:00',
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      type: map['type'] ?? 'Corrida',
      mood: map['mood'] ?? '',
      splits: _decodeSplits(jsonDecode(map['splits'] ?? '[]')),
    );
  }

  /// `true` quando o objeto carrega a rota (treino completo, não resumo).
  bool get hasRoute => route.any((segment) => segment.isNotEmpty);

  static List<RunSplit> _decodeSplits(List<dynamic> splitList) {
    return splitList.map((s) {
      if (s is Map) return RunSplit.fromMap(s.cast<String, dynamic>());
      if (s is int) return RunSplit(timeSeconds: s, calories: 0);
      return RunSplit(timeSeconds: 0, calories: 0);
    }).toList();
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

  /// Extrai os tempos por ponto, se TODOS os pontos os tiverem.
  /// Formatos antigos (sem 't') retornam vazio.
  static List<List<int>> _decodeRouteTimes(List<dynamic> list) {
    if (list.isEmpty || list.first is! List) return [];

    var allHaveTime = true;
    final times = list.map((segment) {
      return (segment as List).map((p) {
        final t = p is Map ? p['t'] : null;
        if (t is int) return t;
        if (t is num) return t.toInt();
        allHaveTime = false;
        return 0;
      }).toList();
    }).toList();

    return allHaveTime ? times : [];
  }
}
