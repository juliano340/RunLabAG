import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/domain/models/auto_pause_event.dart';
import '../../../core/domain/models/run_split.dart';
import '../../../core/domain/models/user_profile.dart';
import '../../../core/services/achievement_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/pacing_service.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/time_utils.dart';
import '../data/repositories/database_active_run_store.dart';
import '../data/repositories/database_run_profile_source.dart';
import '../domain/models/run_session_event.dart';
import '../domain/repositories/active_run_store.dart';
import '../domain/repositories/location_source.dart';
import '../domain/repositories/run_profile_source.dart';
import '../domain/repositories/run_session_effects.dart';
import '../domain/services/gps_filter_service.dart';
import '../domain/services/run_finalization_service.dart';
import '../domain/services/run_metrics_service.dart';
import 'run_persistence_coordinator.dart';
import 'system_run_session_effects.dart';

/// Motor testável da corrida. A tela apenas desenha estado e reage a eventos.
///
/// Existem três canais independentes de atualização:
/// - [uiTick]: relógio de 1 s, consumido só pelo painel;
/// - [stateChanges]: permissão, pausa, meta e demais estados estruturais;
/// - [routeChanges]: pontos aceitos, distância, splits e rota.
class RunSessionController {
  static const Duration _routePersistInterval = Duration(seconds: 30);
  static const String _autoPauseEnabledKey = 'auto_pause_enabled';

  final LocationSource _locations;
  final Clock _clock;
  final ActiveRunStore _activeRunStore;
  final RunProfileSource _profileSource;
  final RunSessionEffects _effects;
  final RunPersistenceCoordinator? _persistenceCoordinator;

  final StreamController<RunSessionEvent> _events =
      StreamController<RunSessionEvent>.broadcast();
  final ValueNotifier<int> _uiTick = ValueNotifier(0);
  final ValueNotifier<int> _stateChanges = ValueNotifier(0);
  final ValueNotifier<int> _routeChanges = ValueNotifier(0);

  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  Future<void> _metaWrites = Future<void>.value();
  Future<void> _routeWrites = Future<void>.value();
  DateTime? _lastRoutePersistAt;

  bool _initialized = false;
  bool _disposed = false;
  bool _hasRestoredState = false;
  bool _hasPermissions = false;
  bool _isStartingRun = false;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isFinished = false;
  bool _autoPauseEnabled = true;
  bool _isAutoPaused = false;
  bool _trackPointTimes = true;
  LatLng? _autoPauseAnchor;
  int _currentAutoPauseDurationSeconds = 0;
  DateTime? _autoPauseStartTime;
  int _lowSpeedTicks = 0;

  double _distanceKm = 0;
  double? _distanceGoal;
  int? _targetTimeSeconds;
  PacingService? _pacingService;
  PacingFeedback? _pacingFeedback;
  int _secondsElapsed = 0;
  int _pausedSecondsElapsed = 0;
  int _lastResumeSeconds = 0;
  int _lastKmNotified = 0;
  List<RunSplit> _splits = [];
  int _lastSplitTimeSeconds = 0;
  int _lastSplitCalories = 0;
  List<List<LatLng>> _routePoints = [];
  List<List<int>> _routePointTimes = [];
  List<AutoPauseEvent> _autoPauses = [];
  List<Position> _paceBuffer = [];
  String _currentSmoothedPace = '0:00';
  bool _isFirstPointAfterResume = false;
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
       _activeRunStore =
           activeRunStore ?? DatabaseActiveRunStore(DatabaseService()),
       _profileSource =
           profileSource ?? DatabaseRunProfileSource(DatabaseService()),
       _effects = effects ?? const SystemRunSessionEffects(),
       _persistenceCoordinator = persistenceCoordinator;

  Stream<RunSessionEvent> get events => _events.stream;
  ValueListenable<int> get uiTick => _uiTick;
  ValueListenable<int> get stateChanges => _stateChanges;
  ValueListenable<int> get routeChanges => _routeChanges;

  bool get hasPermissions => _hasPermissions;
  bool get isStarting => _isStartingRun;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  bool get isFinished => _isFinished;
  bool get isAutoPaused => _isAutoPaused;
  bool get autoPauseEnabled => _autoPauseEnabled;
  bool get canExit => !_isRunning && !_isFinished;
  double get distanceKm => _distanceKm;
  double? get distanceGoal => _distanceGoal;
  int get elapsedSeconds => _secondsElapsed;
  int get pausedSeconds => _pausedSecondsElapsed;
  int get lastKmNotified => _lastKmNotified;
  PacingFeedback? get pacingFeedback => _pacingFeedback;
  LatLng? get autoPauseAnchor => _autoPauseAnchor;
  DateTime? get runStartTime => _runStartTime;
  List<RunSplit> get splits => _splits;
  List<AutoPauseEvent> get autoPauses => _autoPauses;
  List<List<LatLng>> get routePoints => _routePoints;
  List<List<int>> get routePointTimes => _routePointTimes;

  String get formattedTime => TimeUtils.formatDuration(_secondsElapsed);

  String get pace {
    if (_isRunning && !_isFinished) return _currentSmoothedPace;
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

    try {
      final prefs = await SharedPreferences.getInstance();
      _autoPauseEnabled = prefs.getBool(_autoPauseEnabledKey) ?? true;
    } catch (e) {
      debugPrint('RunSession: não foi possível ler auto-pause: $e');
    }

    if (restoredState != null) {
      _hasRestoredState = true;
      _restoreState(restoredState);
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
        _routePoints = [
          [point],
        ];
        _routePointTimes = [
          [_secondsElapsed],
        ];
        _trackPointTimes = true;
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
    _lastResumeSeconds = 0;
    _lastKmNotified = 0;
    _splits = [];
    _lastSplitTimeSeconds = 0;
    _lastSplitCalories = 0;
    _autoPauses = [];
    _currentAutoPauseDurationSeconds = 0;
    _autoPauseStartTime = null;
    _routePoints = [[]];
    _routePointTimes = [[]];
    _trackPointTimes = true;
    _paceBuffer = [];
    _currentSmoothedPace = '0:00';
    _isRunning = true;
    _isPaused = false;
    _isFinished = false;
    _isFirstPointAfterResume = true;
    _isAutoPaused = false;
    _autoPauseAnchor = null;
    _lowSpeedTicks = 0;
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
    _isAutoPaused = false;
    _lowSpeedTicks = 0;
    _autoPauseAnchor = null;
    _stopRuntime();
    _notifyState();
    _persistState(forceRoute: true);
  }

  void resume() {
    if (!_isRunning || _isFinished || (!_isPaused && !_isAutoPaused)) return;
    _isPaused = false;
    _isAutoPaused = false;
    _lowSpeedTicks = 0;
    _autoPauseAnchor = null;
    _isFirstPointAfterResume = true;
    _lastResumeSeconds = _secondsElapsed;
    _startNewSegmentIfNeeded();
    _notifyState();
    _notifyRoute();
    _startRuntime();
    _persistState(forceRoute: true);
  }

  Future<void> setAutoPauseEnabled(bool enabled) async {
    _autoPauseEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoPauseEnabledKey, enabled);
    } catch (e) {
      debugPrint('RunSession: não foi possível salvar auto-pause: $e');
    }

    if (!enabled && _isAutoPaused) {
      _isAutoPaused = false;
      _autoPauseAnchor = null;
      _autoPauseStartTime = null;
      _currentAutoPauseDurationSeconds = 0;
      _lowSpeedTicks = 0;
      _isFirstPointAfterResume = true;
      _lastResumeSeconds = _secondsElapsed;
      _startNewSegmentIfNeeded();
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

    if (!shortRun &&
        RunFinalizationService.shouldAddFinalSplit(
          distanceKm: _distanceKm,
          lastKmNotified: _lastKmNotified,
        )) {
      final splitTime = RunFinalizationService.calculateFinalSplitTime(
        elapsedSeconds: _secondsElapsed,
        lastSplitTimeSeconds: _lastSplitTimeSeconds,
      );
      final splitCalories = RunFinalizationService.calculateFinalSplitCalories(
        totalCalories: calories,
        lastSplitCalories: _lastSplitCalories,
      );
      _splits.add(RunSplit(timeSeconds: splitTime, calories: splitCalories));
      _lastKmNotified = RunFinalizationService.calculateFinalNotifiedKm(
        _distanceKm,
      );
    }

    _isRunning = false;
    _isFinished = true;
    _isPaused = true;
    _isAutoPaused = false;
    _notifyState();
    _notifyRoute();
    await _persistFinished();
    return false;
  }

  Future<void> discardActiveRun() async {
    _stopRuntime();
    await _activeRunStore.clear();
  }

  /// Sai/minimiza sem perder o snapshot: para timers e força a persistência.
  Future<void> suspendAndPersist() async {
    _stopRuntime();
    await flushPersistence();
  }

  Future<void> flushPersistence() async {
    await Future.wait([_metaWrites, _routeWrites]);
  }

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
        for (final segment in _routePoints) List<LatLng>.unmodifiable(segment),
      ],
      routeTimes: _trackPointTimes
          ? [
              for (final segment in _routePointTimes)
                List<int>.unmodifiable(segment),
            ]
          : const [],
      type: type,
      mood: mood,
      splits: List<RunSplit>.unmodifiable(_splits),
      autoPauses: List<AutoPauseEvent>.unmodifiable(_autoPauses),
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

    if (_isPaused || _isAutoPaused) {
      _pausedSecondsElapsed++;
      if (_isAutoPaused) _currentAutoPauseDurationSeconds++;
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

    if (_isAutoPaused) {
      final distanceMeters = _autoPauseAnchor == null
          ? 0.0
          : Geolocator.distanceBetween(
              _autoPauseAnchor!.latitude,
              _autoPauseAnchor!.longitude,
              position.latitude,
              position.longitude,
            );
      final shouldResume = position.speed > 1.2 || distanceMeters > 12;
      if (shouldResume) {
        final anchor = _autoPauseAnchor;
        final duration = _currentAutoPauseDurationSeconds;
        final startedAt = _autoPauseStartTime ?? _clock.now();
        if (anchor != null && duration > 0) {
          _autoPauses.add(
            AutoPauseEvent(
              latitude: anchor.latitude,
              longitude: anchor.longitude,
              resumeLatitude: newPoint.latitude,
              resumeLongitude: newPoint.longitude,
              durationSeconds: duration,
              timestamp: startedAt.toIso8601String(),
            ),
          );
        }
        _isAutoPaused = false;
        _autoPauseAnchor = null;
        _autoPauseStartTime = null;
        _currentAutoPauseDurationSeconds = 0;
        _lowSpeedTicks = 0;
        _isFirstPointAfterResume = true;
        _lastResumeSeconds = _secondsElapsed;
        _startNewSegmentIfNeeded();
        _notifyState();
        _notifyRoute();
        _triggerEffect(_effects.autoPauseResumed);
        _emit(RunAutoPauseResumed());
      }
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

    if (_autoPauseEnabled) {
      _lowSpeedTicks = GpsFilterService.updateLowSpeedTicks(
        speed: position.speed,
        currentTicks: _lowSpeedTicks,
        elapsedSeconds: _secondsElapsed,
        lastResumeSeconds: _lastResumeSeconds,
      );
      if (GpsFilterService.shouldAutoPause(
        speed: position.speed,
        lowSpeedTicks: _lowSpeedTicks,
        elapsedSeconds: _secondsElapsed,
        lastResumeSeconds: _lastResumeSeconds,
      )) {
        _isAutoPaused = true;
        _autoPauseAnchor = newPoint;
        _autoPauseStartTime = _clock.now();
        _currentAutoPauseDurationSeconds = 0;
        _lowSpeedTicks = 0;
        _notifyState();
        _triggerEffect(_effects.autoPauseStarted);
        _emit(RunAutoPauseStarted());
        return;
      }
    }

    if (_routePoints.isNotEmpty && _routePoints.last.isNotEmpty) {
      final lastPoint = _routePoints.last.last;
      final distanceMeters = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );

      if (_isFirstPointAfterResume) {
        if (_routePoints.last.isEmpty) {
          _appendPoint(newPoint, position);
        } else {
          _startNewSegmentIfNeeded();
          _appendPoint(newPoint, position);
        }
        _paceBuffer = [position];
        _isFirstPointAfterResume = false;
        _notifyRoute();
        _emit(RunPositionUpdated(newPoint));
        return;
      }

      final lastPosition = _paceBuffer.isNotEmpty ? _paceBuffer.last : null;
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
        _paceBuffer.add(position);
        if (_paceBuffer.length > 30) _paceBuffer.removeAt(0);
        _updateSmoothedPace();
        _appendPoint(newPoint, position);
        _notifyRoute();
        _emit(RunPositionUpdated(newPoint));
        _handleKilometerCrossing();
      }
      return;
    }

    _appendPoint(newPoint, position);
    _paceBuffer = [position];
    _isFirstPointAfterResume = false;
    _notifyRoute();
    _emit(RunPositionUpdated(newPoint));
  }

  void _appendPoint(LatLng point, Position position) {
    if (_routePoints.isEmpty) {
      _routePoints.add([]);
      if (_trackPointTimes) _routePointTimes.add([]);
    }
    _routePoints.last.add(point);
    if (_trackPointTimes) {
      while (_routePointTimes.length < _routePoints.length) {
        _routePointTimes.add([]);
      }
      _routePointTimes.last.add(_secondsElapsed);
    }
  }

  void _startNewSegmentIfNeeded() {
    if (_routePoints.isEmpty || _routePoints.last.isNotEmpty) {
      _routePoints.add([]);
      if (_trackPointTimes) _routePointTimes.add([]);
    } else if (_trackPointTimes &&
        _routePointTimes.length < _routePoints.length) {
      _routePointTimes.add([]);
    }
  }

  void _handleKilometerCrossing() {
    final currentKm = _distanceKm.floor();
    if (currentKm <= _lastKmNotified) return;

    final splitTime = _secondsElapsed - _lastSplitTimeSeconds;
    final totalCalories = calories;
    _splits.add(
      RunSplit(
        timeSeconds: splitTime,
        calories: totalCalories - _lastSplitCalories,
      ),
    );
    _lastSplitTimeSeconds = _secondsElapsed;
    _lastSplitCalories = totalCalories;
    _lastKmNotified = currentKm;
    _persistState(forceRoute: true);

    if (_userProfile?.kmNotificationsEnabled == true) {
      final currentPace = _currentSmoothedPace.isNotEmpty
          ? _currentSmoothedPace
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

  void _updateSmoothedPace() {
    if (_paceBuffer.length < 5) {
      _currentSmoothedPace = '0:00';
      return;
    }
    final first = _paceBuffer.first;
    final last = _paceBuffer.last;
    var totalDistanceMeters = 0.0;
    for (var i = 0; i < _paceBuffer.length - 1; i++) {
      totalDistanceMeters += Geolocator.distanceBetween(
        _paceBuffer[i].latitude,
        _paceBuffer[i].longitude,
        _paceBuffer[i + 1].latitude,
        _paceBuffer[i + 1].longitude,
      );
    }
    final timeSeconds = last.timestamp.difference(first.timestamp).inSeconds;
    if (timeSeconds > 0 && totalDistanceMeters > 10) {
      final paceMinutes = (timeSeconds / 60) / (totalDistanceMeters / 1000);
      if (paceMinutes > 0 && paceMinutes < 35) {
        final minutes = paceMinutes.toInt();
        final seconds = ((paceMinutes - minutes) * 60).toInt();
        _currentSmoothedPace = '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
    } else if (timeSeconds > 10) {
      _currentSmoothedPace = '0:00';
    }
  }

  void _restoreState(Map<String, dynamic> state) {
    _distanceKm = (state['distanceKm'] as num?)?.toDouble() ?? 0;
    _secondsElapsed = (state['secondsElapsed'] as num?)?.toInt() ?? 0;
    _pausedSecondsElapsed =
        (state['pausedDurationSeconds'] as num?)?.toInt() ?? 0;
    _lastResumeSeconds = _secondsElapsed;
    _lastKmNotified = (state['lastKmNotified'] as num?)?.toInt() ?? 0;
    _distanceGoal = (state['distanceGoal'] as num?)?.toDouble();
    _targetTimeSeconds = (state['targetTimeSeconds'] as num?)?.toInt();
    _runStartTime = DateTime.tryParse('${state['startTime']}');
    if (_distanceGoal != null && _targetTimeSeconds != null) {
      _pacingService = PacingService(
        targetDistanceKm: _distanceGoal,
        targetTimeSeconds: _targetTimeSeconds,
      );
    }
    _splits = _decodeSplits(state['splits']);
    _lastSplitTimeSeconds = _splits.fold(
      0,
      (sum, split) => sum + split.timeSeconds,
    );
    _lastSplitCalories = _splits.fold(0, (sum, split) => sum + split.calories);
    _isPaused = (state['isPaused'] as num?)?.toInt() == 1;
    _isFinished = (state['finished'] as num?)?.toInt() == 1;
    _isRunning = !_isFinished;
    _isFirstPointAfterResume = true;
    _paceBuffer = [];
    _restoreRoute(state['route']);
    _autoPauses = _decodeAutoPauses(state['autoPauses']);
  }

  void _restoreRoute(String? routeJson) {
    _routePoints = [];
    _routePointTimes = [];
    _trackPointTimes = true;
    if (routeJson == null || routeJson.isEmpty) return;

    try {
      final decoded = jsonDecode(routeJson) as List<dynamic>;
      if (decoded.isEmpty) return;
      if (decoded.first is List) {
        _routePoints = [
          for (final segment in decoded)
            [
              for (final point in segment as List<dynamic>)
                LatLng(
                  (point['lat'] as num).toDouble(),
                  (point['lng'] as num).toDouble(),
                ),
            ],
        ];
        final times = _decodePersistedTimes(decoded);
        _trackPointTimes = times != null;
        _routePointTimes = times ?? [];
      } else {
        _routePoints = [
          [
            for (final point in decoded)
              LatLng(
                (point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble(),
              ),
          ],
        ];
        // Formato plano antigo não tem tempos por ponto.
        _trackPointTimes = false;
      }
    } catch (e) {
      debugPrint('RunSession: rota restaurada é inválida: $e');
      _routePoints = [];
      _routePointTimes = [];
      _trackPointTimes = true;
    }
  }

  List<List<int>>? _decodePersistedTimes(List<dynamic> decoded) {
    final times = <List<int>>[];
    for (final segment in decoded) {
      final segmentTimes = <int>[];
      for (final point in segment as List<dynamic>) {
        final value = point is Map ? point['t'] : null;
        if (value is num) {
          segmentTimes.add(value.toInt());
        } else {
          return null;
        }
      }
      times.add(segmentTimes);
    }
    return times;
  }

  List<RunSplit> _decodeSplits(String? splitsJson) {
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

  List<AutoPauseEvent> _decodeAutoPauses(String? autoPausesJson) {
    if (autoPausesJson == null || autoPausesJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(autoPausesJson) as List<dynamic>;
      return [
        for (final pause in decoded)
          AutoPauseEvent.fromMap((pause as Map).cast<String, dynamic>()),
      ];
    } catch (e) {
      debugPrint('RunSession: autopausas restauradas são inválidas: $e');
      return [];
    }
  }

  Future<void> _loadProfile() async {
    try {
      _userProfile = await _profileSource.load();
    } catch (e) {
      debugPrint('RunSession: não foi possível carregar o perfil: $e');
    }
  }

  void _persistState({bool forceRoute = false}) {
    if (!_isRunning || _isFinished) return;
    _queueMeta(_metaPayload(finished: false));
    _persistRoute(force: forceRoute);
  }

  Map<String, dynamic> _metaPayload({required bool finished}) => {
    'startTime': (_runStartTime ?? _clock.now()).toIso8601String(),
    'distanceKm': _distanceKm,
    'secondsElapsed': _secondsElapsed,
    'pausedDurationSeconds': _pausedSecondsElapsed,
    'lastKmNotified': _lastKmNotified,
    'distanceGoal': _distanceGoal,
    'targetTimeSeconds': _targetTimeSeconds,
    'isPaused': finished || _isPaused ? 1 : 0,
    'finished': finished ? 1 : 0,
    'splits': jsonEncode([for (final split in _splits) split.toMap()]),
    'autoPauses': jsonEncode([for (final pause in _autoPauses) pause.toMap()]),
  };

  void _queueMeta(Map<String, dynamic> payload) {
    _metaWrites = _metaWrites.then((_) async {
      try {
        await _activeRunStore.saveMeta(payload);
      } catch (e) {
        debugPrint('RunSession: falha ao persistir metadados: $e');
      }
    });
  }

  void _persistRoute({bool force = false}) {
    if (!_isRunning || _isFinished) return;
    final now = _clock.now();
    final last = _lastRoutePersistAt;
    if (!force &&
        last != null &&
        now.difference(last) < _routePersistInterval) {
      return;
    }
    _lastRoutePersistAt = now;
    final payload = _encodeRouteJson();
    _routeWrites = _routeWrites.then((_) async {
      try {
        await _activeRunStore.saveRoute(payload);
      } catch (e) {
        debugPrint('RunSession: falha ao persistir rota: $e');
        _lastRoutePersistAt = null;
      }
    });
  }

  String _encodeRouteJson() {
    final segments = <List<Map<String, dynamic>>>[];
    for (var si = 0; si < _routePoints.length; si++) {
      final segment = _routePoints[si];
      final times = si < _routePointTimes.length ? _routePointTimes[si] : null;
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

  Future<void> _persistFinished() async {
    // Espera escritas já enfileiradas antes de publicar o snapshot final.
    // Assim uma gravação atrasada não pode regravar finished = 0 depois.
    await Future.wait([_metaWrites, _routeWrites]);
    try {
      await _activeRunStore.saveMeta(_metaPayload(finished: true));
      await _activeRunStore.saveRoute(_encodeRouteJson());
    } catch (e) {
      debugPrint('RunSession: falha ao persistir treino finalizado: $e');
    }
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
