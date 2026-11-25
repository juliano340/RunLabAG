import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/domain/models/auto_pause_event.dart';
import 'gps_filter_service.dart';

enum AutoPauseTransition { none, started, resumed }

class AutoPauseUpdate {
  final AutoPauseTransition transition;
  final AutoPauseEvent? completedPause;

  const AutoPauseUpdate(this.transition, [this.completedPause]);
}

/// Máquina de estados da autopausa, independente de timer, GPS e UI.
class RunAutoPauseMachine {
  bool _enabled = true;
  bool _active = false;
  LatLng? _anchor;
  DateTime? _startedAt;
  int _durationSeconds = 0;
  int _lowSpeedTicks = 0;
  int _lastResumeSeconds = 0;
  final List<AutoPauseEvent> _events = [];

  bool get enabled => _enabled;
  bool get active => _active;
  LatLng? get anchor => _anchor;
  int get durationSeconds => _durationSeconds;
  int get lastResumeSeconds => _lastResumeSeconds;
  List<AutoPauseEvent> get events => _events;

  void restore({
    required bool enabled,
    required List<AutoPauseEvent> events,
    int resumeSeconds = 0,
  }) {
    _enabled = enabled;
    _events
      ..clear()
      ..addAll(events);
    _resetActiveState();
    _lastResumeSeconds = resumeSeconds;
  }

  void reset({bool clearEvents = false}) {
    _resetActiveState();
    _lastResumeSeconds = 0;
    if (clearEvents) _events.clear();
  }

  void pause() => _resetActiveState();

  void resume(int elapsedSeconds) {
    _resetActiveState();
    _lastResumeSeconds = elapsedSeconds;
  }

  void finish() => _resetActiveState();

  /// Desativa a autopausa e retorna se era necessário retomar a corrida.
  bool setEnabled(bool enabled, int elapsedSeconds) {
    _enabled = enabled;
    if (enabled || !_active) return false;
    _resetActiveState();
    _lastResumeSeconds = elapsedSeconds;
    return true;
  }

  void tick() {
    if (_active) _durationSeconds++;
  }

  AutoPauseUpdate onPosition({
    required Position position,
    required LatLng point,
    required int elapsedSeconds,
    required DateTime now,
  }) {
    if (_active) {
      final distanceMeters = _anchor == null
          ? 0.0
          : Geolocator.distanceBetween(
              _anchor!.latitude,
              _anchor!.longitude,
              position.latitude,
              position.longitude,
            );
      if (position.speed <= 1.2 && distanceMeters <= 12) {
        return const AutoPauseUpdate(AutoPauseTransition.none);
      }

      final anchor = _anchor;
      final duration = _durationSeconds;
      final startedAt = _startedAt ?? now;
      final completedPause = anchor != null && duration > 0
          ? AutoPauseEvent(
              latitude: anchor.latitude,
              longitude: anchor.longitude,
              resumeLatitude: point.latitude,
              resumeLongitude: point.longitude,
              durationSeconds: duration,
              timestamp: startedAt.toIso8601String(),
            )
          : null;
      if (completedPause != null) _events.add(completedPause);

      resume(elapsedSeconds);
      return AutoPauseUpdate(AutoPauseTransition.resumed, completedPause);
    }

    if (!_enabled) return const AutoPauseUpdate(AutoPauseTransition.none);

    _lowSpeedTicks = GpsFilterService.updateLowSpeedTicks(
      speed: position.speed,
      currentTicks: _lowSpeedTicks,
      elapsedSeconds: elapsedSeconds,
      lastResumeSeconds: _lastResumeSeconds,
    );
    final shouldPause = GpsFilterService.shouldAutoPause(
      speed: position.speed,
      lowSpeedTicks: _lowSpeedTicks,
      elapsedSeconds: elapsedSeconds,
      lastResumeSeconds: _lastResumeSeconds,
    );
    if (!shouldPause) return const AutoPauseUpdate(AutoPauseTransition.none);

    _active = true;
    _anchor = point;
    _startedAt = now;
    _durationSeconds = 0;
    _lowSpeedTicks = 0;
    return const AutoPauseUpdate(AutoPauseTransition.started);
  }

  void _resetActiveState() {
    _active = false;
    _anchor = null;
    _startedAt = null;
    _durationSeconds = 0;
    _lowSpeedTicks = 0;
  }
}
