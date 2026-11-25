import 'package:geolocator/geolocator.dart';

/// Pace exibido durante a corrida, calculado a partir de uma janela de pontos.
/// Não altera distância, métricas, splits ou recordes.
class SmoothedPaceTracker {
  final List<Position> _buffer = [];
  String _value = '0:00';

  String get value => _value;
  Position? get lastPosition => _buffer.isEmpty ? null : _buffer.last;

  void reset([Position? first, bool resetValue = true]) {
    _buffer.clear();
    if (resetValue) _value = '0:00';
    if (first != null) _buffer.add(first);
  }

  void add(Position position) {
    _buffer.add(position);
    if (_buffer.length > 30) _buffer.removeAt(0);
    _recalculate();
  }

  void _recalculate() {
    if (_buffer.length < 5) {
      _value = '0:00';
      return;
    }

    final first = _buffer.first;
    final last = _buffer.last;
    var totalDistanceMeters = 0.0;
    for (var i = 0; i < _buffer.length - 1; i++) {
      totalDistanceMeters += Geolocator.distanceBetween(
        _buffer[i].latitude,
        _buffer[i].longitude,
        _buffer[i + 1].latitude,
        _buffer[i + 1].longitude,
      );
    }
    final timeSeconds = last.timestamp.difference(first.timestamp).inSeconds;
    if (timeSeconds > 0 && totalDistanceMeters > 10) {
      final paceMinutes = (timeSeconds / 60) / (totalDistanceMeters / 1000);
      if (paceMinutes > 0 && paceMinutes < 35) {
        final minutes = paceMinutes.toInt();
        final seconds = ((paceMinutes - minutes) * 60).toInt();
        _value = '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
    } else if (timeSeconds > 10) {
      _value = '0:00';
    }
  }
}
