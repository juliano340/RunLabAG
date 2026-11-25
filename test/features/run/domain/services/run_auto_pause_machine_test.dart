import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/core/domain/models/auto_pause_event.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:runlabag/features/run/domain/services/run_auto_pause_machine.dart';

Position _position({
  required DateTime timestamp,
  double speed = 0,
  double latitude = -23.55,
  double longitude = -46.63,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );
}

void main() {
  final now = DateTime(2026, 11, 24, 14, 30);

  test('autopausa respeita carência, congela e registra retomada', () {
    final machine = RunAutoPauseMachine();
    final point = const LatLng(-23.55, -46.63);

    for (var i = 0; i < 3; i++) {
      final update = machine.onPosition(
        position: _position(timestamp: now, speed: 0),
        point: point,
        elapsedSeconds: 5,
        now: now,
      );
      expect(update.transition, AutoPauseTransition.none);
    }

    for (var i = 0; i < 3; i++) {
      final update = machine.onPosition(
        position: _position(timestamp: now, speed: 0),
        point: point,
        elapsedSeconds: 20,
        now: now,
      );
      if (i < 2) expect(update.transition, AutoPauseTransition.none);
    }
    expect(machine.active, isTrue);

    machine.tick();
    machine.tick();
    final resumed = machine.onPosition(
      position: _position(timestamp: now, speed: 2),
      point: point,
      elapsedSeconds: 24,
      now: now.add(const Duration(seconds: 2)),
    );

    expect(resumed.transition, AutoPauseTransition.resumed);
    expect(resumed.completedPause?.durationSeconds, 2);
    expect(machine.active, isFalse);
    expect(machine.events, hasLength(1));
    expect(machine.lastResumeSeconds, 24);
  });

  test('desligar autopausa ativa retoma sem inventar evento', () {
    final machine = RunAutoPauseMachine();
    final point = const LatLng(-23.55, -46.63);
    for (var i = 0; i < 3; i++) {
      machine.onPosition(
        position: _position(timestamp: now),
        point: point,
        elapsedSeconds: 20,
        now: now,
      );
    }

    expect(machine.setEnabled(false, 25), isTrue);
    expect(machine.active, isFalse);
    expect(machine.events, isEmpty);
    expect(machine.lastResumeSeconds, 25);
  });

  test('autopausa desligada não acumula ticks de baixa velocidade', () {
    final machine = RunAutoPauseMachine()..setEnabled(false, 0);
    final point = const LatLng(-23.55, -46.63);

    for (var i = 0; i < 5; i++) {
      machine.onPosition(
        position: _position(timestamp: now),
        point: point,
        elapsedSeconds: 20,
        now: now,
      );
    }

    expect(machine.active, isFalse);
  });

  test('restauração preserva eventos e a carência da retomada', () {
    final machine = RunAutoPauseMachine();
    final event = AutoPauseEvent(
      latitude: -23.55,
      longitude: -46.63,
      durationSeconds: 10,
      timestamp: now.toIso8601String(),
    );

    machine.restore(enabled: false, events: [event], resumeSeconds: 300);
    final update = machine.onPosition(
      position: _position(timestamp: now),
      point: const LatLng(-23.55, -46.63),
      elapsedSeconds: 305,
      now: now,
    );

    expect(machine.enabled, isFalse);
    expect(machine.events, [event]);
    expect(machine.lastResumeSeconds, 300);
    expect(update.transition, AutoPauseTransition.none);
    machine.reset(clearEvents: true);
    expect(machine.events, isEmpty);
  });

  test('pausa manual limpa o estado ativo sem registrar evento', () {
    final machine = RunAutoPauseMachine();
    final point = const LatLng(-23.55, -46.63);
    for (var i = 0; i < 3; i++) {
      machine.onPosition(
        position: _position(timestamp: now),
        point: point,
        elapsedSeconds: 20,
        now: now,
      );
    }

    machine.pause();

    expect(machine.active, isFalse);
    expect(machine.anchor, isNull);
    expect(machine.events, isEmpty);
  });
}
