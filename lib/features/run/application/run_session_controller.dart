import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/domain/models/auto_pause_event.dart';
import '../../../core/domain/models/run_split.dart';
import '../../../core/domain/models/user_profile.dart';
import '../../../core/services/achievement_service.dart';
import '../../../core/services/pacing_service.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/time_utils.dart';
import '../data/repositories/database_active_run_store.dart';
import '../data/repositories/database_run_profile_source.dart';
import '../domain/models/run_route.dart';
import '../domain/models/run_session_event.dart';
import '../domain/models/run_session_snapshot.dart';
import '../domain/repositories/active_run_store.dart';
import '../domain/repositories/location_source.dart';
import '../domain/repositories/run_profile_source.dart';
import '../domain/repositories/run_session_effects.dart';
import '../domain/services/gps_filter_service.dart';
import '../domain/services/run_auto_pause_machine.dart';
import '../domain/services/run_finalization_service.dart';
import '../domain/services/run_metrics_service.dart';
import '../domain/services/run_split_tracker.dart';
import '../domain/services/smoothed_pace_tracker.dart';
import 'active_run_persistence.dart';
import 'run_persistence_coordinator.dart';
import 'system_run_session_effects.dart';

/// Motor testável da corrida. A tela apenas desenha estado e reage a eventos.
///
/// Existem três canais independentes de atualização:
/// - [uiTick]: relógio de 1 s, consumido só pelo painel;
/// - [stateChanges]: permissão, pausa, meta e demais estados estruturais;
/// - [routeChanges]: pontos aceitos, distância, splits e rota.
class RunSessionController {
  static const String _autoPauseEnabledKey = 'auto_pause_enabled';

  final LocationSource _locations;
  final Clock _clock;
  final RunProfileSource _profileSource;
  final RunSessionEffects _effects;
  final RunPersistenceCoordinator? _persistenceCoordinator;
  final ActiveRunPersistence _persistence;
  final RunAutoPauseMachine _autoPause = RunAutoPauseMachine();
  final RunSplitTracker _splitTracker = RunSplitTracker();
  final SmoothedPaceTracker _paceTracker = SmoothedPaceTracker();

  final StreamController<RunSessionEvent> _events =
      StreamController<RunSessionEvent>.broadcast();
  final ValueNotifier<int> _uiTick = ValueNotifier(0);
  final ValueNotifier<int> _stateChanges = ValueNotifier(0);
  final ValueNotifier<int> _routeChanges = ValueNotifier(0);

  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  RunRoute _route = RunRoute.empty();

  bool _initialized = false;
  bool _disposed = false;
  bool _hasRestoredState = false;
  bool _hasPermissions = false;
  bool _isStartingRun = false;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isFinished = false;
  bool _isFirstPointAfterResume = false;

  double _distanceKm = 0;
  double? _distanceGoal;
  int? _targetTimeSeconds;
  PacingService? _pacingService;
  PacingFeedback? _pacingFeedback;
  int _secondsElapsed = 0;
  int _pausedSecondsElapsed = 0;
  DateTime? _runStartTime;
  UserProfile? _userProfile;

  RunSessionController({
    required LocationSource locations,
    required Clock clock,
    ActiveRunStore? activeRunStore,
    RunProfileSource? profileSource,
    RunSessionEffects? effects,
    RunPersistenceCoordinator? persistenceCoordinator,
  }) : _locations = locations,
       _clock = clock,
       _profileSource = profileSource ?? DatabaseRunProfileSource(),
       _effects = effects ?? const SystemRunSessionEffects(),
       _persistenceCoordinator = persistenceCoordinator,
       _persistence = ActiveRunPersistence(
         activeRunStore ?? DatabaseActiveRunStore(),
         clock,
       );

  Stream<RunSessionEvent> get events => _events.stream;
  ValueListenable<int> get uiTick => _uiTick;
  ValueListenable<int> get stateChanges => _stateChanges;
  ValueListenable<int> get routeChanges => _routeChanges;

  bool get hasPermissions => _hasPermissions;
  bool get isStarting => _isStartingRun;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get isFinished => _isFinished;
  bool get isAutoPaused => _autoPause.active;
  bool get autoPauseEnabled => _autoPause.enabled;
  bool get canExit => !_isRunning && !_isFinished;
  double get distanceKm => _distanceKm;
  double? get distanceGoal => _distanceGoal;
  int get elapsedSeconds => _secondsElapsed;
  int get pausedSeconds => _pausedSecondsElapsed;
  int get lastKmNotified => _splitTracker.lastKmNotified;
  PacingFeedback? get pacingFeedback => _pacingFeedback;
  LatLng? get autoPauseAnchor => _autoPause.anchor;
  DateTime? get runStartTime => _runStartTime;
  List<RunSplit> get splits => _splitTracker.splits;
  List<AutoPauseEvent> get autoPauses => _autoPause.events;
  List<List<LatLng>> get routePoints => _route.points;
  List<List<int>> get routePointTimes => _route.times;

  String get formattedTime => TimeUtils.formatDuration(_secondsElapsed);

  String get pace {
    if (_isRunning && !_isFinished) return _paceTracker.value;
    return RunMetricsService.calculatePace(_secondsElapsed, _distanceKm);
  }

  int get calories => RunMetricsService.calculateCalories(
    _distanceKm,
    _userProfile?.weight ?? 70,
  );

  String get eta => RunMetricsService.calculateETA(
    currentDistanceKm: _distanceKm,
    goalDistanceKm: _distanceGoal ?? 0,
    elapsedSeconds: _secondsElapsed,
  );

  bool get isShortRun => RunFinalizationService.isShortRun(
    distanceKm: _distanceKm,
    elapsedSeconds: _secondsElapsed,
  );

  /// Carrega preferências/perfil, resolve permissão e restaura ou inicia.
  Future<void> initialize({
    Map<String, dynamic>? restoredState,
    bool autoStart = false,
  }) async {
    if (_initialized) return;
    _initialized = true;

    var autoPauseEnabled = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      autoPauseEnabled = prefs.getBool(_autoPauseEnabledKey) ?? true;
    } catch (e) {
      debugPrint('RunSession: não foi possível ler auto-pause: $e');
    }

    if (restoredState != null) {
      _hasRestoredState = true;
      final snapshot = _restoreState(restoredState);
      _autoPause.restore(
        enabled: autoPauseEnabled,
        events: snapshot.autoPauses,
        resumeSeconds: snapshot.secondsElapsed,
      );
    } else {
      _autoPause.restore(enabled: autoPauseEnabled, events: const []);
    }
    _notifyState();
    unawaited(_loadProfile());

    try {
      _hasPermissions = await _locations.requestPermission();
    } catch (e) {
      debugPrint('RunSession: falha ao pedir permissão: $e');
      _hasPermissions = false;
    }
    _notifyState();

    if (!_hasPermissions) {
      _emit(
        RunSessionError('Permissão de localização necessária para iniciar.'),
      );
      return;
    }

    if (autoStart && restoredState == null) {
      await start(warmUpGps: false);
    } else if (_isRunning && !_isPaused && !_isFinished) {
      _startRuntime();
    }

    try {
      final position = await _locations.getCurrentLocation();
      final point = LatLng(position.latitude, position.longitude);

      // Só uma corrida nova ainda não iniciada recebe a semente inicial.
      // Restaurar ou finalizar nunca pode sobrescrever a rota persistida.
      if (!_hasRestoredState && !_isRunning && !_isFinished) {
        _route.reset(createSegment: true);
        _route.append(point, _secondsElapsed);
        _notifyRoute();
      }
      _emit(RunLocationReady(point));
    } catch (e) {
      debugPrint('RunSession: falha ao obter posição inicial: $e');
      _emit(RunSessionError('Não foi possível obter a localização inicial.'));
    }
  }

  Future<bool> start({bool warmUpGps = true}) async {
    if (_isStartingRun || _isRunning || _disposed) return false;
    if (!_hasPermissions) {
      _emit(
        RunSessionError('Permissão de localização necessária para iniciar.'),
      );
      return false;
    }

    _isStartingRun = true;
    _notifyState();
    _stopRuntime();
    _runStartTime = _clock.now();

    if (warmUpGps) {
      try {
        await _locations.getCurrentLocation();
      } catch (e) {
        debugPrint('RunSession: aquecimento de GPS falhou: $e');
      }
    }
    if (_disposed) return false;

    _distanceKm = 0;
    _secondsElapsed = 0;
    _pausedSecondsElapsed = 0;
    _splitTracker.reset();
    _autoPause.reset(clearEvents: true);
    _route.reset(createSegment: true);
    _paceTracker.reset();
    _isRunning = true;
    _isPaused = false;
    _isFinished = false;
    _isFirstPointAfterResume = true;
    _isStartingRun = false;

    _notifyState();
    _notifyRoute();
    _startRuntime();
    _persistState(forceRoute: true);
    _triggerEffect(
      () => _effects.logRunStarted(
        _distanceGoal != null ? 'meta_distancia' : 'livre',
      ),
    );
    return true;
  }

  void pause() {
    if (!_isRunning || _isPaused || _isFinished) return;
    _isPaused = true;
    _autoPause.pause();
    _stopRuntime();
    _notifyState();
    _persistState(forceRoute: true);
  }

  void resume() {
    if (!_isRunning || _isFinished || (!_isPaused && !_autoPause.active)) {
      return;
    }
    _isPaused = false;
    _autoPause.resume(_secondsElapsed);
    _isFirstPointAfterResume = true;
    _route.startSegment();
    _notifyState();
    _notifyRoute();
    _startRuntime();
    _persistState(forceRoute: true);
  }

  Future<void> setAutoPauseEnabled(bool enabled) async {
    final resumed = _autoPause.setEnabled(enabled, _secondsElapsed);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoPauseEnabledKey, enabled);
    } catch (e) {
      debugPrint('RunSession: não foi possível salvar auto-pause: $e');
    }

    if (resumed) {
      _isFirstPointAfterResume = true;
      _route.startSegment();
      _notifyState();
      _notifyRoute();
      _triggerEffect(_effects.autoPauseResumed);
      _emit(RunAutoPauseResumed());
    } else {
      _notifyState();
    }
  }

  void setGoal({
    required double? distanceKm,
    required int? targetTimeSeconds,
    required PacingService? pacingService,
  }) {
    _distanceGoal = distanceKm;
    _targetTimeSeconds = targetTimeSeconds;
    _pacingService = pacingService;
    _pacingFeedback = null;
    _notifyState();
  }

  /// Para o runtime e retorna true quando a corrida curta exige confirmação.
  /// Com [forceSave], marca como finalizada e preserva o snapshot para save.
  Future<bool> finish({bool forceSave = false}) async {
    if (_isFinished) return false;
    _stopRuntime();

    final shortRun = isShortRun;
    if (shortRun && !forceSave) return true;

    if (!shortRun) {
      _splitTracker.finalize(
        distanceKm: _distanceKm,
        elapsedSeconds: _secondsElapsed,
        totalCalories: calories,
      );
    }

    _isRunning = false;
    _isFinished = true;
    _isPaused = true;
    _autoPause.finish();
    _notifyState();
    _notifyRoute();
    await _persistFinished();
    return false;
  }

  Future<void> discardActiveRun() async {
    _stopRuntime();
    await _persistence.clear();
  }

  /// Sai/minimiza sem perder o snapshot: para timers e força a persistência.
  Future<void> suspendAndPersist() async {
    _stopRuntime();
    await flushPersistence();
  }

  Future<void> flushPersistence() => _persistence.flush();

  Future<RunPersistenceResult> saveCompletedRun({
    required String type,
    required String mood,
  }) {
    final coordinator = _persistenceCoordinator ?? RunPersistenceCoordinator();
    return coordinator.saveCompletedRun(
      startTime: _runStartTime,
      distanceKm: _distanceKm,
      durationSeconds: _secondsElapsed,
      pausedDurationSeconds: _pausedSecondsElapsed,
      pace: pace,
      calories: calories,
      route: [
        for (final segment in _route.points) List<LatLng>.unmodifiable(segment),
      ],
      routeTimes: _route.trackPointTimes
          ? [
              for (final segment in _route.times)
                List<int>.unmodifiable(segment),
            ]
          : const [],
      type: type,
      mood: mood,
      splits: List<RunSplit>.unmodifiable(_splitTracker.splits),
      autoPauses: List<AutoPauseEvent>.unmodifiable(_autoPause.events),
    );
  }

  void _startRuntime() {
    if (_disposed || _isPaused || _isFinished) return;
    _timer?.cancel();
    _positionStream?.cancel();
    _timer = _clock.periodic(const Duration(seconds: 1), _onTick);
    _triggerEffect(() => _effects.setWakeLock(true));

    try {
      _positionStream = _locations.getLocationStream().listen(
        _onPosition,
        onError: (Object error, StackTrace stack) {
          debugPrint('RunSession: stream de localização falhou: $error');
          _emit(RunSessionError('Falha no rastreamento GPS.'));
        },
      );
    } catch (e) {
      debugPrint('RunSession: não foi possível abrir o GPS: $e');
      _emit(RunSessionError('Não foi possível iniciar o rastreamento GPS.'));
    }
  }

  void _stopRuntime() {
    _timer?.cancel();
    _timer = null;
    _positionStream?.cancel();
    _positionStream = null;
    _triggerEffect(() => _effects.setWakeLock(false));
  }

  void _onTick(Timer timer) {
    if (_disposed || !_isRunning || _isFinished) return;

    if (_isPaused || _autoPause.active) {
      _pausedSecondsElapsed++;
      if (_autoPause.active) _autoPause.tick();
      _uiTick.value++;
      if (_pausedSecondsElapsed % 5 == 0) _persistState();
      return;
    }

    _secondsElapsed++;
    if (_pacingService != null) {
      final oldStatus = _pacingFeedback?.status;
      _pacingFeedback = _pacingService!.getUpdate(_distanceKm, _secondsElapsed);
      if (_pacingFeedback != null &&
          _pacingFeedback!.status != oldStatus &&
          _pacingFeedback!.status != PacingStatus.none) {
        _triggerEffect(_effects.pacingStatusChanged);
      }
    }
    _uiTick.value++;
    if (_secondsElapsed % 5 == 0) _persistState();
  }

  void _onPosition(Position position) {
    if (_disposed || _isPaused || _isFinished || !_isRunning) return;
    final newPoint = LatLng(position.latitude, position.longitude);

    final autoPause = _autoPause.onPosition(
      position: position,
      point: newPoint,
      elapsedSeconds: _secondsElapsed,
      now: _clock.now(),
    );
    if (autoPause.transition == AutoPauseTransition.started) {
      _notifyState();
      _triggerEffect(_effects.autoPauseStarted);
      _emit(RunAutoPauseStarted());
      return;
    }
    if (autoPause.transition == AutoPauseTransition.resumed) {
      _isFirstPointAfterResume = true;
      _route.startSegment();
      _notifyState();
      _notifyRoute();
      _triggerEffect(_effects.autoPauseResumed);
      _emit(RunAutoPauseResumed());
      return;
    }

    if (GpsFilterService.shouldRejectByAccuracy(
      pointAccuracy: position.accuracy,
      elapsedSeconds: _secondsElapsed,
    )) {
      debugPrint(
        'GPS impreciso ignorado: ${position.accuracy}m '
        '(Max: ${GpsFilterService.maxAllowedAccuracy(_secondsElapsed)})',
      );
      return;
    }

    if (_route.points.isNotEmpty && _route.points.last.isNotEmpty) {
      final lastPoint = _route.points.last.last;
      final distanceMeters = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );

      if (_isFirstPointAfterResume) {
        _route.startSegment();
        _route.append(newPoint, _secondsElapsed);
        _paceTracker.reset(position, false);
        _isFirstPointAfterResume = false;
        _notifyRoute();
        _emit(RunPositionUpdated(newPoint));
        return;
      }

      final lastPosition = _paceTracker.lastPosition;
      if (lastPosition != null) {
        final timeDiff = position.timestamp
            .difference(lastPosition.timestamp)
            .inSeconds;
        if (GpsFilterService.shouldRejectBySpeedJump(
          distanceMeters: distanceMeters,
          timeDiffSeconds: timeDiff,
        )) {
          final speed = timeDiff > 0
              ? distanceMeters / timeDiff
              : double.infinity;
          debugPrint('Salto de GPS detectado: ${speed.toStringAsFixed(1)} m/s');
          return;
        }
      }

      if (GpsFilterService.isSignificantDisplacement(
        distanceMeters: distanceMeters,
        estimatedSpeed: position.speed,
      )) {
        _distanceKm += distanceMeters / 1000;
        _paceTracker.add(position);
        _route.append(newPoint, _secondsElapsed);
        _notifyRoute();
        _emit(RunPositionUpdated(newPoint));
        _handleKilometerCrossing();
      }
      return;
    }

    _route.append(newPoint, _secondsElapsed);
    _paceTracker.reset(position, false);
    _isFirstPointAfterResume = false;
    _notifyRoute();
    _emit(RunPositionUpdated(newPoint));
  }

  void _handleKilometerCrossing() {
    final split = _splitTracker.recordDistance(
      distanceKm: _distanceKm,
      elapsedSeconds: _secondsElapsed,
      totalCalories: calories,
    );
    if (split == null) return;

    final currentKm = _splitTracker.lastKmNotified;
    _persistState(forceRoute: true);

    if (_userProfile?.kmNotificationsEnabled == true) {
      final currentPace = _paceTracker.value.isNotEmpty
          ? _paceTracker.value
          : '--:--';
      _triggerEffect(() => _effects.notifyKm(currentKm, currentPace));
    }
    _emit(
      RunKilometerReached(
        currentKm,
        AchievementService.getIncentiveMessage(currentKm),
      ),
    );
  }

  RunSessionSnapshot _restoreState(Map<String, dynamic> state) {
    final snapshot = RunSessionSnapshot.fromStored(state);
    _distanceKm = snapshot.distanceKm;
    _secondsElapsed = snapshot.secondsElapsed;
    _pausedSecondsElapsed = snapshot.pausedDurationSeconds;
    _distanceGoal = snapshot.distanceGoal;
    _targetTimeSeconds = snapshot.targetTimeSeconds;
    _runStartTime = snapshot.startTime;
    if (_distanceGoal != null && _targetTimeSeconds != null) {
      _pacingService = PacingService(
        targetDistanceKm: _distanceGoal,
        targetTimeSeconds: _targetTimeSeconds,
      );
    }
    _splitTracker.restore(
      splits: snapshot.splits,
      lastKmNotified: snapshot.lastKmNotified,
    );
    _isPaused = snapshot.isPaused;
    _isFinished = snapshot.isFinished;
    _isRunning = !_isFinished;
    _isFirstPointAfterResume = true;
    _paceTracker.reset();
    _route = RunRoute.fromJson(state['route'] as String?);
    return snapshot;
  }

  Future<void> _loadProfile() async {
    try {
      _userProfile = await _profileSource.load();
    } catch (e) {
      debugPrint('RunSession: não foi possível carregar o perfil: $e');
    }
  }

  RunSessionSnapshot _snapshot({required bool finished}) {
    return RunSessionSnapshot(
      distanceKm: _distanceKm,
      secondsElapsed: _secondsElapsed,
      pausedDurationSeconds: _pausedSecondsElapsed,
      lastKmNotified: _splitTracker.lastKmNotified,
      distanceGoal: _distanceGoal,
      targetTimeSeconds: _targetTimeSeconds,
      startTime: _runStartTime,
      isPaused: _isPaused,
      isFinished: finished,
      splits: _splitTracker.splits,
      autoPauses: _autoPause.events,
    );
  }

  void _persistState({bool forceRoute = false}) {
    if (!_isRunning || _isFinished) return;
    _persistence.saveState(
      meta: _snapshot(
        finished: false,
      ).toMeta(finished: false, fallbackStartTime: _clock.now()),
      routeJson: _route.toJson(),
      forceRoute: forceRoute,
    );
  }

  Future<void> _persistFinished() {
    return _persistence.finish(
      meta: _snapshot(
        finished: true,
      ).toMeta(finished: true, fallbackStartTime: _clock.now()),
      routeJson: _route.toJson(),
    );
  }

  void _emit(RunSessionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _notifyState() {
    if (!_disposed) _stateChanges.value++;
  }

  void _notifyRoute() {
    if (!_disposed) _routeChanges.value++;
  }

  void _triggerEffect(Future<void> Function() effect) {
    unawaited(_safeEffect(effect));
  }

  Future<void> _safeEffect(Future<void> Function() effect) async {
    try {
      await effect();
    } catch (e) {
      debugPrint('RunSession: efeito de sistema falhou: $e');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopRuntime();
    _events.close();
    _uiTick.dispose();
    _stateChanges.dispose();
    _routeChanges.dispose();
  }
}
