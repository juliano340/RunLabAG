import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runlabag/core/domain/models/user_profile.dart';
import 'package:runlabag/core/utils/clock.dart';
import 'package:runlabag/features/run/application/run_session_controller.dart';
import 'package:runlabag/features/run/domain/repositories/active_run_store.dart';
import 'package:runlabag/features/run/domain/repositories/location_source.dart';
import 'package:runlabag/features/run/domain/repositories/run_profile_source.dart';
import 'package:runlabag/features/run/domain/repositories/run_session_effects.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTimer implements Timer {
  final void Function(Timer timer) callback;
  bool _active = true;
  int _ticks = 0;

  _FakeTimer(this.callback);

  @override
  bool get isActive => _active;

  @override
  int get tick => _ticks;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _ticks++;
    callback(this);
  }
}

class _FakeClock implements Clock {
  DateTime current;
  _FakeTimer? timer;

  _FakeClock(this.current);

  @override
  DateTime now() => current;

  @override
  Timer periodic(Duration interval, void Function(Timer timer) callback) {
    timer = _FakeTimer(callback);
    return timer!;
  }

  void tick([int seconds = 1]) {
    for (var i = 0; i < seconds; i++) {
      current = current.add(const Duration(seconds: 1));
      timer?.fire();
    }
  }
}

class _FakeLocationSource implements LocationSource {
  bool permissionGranted = true;
  Position? currentPosition;
  Completer<Position>? nextCurrentLocation;
  final StreamController<Position> _positions =
      StreamController<Position>.broadcast();
  int activeListeners = 0;
  int currentLocationCalls = 0;

  _FakeLocationSource(DateTime now) {
    currentPosition = _position(now, -23.55, -46.63);
  }

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<Position> getCurrentLocation() {
    currentLocationCalls++;
    final next = nextCurrentLocation;
    if (next != null) return next.future;
    return Future.value(currentPosition!);
  }

  @override
  Stream<Position> getLocationStream() {
    return Stream<Position>.multi((controller) {
      activeListeners++;
      final subscription = _positions.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () async {
        activeListeners--;
        await subscription.cancel();
      };
    });
  }

  void emit(Position position) => _positions.add(position);

  Future<void> close() => _positions.close();
}

class _FakeActiveRunStore implements ActiveRunStore {
  final List<Map<String, dynamic>> metaWrites = [];
  final List<String> routeWrites = [];
  Completer<void>? metaGate;
  int clearCount = 0;

  @override
  Future<void> saveMeta(Map<String, dynamic> data) async {
    final gate = metaGate;
    if (gate != null) await gate.future;
    metaWrites.add(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> saveRoute(String routeJson) async {
    routeWrites.add(routeJson);
  }

  @override
  Future<void> clear() async {
    clearCount++;
  }
}

class _FakeProfileSource implements RunProfileSource {
  @override
  Future<UserProfile?> load() async => UserProfile(
    name: 'Teste',
    age: 30,
    weight: 70,
    height: 170,
    weeklyGoal: 20,
    monthlyGoal: 80,
    kmNotificationsEnabled: false,
  );
}

class _FakeEffects implements RunSessionEffects {
  final List<bool> wakeLockChanges = [];
  final List<String> startedRuns = [];
  int autoPauseStarts = 0;
  int autoPauseResumes = 0;

  @override
  Future<void> setWakeLock(bool enabled) async {
    wakeLockChanges.add(enabled);
  }

  @override
  Future<void> logRunStarted(String runType) async {
    startedRuns.add(runType);
  }

  @override
  Future<void> notifyKm(int km, String pace) async {}

  @override
  Future<void> autoPauseStarted() async {
    autoPauseStarts++;
  }

  @override
  Future<void> autoPauseResumed() async {
    autoPauseResumes++;
  }

  @override
  Future<void> pacingStatusChanged() async {}
}

Position _position(
  DateTime timestamp,
  double latitude,
  double longitude, {
  double accuracy = 5,
  double speed = 2,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeClock clock;
  late _FakeLocationSource locations;
  late _FakeActiveRunStore store;
  late _FakeEffects effects;
  late RunSessionController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = _FakeClock(DateTime(2026, 11, 24, 14, 30));
    locations = _FakeLocationSource(clock.current);
    store = _FakeActiveRunStore();
    effects = _FakeEffects();
    controller = RunSessionController(
      locations: locations,
      clock: clock,
      activeRunStore: store,
      profileSource: _FakeProfileSource(),
      effects: effects,
    );
  });

  tearDown(() async {
    controller.dispose();
    await locations.close();
  });

  Future<void> startController() async {
    await controller.initialize();
    await controller.start(warmUpGps: false);
    await _flush();
  }

  test('início manual espera o aquecimento de GPS', () async {
    await controller.initialize();
    final fix = Completer<Position>();
    locations.nextCurrentLocation = fix;

    final starting = controller.start(warmUpGps: true);
    await _flush();
    expect(controller.isStarting, isTrue);
    expect(controller.isRunning, isFalse);

    fix.complete(locations.currentPosition!);
    expect(await starting, isTrue);
    expect(controller.isRunning, isTrue);
    expect(controller.isStarting, isFalse);
  });

  test('início expresso não espera o primeiro fix', () async {
    final fix = Completer<Position>();
    locations.nextCurrentLocation = fix;

    final initializing = controller.initialize(autoStart: true);
    await _flush();
    expect(controller.isRunning, isTrue);
    expect(controller.elapsedSeconds, 0);

    fix.complete(locations.currentPosition!);
    await initializing;
  });

  test('start duplo não zera a corrida em andamento', () async {
    await startController();
    clock.tick(3);
    final routeBefore = controller.routePoints.length;

    expect(await controller.start(warmUpGps: false), isFalse);
    expect(controller.elapsedSeconds, 3);
    expect(controller.routePoints.length, routeBefore);
  });

  test('tick atualiza apenas o canal do painel', () async {
    await startController();
    var ticks = 0;
    var stateChanges = 0;
    var routeChanges = 0;
    controller.uiTick.addListener(() => ticks++);
    controller.stateChanges.addListener(() => stateChanges++);
    controller.routeChanges.addListener(() => routeChanges++);

    clock.tick(5);

    expect(controller.elapsedSeconds, 5);
    expect(ticks, 5);
    expect(stateChanges, 0);
    expect(routeChanges, 0);
    expect(store.metaWrites, isNotEmpty);
  });

  test(
    'ponto aceito atualiza a rota sem reconstruir estado estrutural',
    () async {
      await startController();
      var stateChanges = 0;
      var routeChanges = 0;
      controller.stateChanges.addListener(() => stateChanges++);
      controller.routeChanges.addListener(() => routeChanges++);

      locations.emit(_position(clock.current, -23.5501, -46.6301));
      await _flush();

      expect(routeChanges, 1);
      expect(stateChanges, 0);
      expect(controller.routePoints.single, hasLength(1));
      expect(controller.routePointTimes.single, hasLength(1));
    },
  );

  test('ponto impreciso é ignorado sem notificar rota', () async {
    await startController();
    var routeChanges = 0;
    controller.routeChanges.addListener(() => routeChanges++);

    locations.emit(_position(clock.current, -23.5501, -46.6301, accuracy: 50));
    await _flush();

    expect(routeChanges, 0);
    expect(controller.routePoints.single, isEmpty);
  });

  test('auto-pause congela tempo ativo e retoma por velocidade', () async {
    await startController();
    clock.tick(11);

    for (var i = 0; i < 3; i++) {
      locations.emit(_position(clock.current, -23.55, -46.63, speed: 0));
      await _flush();
    }
    expect(controller.isAutoPaused, isTrue);

    clock.tick(3);
    expect(controller.elapsedSeconds, 11);
    expect(controller.pausedSeconds, 3);
    expect(effects.autoPauseStarts, 1);

    locations.emit(_position(clock.current, -23.55, -46.63, speed: 2));
    await _flush();
    expect(controller.isAutoPaused, isFalse);
    expect(controller.autoPauses, hasLength(1));
    expect(effects.autoPauseResumes, 1);

    locations.emit(_position(clock.current, -23.5501, -46.6301, speed: 2));
    await _flush();
    expect(
      controller.distanceKm,
      0,
      reason: 'primeiro ponto após retomada não soma distância',
    );
  });

  test('pause e resume mantêm uma única subscription GPS', () async {
    await startController();
    expect(locations.activeListeners, 1);

    controller.pause();
    await _flush();
    expect(locations.activeListeners, 0);

    controller.resume();
    await _flush();
    expect(locations.activeListeners, 1);

    controller.pause();
    controller.resume();
    await _flush();
    expect(locations.activeListeners, 1);
  });

  test('restore legado sem tempos continua aceitando pontos novos', () async {
    final restored = {
      'distanceKm': 0.5,
      'secondsElapsed': 300,
      'pausedDurationSeconds': 0,
      'lastKmNotified': 0,
      'isPaused': 0,
      'finished': 0,
      'startTime': clock.current
          .subtract(const Duration(minutes: 5))
          .toIso8601String(),
      'route': jsonEncode([
        {'lat': -23.55, 'lng': -46.63},
      ]),
    };

    await controller.initialize(restoredState: restored);
    await _flush();
    expect(controller.routePointTimes, isEmpty);

    locations.emit(_position(clock.current, -23.5501, -46.6301));
    await _flush();

    expect(controller.routePoints, hasLength(2));
    expect(controller.routePointTimes, isEmpty);
    expect(controller.distanceKm, 0.5);
  });

  test(
    'restore de rota vazia cria tempos paralelos no primeiro ponto',
    () async {
      await controller.initialize(
        restoredState: {
          'distanceKm': 0.0,
          'secondsElapsed': 10,
          'isPaused': 0,
          'finished': 0,
          'route': '[]',
        },
      );
      await _flush();

      locations.emit(_position(clock.current, -23.55, -46.63));
      await _flush();

      expect(controller.routePoints.single, hasLength(1));
      expect(controller.routePointTimes.single, hasLength(1));
    },
  );

  test(
    'snapshot final espera escritas antigas e preserva finished = 1',
    () async {
      await startController();
      final gate = Completer<void>();
      store.metaGate = gate;

      // A próxima persistência periódica fica retida na fila.
      clock.tick(5);
      final finishing = controller.finish(forceSave: true);
      await _flush();
      expect(store.metaWrites.last['finished'], 0);

      gate.complete();
      await finishing;

      expect(store.metaWrites.last['finished'], 1);
      expect(store.metaWrites.last['isPaused'], 1);
      expect(controller.isFinished, isTrue);
      expect(store.clearCount, 0);
    },
  );

  test('discard limpa o treino ativo', () async {
    await startController();
    await controller.discardActiveRun();
    expect(store.clearCount, 1);
  });

  test('sem permissão o motor não inicia', () async {
    locations.permissionGranted = false;
    await controller.initialize(autoStart: true);
    expect(controller.hasPermissions, isFalse);
    expect(controller.isRunning, isFalse);
    expect(locations.activeListeners, 0);
  });
}
