import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Rota bruta da corrida e seus tempos ativos paralelos.
///
/// A suavização continua sendo responsabilidade apenas do desenho. Esta classe
/// preserva exatamente os pontos aceitos pelo GPS e os formatos legados.
class RunRoute {
  List<List<LatLng>> _points;
  List<List<int>> _times;
  bool _trackPointTimes;

  RunRoute({
    List<List<LatLng>> points = const [],
    List<List<int>> times = const [],
    bool trackPointTimes = true,
  }) : _points = [for (final segment in points) List<LatLng>.of(segment)],
       _times = [for (final segment in times) List<int>.of(segment)],
       _trackPointTimes = trackPointTimes;

  factory RunRoute.empty({bool createSegment = false}) {
    return RunRoute(
      points: createSegment ? [[]] : const [],
      times: createSegment ? [[]] : const [],
    );
  }

  factory RunRoute.fromJson(String? routeJson) {
    if (routeJson == null || routeJson.isEmpty) return RunRoute.empty();

    try {
      final decoded = jsonDecode(routeJson) as List<dynamic>;
      if (decoded.isEmpty) return RunRoute.empty();

      if (decoded.first is List) {
        final points = <List<LatLng>>[
          for (final segment in decoded)
            <LatLng>[
              for (final point in segment as List<dynamic>) _decodePoint(point),
            ],
        ];
        final times = _decodeTimes(decoded);
        return RunRoute(
          points: points,
          times: times ?? const [],
          trackPointTimes: times != null,
        );
      }

      return RunRoute(
        points: [
          [for (final point in decoded) _decodePoint(point)],
        ],
        // O formato plano antigo não registra tempos por ponto.
        trackPointTimes: false,
      );
    } catch (e) {
      debugPrint('RunSession: rota restaurada é inválida: $e');
      return RunRoute.empty();
    }
  }

  List<List<LatLng>> get points => _points;
  List<List<int>> get times => _times;
  bool get trackPointTimes => _trackPointTimes;

  void reset({bool createSegment = false, bool trackPointTimes = true}) {
    _trackPointTimes = trackPointTimes;
    _points = createSegment ? [[]] : [];
    _times = createSegment && trackPointTimes ? [[]] : [];
  }

  void append(LatLng point, int activeTimeSeconds) {
    if (_points.isEmpty) {
      _points.add([]);
      if (_trackPointTimes) _times.add([]);
    }
    _points.last.add(point);
    if (_trackPointTimes) {
      while (_times.length < _points.length) {
        _times.add([]);
      }
      _times.last.add(activeTimeSeconds);
    }
  }

  void startSegment() {
    if (_points.isEmpty || _points.last.isNotEmpty) {
      _points.add([]);
      if (_trackPointTimes) _times.add([]);
    } else if (_trackPointTimes && _times.length < _points.length) {
      _times.add([]);
    }
  }

  String toJson() {
    final segments = <List<Map<String, dynamic>>>[];
    for (var si = 0; si < _points.length; si++) {
      final segment = _points[si];
      final times = si < _times.length ? _times[si] : null;
      segments.add([
        for (var pi = 0; pi < segment.length; pi++)
          if (times != null && pi < times.length)
            {
              'lat': segment[pi].latitude,
              'lng': segment[pi].longitude,
              't': times[pi],
            }
          else
            {'lat': segment[pi].latitude, 'lng': segment[pi].longitude},
      ]);
    }
    return jsonEncode(segments);
  }

  static LatLng _decodePoint(dynamic point) {
    if (point is! Map) throw const FormatException('Ponto de rota inválido');
    final latitude = point['lat'];
    final longitude = point['lng'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException('Coordenadas de rota inválidas');
    }
    return LatLng(latitude.toDouble(), longitude.toDouble());
  }

  static List<List<int>>? _decodeTimes(List<dynamic> decoded) {
    final times = <List<int>>[];
    for (final segment in decoded) {
      final segmentTimes = <int>[];
      for (final point in segment as List<dynamic>) {
        final value = point is Map ? point['t'] : null;
        if (value is! num) return null;
        segmentTimes.add(value.toInt());
      }
      times.add(segmentTimes);
    }
    return times;
  }
}
