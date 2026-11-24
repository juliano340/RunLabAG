import 'dart:ui' show Color;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/services/pace_zone_service.dart';

class _LivePaceChunk {
  final int segmentId;
  final double? paceSecPerKm;
  final double distanceKm;
  final List<LatLng> drawPoints;

  const _LivePaceChunk({
    required this.segmentId,
    required this.paceSecPerKm,
    required this.distanceKm,
    required this.drawPoints,
  });
}

class _BuiltSegment {
  final int sourceSegmentId;
  final PaceZoneSegment segment;

  const _BuiltSegment(this.sourceSegmentId, this.segment);
}

/// Acumulador incremental do traçado colorido durante a corrida.
///
/// Cada ponto novo só calcula a distância do último trecho. A rota completa
/// não é revisitada: chunks concluídos guardam pace, distância e pontos já
/// suavizados. [build] apenas converte esses chunks em segmentos coloridos.
class LivePaceTrace {
  final List<_LivePaceChunk> _chunks = [];
  int _segmentId = 0;
  bool _hasSegment = false;

  LatLng? _lastRawPoint;
  int? _chunkStartTime;
  int _activeTimeSeconds = 0;
  double _chunkDistanceMeters = 0;
  final List<LatLng> _chunkDrawPoints = [];
  double? _smoothedLatitude;
  double? _smoothedLongitude;

  int get completedChunkCount => _chunks.length;

  void reset() {
    _chunks.clear();
    _segmentId = 0;
    _hasSegment = false;
    _lastRawPoint = null;
    _chunkStartTime = null;
    _activeTimeSeconds = 0;
    _chunkDistanceMeters = 0;
    _chunkDrawPoints.clear();
    _smoothedLatitude = null;
    _smoothedLongitude = null;
  }

  void addPoint(
    LatLng point,
    int activeTimeSeconds, {
    bool startsNewSegment = false,
  }) {
    if (startsNewSegment || !_hasSegment) {
      _flushCurrentChunk();
      _segmentId++;
      _hasSegment = true;
      _lastRawPoint = null;
      _smoothedLatitude = null;
      _smoothedLongitude = null;
    }
    _activeTimeSeconds = activeTimeSeconds;

    final drawPoint = _smoothedPoint(point);
    final lastPoint = _lastRawPoint;
    if (lastPoint == null) {
      _beginChunk(activeTimeSeconds, drawPoint);
      _lastRawPoint = point;
      return;
    }

    _chunkDistanceMeters += PaceZoneService.distanceMeters(lastPoint, point);
    _chunkDrawPoints.add(drawPoint);

    if (_chunkDistanceMeters >= PaceZoneService.chunkMinMeters) {
      _chunks.add(_snapshotCurrentChunk());
      _beginChunk(activeTimeSeconds, drawPoint);
    }
    _lastRawPoint = point;
  }

  PaceZoneResult build({required double centerSecPerKm}) {
    final chunks = <_LivePaceChunk>[
      ..._chunks,
      if (_chunkDrawPoints.length >= 2) _snapshotCurrentChunk(),
    ];
    if (chunks.isEmpty) {
      return const PaceZoneResult([], {});
    }

    final distanceByZone = <PaceZone, double>{};
    final built = <_BuiltSegment>[];
    var lastZone = PaceZone.running;
    var lastColor = PaceZone.running.color;

    for (final chunk in chunks) {
      final pace = chunk.paceSecPerKm;
      final zone = pace != null
          ? PaceZoneService.zoneFor(
              paceSecPerKm: pace,
              centerSecPerKm: centerSecPerKm,
            )
          : lastZone;
      final color = pace != null
          ? PaceZoneService.gradientColorFor(
              paceSecPerKm: pace,
              centerSecPerKm: centerSecPerKm,
            )
          : lastColor;

      distanceByZone[zone] = (distanceByZone[zone] ?? 0) + chunk.distanceKm;
      _appendBuiltSegment(
        built,
        sourceSegmentId: chunk.segmentId,
        zone: zone,
        color: color,
        points: chunk.drawPoints,
      );
      lastZone = zone;
      lastColor = color;
    }

    return PaceZoneResult([
      for (final item in built) item.segment,
    ], distanceByZone);
  }

  LatLng _smoothedPoint(LatLng point) {
    final latitude = _smoothedLatitude;
    final longitude = _smoothedLongitude;
    if (latitude == null || longitude == null) {
      _smoothedLatitude = point.latitude;
      _smoothedLongitude = point.longitude;
      return point;
    }

    final nextLatitude =
        latitude + (point.latitude - latitude) * PaceZoneService.smoothingAlpha;
    final nextLongitude =
        longitude +
        (point.longitude - longitude) * PaceZoneService.smoothingAlpha;
    _smoothedLatitude = nextLatitude;
    _smoothedLongitude = nextLongitude;
    return LatLng(nextLatitude, nextLongitude);
  }

  void _beginChunk(int activeTimeSeconds, LatLng drawPoint) {
    _chunkStartTime = activeTimeSeconds;
    _chunkDistanceMeters = 0;
    _chunkDrawPoints
      ..clear()
      ..add(drawPoint);
  }

  _LivePaceChunk _snapshotCurrentChunk() {
    final seconds = (_chunkStartTime == null
        ? 0
        : _activeTimeSeconds - _chunkStartTime!);
    final double? pace;
    if (seconds <= 0) {
      pace = null;
    } else if (_chunkDistanceMeters <= 0) {
      pace = double.infinity;
    } else {
      pace = seconds / (_chunkDistanceMeters / 1000);
    }
    return _LivePaceChunk(
      segmentId: _segmentId,
      paceSecPerKm: pace,
      distanceKm: _chunkDistanceMeters / 1000,
      drawPoints: List<LatLng>.unmodifiable(_chunkDrawPoints),
    );
  }

  void _flushCurrentChunk() {
    if (_chunkDrawPoints.length < 2) return;
    _chunks.add(_snapshotCurrentChunk());
  }

  void _appendBuiltSegment(
    List<_BuiltSegment> output, {
    required int sourceSegmentId,
    required PaceZone zone,
    required Color color,
    required List<LatLng> points,
  }) {
    if (points.length < 2) return;
    if (output.isNotEmpty) {
      final last = output.last;
      final previous = last.segment;
      if (last.sourceSegmentId == sourceSegmentId &&
          previous.color == color &&
          previous.points.isNotEmpty &&
          previous.points.last == points.first) {
        output[output.length - 1] = _BuiltSegment(
          sourceSegmentId,
          PaceZoneSegment(previous.zone, [
            ...previous.points,
            ...points.skip(1),
          ], previous.color),
        );
        return;
      }
    }
    output.add(
      _BuiltSegment(sourceSegmentId, PaceZoneSegment(zone, points, color)),
    );
  }
}
