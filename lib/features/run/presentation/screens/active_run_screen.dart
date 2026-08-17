import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/services/pacing_service.dart';
import '../widgets/active_run/active_run_lock_overlay.dart';
import '../widgets/active_run/active_run_bottom_panel.dart';
import '../widgets/active_run/active_run_top_bar.dart';
import '../widgets/active_run/active_run_dialogs.dart';
import '../widgets/active_run/active_run_map_view.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/services/achievement_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/analytics_service.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/runs_provider.dart';
import '../../application/run_persistence_coordinator.dart';
import '../../domain/services/run_finalization_service.dart';
import '../../domain/services/run_metrics_service.dart';
import '../../domain/services/gps_filter_service.dart';

class ActiveRunScreen extends StatefulWidget {
  final Map<String, dynamic>? restoredState;
  const ActiveRunScreen({super.key, this.restoredState});

  @override
  State<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends State<ActiveRunScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = LocationService();

  StreamSubscription<Position>? _positionStream;
  List<List<LatLng>> _routePoints = []; // Lista de segmentos
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isFinished = false;
  bool _hasPermissions = false;
  bool _showMinimalMap = false;
  bool _autoPauseEnabled = false;
  bool _isAutoPaused = false;
  LatLng? _autoPauseAnchor;
  int _lowSpeedTicks = 0;
  String? _minimalMapStyle;
  String? _darkMapStyle;
  String? _darkMinimalMapStyle;
  // ignore: unused_field
  bool _isMapStylesLoaded = false;
  bool _isMapReady = false;

  // Metrics
  double _distanceKm = 0.0;
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
  Timer? _timer;
  UserProfile? _userProfile;
  // Smoothing fields
  List<Position> _paceBuffer = [];
  String _currentSmoothedPace = '0:00';
  bool _isFirstPointAfterResume = false;

  bool _isExiting = false;
  bool _isScreenLocked = false;
  bool _isSaving = false; // Guard contra double-save
  DateTime? _lastAutoResumeSnackAt;
  DateTime? _runStartTime;

  ThemeService? _themeService;

  @override
  void initState() {
    super.initState();
    _loadMapPreference();
    _loadAutoPausePreference();
    _loadMapStyle();
    _initLocation();
    _loadUserProfile();
    if (widget.restoredState != null) {
      _restoreState(widget.restoredState!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newThemeService = context.read<ThemeService>();
    if (_themeService != newThemeService) {
      _themeService?.removeListener(_onThemeChanged);
      _themeService = newThemeService;
      _themeService!.addListener(_onThemeChanged);
    }
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadMapPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showMinimalMap = prefs.getBool('show_minimal_map') ?? false;
    });
  }

  Future<void> _saveMapPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_minimal_map', value);
  }

  Future<void> _loadAutoPausePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoPauseEnabled = prefs.getBool('auto_pause_enabled') ?? false;
    });
  }

  Future<void> _saveAutoPausePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_pause_enabled', value);
  }

  void _toggleAutoPause() {
    setState(() {
      _autoPauseEnabled = !_autoPauseEnabled;
      if (!_autoPauseEnabled) {
        if (_isAutoPaused) {
          _isAutoPaused = false;
          _autoPauseAnchor = null;
          _lowSpeedTicks = 0;
          if (_isRunning && !_isPaused) {
            _resumeRun();
          }
        }
      }
    });
    _saveAutoPausePreference(_autoPauseEnabled);
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _autoPauseEnabled ? 'Auto Pause Ativado' : 'Auto Pause Desativado',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _restoreState(Map<String, dynamic> state) {
    setState(() {
      _distanceKm = state['distanceKm'] ?? 0.0;
      _secondsElapsed = state['secondsElapsed'] ?? 0;
      _pausedSecondsElapsed = state['pausedDurationSeconds'] ?? 0;
      _lastResumeSeconds = _secondsElapsed;
      _lastKmNotified = state['lastKmNotified'] ?? 0;
      _distanceGoal = state['distanceGoal'];
      _targetTimeSeconds = state['targetTimeSeconds'];

      // Restore the original run start time
      if (state['startTime'] != null) {
        _runStartTime = DateTime.tryParse(state['startTime']);
      }

      if (_distanceGoal != null && _targetTimeSeconds != null) {
        _pacingService = PacingService(
          targetDistanceKm: _distanceGoal,
          targetTimeSeconds: _targetTimeSeconds,
        );
      }

      final splitsJson = state['splits'];
      if (splitsJson != null) {
        final List<dynamic> decoded = jsonDecode(splitsJson);
        _splits = decoded.map((s) {
          if (s is Map) return RunSplit.fromMap(s.cast<String, dynamic>());
          if (s is int) return RunSplit(timeSeconds: s, calories: 0);
          return RunSplit(timeSeconds: 0, calories: 0);
        }).toList();
        // Estimar o tempo do último split a partir da soma dos splits restaurados
        _lastSplitTimeSeconds = _splits.fold(
          0,
          (sum, s) => sum + s.timeSeconds,
        );
        _lastSplitCalories = _splits.fold(0, (sum, s) => sum + s.calories);
      } else {
        _splits = [];
        _lastSplitTimeSeconds = 0;
        _lastSplitCalories = 0;
      }

      _isPaused = (state['isPaused'] ?? 0) == 1;

      final routeJson = state['route'];
      if (routeJson != null) {
        final List<dynamic> decoded = jsonDecode(routeJson);
        if (decoded.isNotEmpty && decoded.first is List) {
          _routePoints = decoded
              .map(
                (segment) => (segment as List)
                    .map((p) => LatLng(p['lat'], p['lng']))
                    .toList(),
              )
              .toList();
        } else {
          // Backward compatibility
          _routePoints = [
            decoded.map((p) => LatLng(p['lat'], p['lng'])).toList(),
          ];
        }
      }

      _isRunning = true;
    });

    // Resume core logic
    if (!_isPaused) {
      _startTimersAndStreams(isNew: false);
    }
  }

  void _persistState() {
    if (!_isRunning || _isFinished) return;

    DatabaseService().saveActiveRun({
      'startTime': (_runStartTime ?? DateTime.now()).toIso8601String(),
      'distanceKm': _distanceKm,
      'secondsElapsed': _secondsElapsed,
      'pausedDurationSeconds': _pausedSecondsElapsed,
      'lastKmNotified': _lastKmNotified,
      'distanceGoal': _distanceGoal,
      'targetTimeSeconds': _targetTimeSeconds,
      'isPaused': _isPaused ? 1 : 0,
      'route': jsonEncode(
        _routePoints
            .map(
              (segment) => segment
                  .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                  .toList(),
            )
            .toList(),
      ),
      'splits': jsonEncode(_splits.map((s) => s.toMap()).toList()),
    });
  }

  Future<void> _loadUserProfile() async {
    final profile = await DatabaseService().getUserProfile();
    setState(() {
      _userProfile = profile;
    });
  }

  Future<void> _loadMapStyle() async {
    try {
      _minimalMapStyle = await rootBundle.loadString(
        'assets/map_style_minimal.json',
      );
      _darkMapStyle = await rootBundle.loadString(
        'assets/map_style_dark.json',
      );
      _darkMinimalMapStyle = await rootBundle.loadString(
        'assets/map_style_dark_minimal.json',
      );
      if (mounted) {
        setState(() {
          _isMapStylesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Error loading map style: $e");
    }
  }

  String? _getMapStyle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return _showMinimalMap ? _darkMinimalMapStyle : _darkMapStyle;
    }

    return _showMinimalMap ? _minimalMapStyle : null;
  }

  Future<void> _initLocation() async {
    try {
      final hasPermission = await _locationService.requestPermission();
      if (hasPermission) {
        setState(() {
          _hasPermissions = true;
        });
        final pos = await _locationService.getCurrentLocation();
        final latLng = LatLng(pos.latitude, pos.longitude);

        // Define o ponto inicial do traçado
        setState(() {
          _routePoints = [
            [latLng],
          ];
        });

        final controller = await _controller.future;
        // Subtrai um pequeno valor da latitude para centralizar o marcador mais para cima na tela
        final cameraTarget = LatLng(pos.latitude - 0.002, pos.longitude);
        controller.animateCamera(CameraUpdate.newLatLngZoom(cameraTarget, 16));
      }
    } catch (e) {
      debugPrint("Error initializing location: $e");
    }
  }

  void _startRun() async {
    // Reset metrics for a fresh start
    _stopRunInternals(); // Clear any existing stream/timer

    // Capture the actual start time ONCE
    _runStartTime = DateTime.now();

    // Get initial position but don't store it (used internally by location service)
    try {
      await _locationService.getCurrentLocation();
    } catch (e) {
      debugPrint("Could not get initial position for run: $e");
    }

    setState(() {
      _distanceKm = 0.0;
      _secondsElapsed = 0;
      _pausedSecondsElapsed = 0;
      _lastResumeSeconds = 0;
      _lastKmNotified = 0;
      _splits = [];
      _lastSplitTimeSeconds = 0;
      _lastSplitCalories = 0;
      _routePoints = [[]]; // Start empty to wait for first LIVE point
      _isRunning = true;
      _isPaused = false;
      _isFinished = false;
      _isFirstPointAfterResume =
          true; // Crucial: Treat start as a resume to ignore initial teleportation
      _isAutoPaused = false;
      _autoPauseAnchor = null;
      _lowSpeedTicks = 0;
    });

    _startTimersAndStreams(isNew: true);

    AnalyticsService().logRunStarted(
      runType: _distanceGoal != null ? 'meta_distancia' : 'livre',
    );
  }

  void _startTimersAndStreams({required bool isNew}) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused || _isAutoPaused) {
        setState(() {
          _pausedSecondsElapsed++;
        });
        if (_pausedSecondsElapsed % 5 == 0) {
          _persistState();
        }
        return;
      }
      setState(() {
        _secondsElapsed++;
        if (_pacingService != null) {
          final oldStatus = _pacingFeedback?.status;
          _pacingFeedback = _pacingService!.getUpdate(
            _distanceKm,
            _secondsElapsed,
          );

          // Vibrar se o status mudar para alertar o usuário sem precisar olhar o celular
          if (_pacingFeedback != null &&
              _pacingFeedback!.status != oldStatus &&
              _pacingFeedback!.status != PacingStatus.none) {
            HapticFeedback.mediumImpact();
          }
        }
      });
      // Save state every 5 seconds
      if (_secondsElapsed % 5 == 0) {
        _persistState();
      }
    });

    WakelockPlus.enable(); // Keep screen on

    if (isNew) {
      _persistState(); // Initial save
    }

    try {
      _positionStream = _locationService.getLocationStream().listen((
        Position position,
      ) {
        if (_isPaused) return;

        final newPoint = LatLng(position.latitude, position.longitude);

        if (_isAutoPaused) {
          final distanceMeters = _autoPauseAnchor != null
              ? Geolocator.distanceBetween(
                  _autoPauseAnchor!.latitude,
                  _autoPauseAnchor!.longitude,
                  position.latitude,
                  position.longitude,
                )
              : 0.0;

          bool shouldResume = false;
          if (position.speed > 1.2) {
            shouldResume = true;
          } else if (distanceMeters > 12.0) {
            shouldResume = true;
          }

          if (shouldResume) {
            setState(() {
              _isAutoPaused = false;
              _autoPauseAnchor = null;
              _lowSpeedTicks = 0;
              _isFirstPointAfterResume = true;
              _lastResumeSeconds = _secondsElapsed;
              if (_routePoints.isEmpty || _routePoints.last.isNotEmpty) {
                _routePoints.add([]);
              }
            });
            _vibrateAutoPauseEnded();
            if (mounted) {
              _showAutoResumeSnackBar();
            }
          }
          return;
        }

        // 1. Filtro de Precisão (Mais rigoroso nos primeiros 30s)
        if (GpsFilterService.shouldRejectByAccuracy(
          pointAccuracy: position.accuracy,
          elapsedSeconds: _secondsElapsed,
        )) {
          debugPrint(
            "GPS impreciso ignorado: ${position.accuracy}m (Max: ${GpsFilterService.maxAllowedAccuracy(_secondsElapsed)})",
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
            setState(() {
              _isAutoPaused = true;
              _autoPauseAnchor = newPoint;
              _lowSpeedTicks = 0;
            });
            _vibrateAutoPauseStarted();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Treino pausado automaticamente'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
        }

        // Verifica se temos um ponto anterior no segmento ATUAL para calcular distância
        if (_routePoints.isNotEmpty && _routePoints.last.isNotEmpty) {
          final lastPoint = _routePoints.last.last;
          final distanceInMeters = Geolocator.distanceBetween(
            lastPoint.latitude,
            lastPoint.longitude,
            newPoint.latitude,
            newPoint.longitude,
          );

          if (_isFirstPointAfterResume) {
            setState(() {
              // Já garantimos no _resumeRun que existe um novo segmento vazio ou estamos no primeiro
              if (_routePoints.last.isEmpty) {
                _routePoints.last.add(newPoint);
              } else {
                _routePoints.add([newPoint]);
              }
              _paceBuffer = [position];
              _isFirstPointAfterResume = false;
            });
            _updateCamera(newPoint);
            return; // Ignora o cálculo de distância para este salto (teletransporte)
          }

          // 2. Filtro de Velocidade
          final lastPosition = _paceBuffer.isNotEmpty ? _paceBuffer.last : null;
          if (lastPosition != null) {
            final timeDiff = position.timestamp
                .difference(lastPosition.timestamp)
                .inSeconds;
            if (GpsFilterService.shouldRejectBySpeedJump(
              distanceMeters: distanceInMeters,
              timeDiffSeconds: timeDiff,
            )) {
              debugPrint(
                "Salto de GPS detectado (velocidade excessiva): ${(distanceInMeters / timeDiff).toStringAsFixed(1)} m/s",
              );
              return;
            }
          }

          // 3. Filtro de Jitter (adaptativo: 2m em movimento, 6m parado)
          if (GpsFilterService.isSignificantDisplacement(
            distanceMeters: distanceInMeters,
            estimatedSpeed: position.speed,
          )) {
            setState(() {
              _distanceKm += distanceInMeters / 1000;
              _paceBuffer.add(position);
              if (_paceBuffer.length > 30) _paceBuffer.removeAt(0);
              _updateSmoothedPace();

              _routePoints.last.add(newPoint);
            });

            _updateCamera(newPoint);

            // 4. Notificação de Milestone
            int currentKm = _distanceKm.floor();
            if (currentKm > _lastKmNotified) {
              final splitTime = _secondsElapsed - _lastSplitTimeSeconds;
              final totalCalories = _calculateCalories();
              final splitCalories = totalCalories - _lastSplitCalories;

              _splits.add(
                RunSplit(timeSeconds: splitTime, calories: splitCalories),
              );
              _lastSplitTimeSeconds = _secondsElapsed;
              _lastSplitCalories = totalCalories;

              _lastKmNotified = currentKm;
              _persistState();

              // Vibration + push notification (replaces ineffective HapticFeedback)
              if (_userProfile?.kmNotificationsEnabled == true) {
                final currentPace = _currentSmoothedPace.isNotEmpty
                    ? _currentSmoothedPace
                    : '--:--';
                NotificationService.sendKmMilestone(currentKm, currentPace);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          LucideIcons.trophy,
                          color: AppColors.primaryNeon,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AchievementService.getIncentiveMessage(currentKm),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.backgroundDarkGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          }
        } else {
          // Primeiro ponto do primeiro segmento ou se resetado
          setState(() {
            if (_routePoints.isEmpty) {
              _routePoints = [
                [newPoint],
              ];
            } else if (_routePoints.last.isEmpty) {
              _routePoints.last.add(newPoint);
            } else {
              _routePoints.add([newPoint]);
            }
            _paceBuffer = [position];
            _isFirstPointAfterResume = false;
          });
          _updateCamera(newPoint);
        }
      });
    } catch (e) {
      debugPrint("Error starting location stream: $e");
    }
  }

  void _updateSmoothedPace() {
    // Exigimos pelo menos 5 amostras para começar a suavizar (cerca de 5-10 segundos)
    if (_paceBuffer.length < 5) {
      _currentSmoothedPace = '0:00';
      return;
    }

    final first = _paceBuffer.first;
    final last = _paceBuffer.last;

    // Calcula a distância total percorrida DENTRO de todo o buffer para maior precisão
    double totalBufferDist = 0;
    for (int i = 0; i < _paceBuffer.length - 1; i++) {
      totalBufferDist += Geolocator.distanceBetween(
        _paceBuffer[i].latitude,
        _paceBuffer[i].longitude,
        _paceBuffer[i + 1].latitude,
        _paceBuffer[i + 1].longitude,
      );
    }

    final timeSeconds = last.timestamp.difference(first.timestamp).inSeconds;

    // Se o deslocamento total no buffer for muito pequeno (< 10m), assume que está parado/muito lento
    if (timeSeconds > 0 && totalBufferDist > 10) {
      double paceInMinutes = (timeSeconds / 60) / (totalBufferDist / 1000);
      if (paceInMinutes > 0 && paceInMinutes < 35) {
        // Limite razoável
        int minutes = paceInMinutes.toInt();
        int seconds = ((paceInMinutes - minutes) * 60).toInt();
        _currentSmoothedPace = '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
    } else if (timeSeconds > 10) {
      // Se passou muito tempo e não se mexeu 10m, o ritmo é muito baixo
      _currentSmoothedPace = '0:00';
    }
  }

  void _pauseRun() {
    setState(() {
      _isPaused = true;
      _isAutoPaused = false;
      _lowSpeedTicks = 0;
      _autoPauseAnchor = null;
    });
    _timer?.cancel();
    WakelockPlus.disable(); // Allow screen to dim
    _persistState(); // Persist pause state
  }

  void _resumeRun() {
    setState(() {
      _isPaused = false;
      _isAutoPaused = false;
      _lowSpeedTicks = 0;
      _autoPauseAnchor = null;
      _isFirstPointAfterResume = true;
      _lastResumeSeconds = _secondsElapsed;
      // Inicia um novo segmento se o último não estiver vazio
      if (_routePoints.isEmpty || _routePoints.last.isNotEmpty) {
        _routePoints.add([]);
      }
    });
    _startTimersAndStreams(isNew: false);
    _persistState(); // Persist resume state
  }

  void _stopRun() async {
    _pauseRun();

    final bool? shouldStop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundDarkGreen
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        title: Text(
          'Parar Treino?',
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Deseja realmente encerrar este treino? Uma vez encerrado, não será possível retomá-lo.',
          style: GoogleFonts.outfit(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textMuted
                : AppColors.textMutedDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CONTINUAR',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'ENCERRAR',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldStop == true) {
      _finalizeRun();
    } else {
      _resumeRun();
    }
  }

  void _finalizeRun() {
    _positionStream?.cancel();

    if (RunFinalizationService.isShortRun(
      distanceKm: _distanceKm,
      elapsedSeconds: _secondsElapsed,
    )) {
      _showShortRunWarning();
    } else {
      if (RunFinalizationService.shouldAddFinalSplit(
        distanceKm: _distanceKm,
        lastKmNotified: _lastKmNotified,
      )) {
        final splitTime = RunFinalizationService.calculateFinalSplitTime(
          elapsedSeconds: _secondsElapsed,
          lastSplitTimeSeconds: _lastSplitTimeSeconds,
        );
        final totalCalories = _calculateCalories();
        final splitCalories = RunFinalizationService.calculateFinalSplitCalories(
          totalCalories: totalCalories,
          lastSplitCalories: _lastSplitCalories,
        );

        _splits.add(RunSplit(timeSeconds: splitTime, calories: splitCalories));
        _lastKmNotified = RunFinalizationService.calculateFinalNotifiedKm(
          _distanceKm,
        );
      }

      setState(() {
        _isRunning = false;
        _isFinished = true;
      });
      DatabaseService().clearActiveRun();
    }
  }

  Future<void> _showShortRunWarning() async {
    final shouldDiscard = await ActiveRunDialogs.showShortRunWarning(
      context,
      (_distanceKm * 1000).toInt(),
      _secondsElapsed,
    );

    if (shouldDiscard == true) {
      _stopRunInternals();
      await DatabaseService().clearActiveRun();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    } else if (shouldDiscard == false) {
      DatabaseService().clearActiveRun();
      setState(() {
        _isRunning = false;
        _isFinished = true;
      });
    }
  }

  Future<void> _updateCamera(LatLng target) async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(target));
  }

  Future<bool?> _showDiscardConfirmation() {
    return ActiveRunDialogs.showDiscardConfirmation(context);
  }

  Future<bool?> _showExitConfirmation() {
    return ActiveRunDialogs.showExitConfirmation(context);
  }

  void _handleBackPress() async {
    if (_isExiting) return;

    final bool canExit = !_isRunning && !_isFinished;
    if (canExit) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final shouldExit = await _showExitConfirmation();
    if (shouldExit == true) {
      _stopRunInternals();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    }
  }

  void _showGoalDialog() {
    ActiveRunDialogs.showGoalDialog(
      context,
      initialDistanceGoal: _distanceGoal,
      onGoalSet: (distance, targetTimeSeconds, pacingService) {
        setState(() {
          _distanceGoal = distance;
          _targetTimeSeconds = targetTimeSeconds;
          _pacingService = pacingService;
          _pacingFeedback = null;
        });
      },
      onNoGoal: () {
        setState(() {
          _distanceGoal = null;
          _targetTimeSeconds = null;
          _pacingService = null;
          _pacingFeedback = null;
        });
      },
    );
  }

  Future<String?> _showTrainingTypePicker() async {
    return ActiveRunDialogs.showTrainingTypePicker(context);
  }

  Future<String?> _showMoodPicker() async {
    return ActiveRunDialogs.showMoodPicker(context);
  }

  void _stopRunInternals() {
    _timer?.cancel();
    _positionStream?.cancel();
    WakelockPlus.disable();
  }

  void _toggleMinimalMap() {
    setState(() {
      _showMinimalMap = !_showMinimalMap;
    });
    _saveMapPreference(_showMinimalMap);
  }

  void _lockScreen() {
    setState(() {
      _isScreenLocked = true;
    });
    HapticFeedback.heavyImpact();
  }

  void _unlockScreen() {
    setState(() {
      _isScreenLocked = false;
    });
  }

  Future<void> _vibrateAutoPauseStarted() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: 350, amplitude: 180);
      return;
    }
    await HapticFeedback.heavyImpact();
  }

  Future<void> _vibrateAutoPauseEnded() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(pattern: [0, 120, 80, 120]);
      return;
    }
    await HapticFeedback.mediumImpact();
  }

  Future<void> _discardFinishedRun() async {
    final confirmed = await _showDiscardConfirmation();
    if (confirmed != true || !mounted) return;
    await DatabaseService().clearActiveRun();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
  }

  Future<void> _saveRun() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final String? selectedType = await _showTrainingTypePicker();
      if (!mounted) return;
      if (selectedType == null) {
        setState(() => _isSaving = false);
        return;
      }

      final String selectedMood = await _showMoodPicker() ?? '';
      if (!mounted) return;

      final result = await RunPersistenceCoordinator().saveCompletedRun(
        startTime: _runStartTime,
        distanceKm: _distanceKm,
        durationSeconds: _secondsElapsed,
        pausedDurationSeconds: _pausedSecondsElapsed,
        pace: _calculatePace(),
        calories: _calculateCalories(),
        route: List<List<LatLng>>.from(_routePoints),
        type: selectedType,
        mood: selectedMood,
        splits: List.from(_splits),
      );
      if (!mounted) return;

      context.read<RunsProvider>().notifyRunSaved();

      String snackMessage = '';
      if (result.isPlanSuccessful) {
        snackMessage = 'SESSÃO DO PLANO CONCLUÍDA! 🎯';
      } else if (result.newAwards.isNotEmpty) {
        snackMessage = 'PARABÉNS! Você ganhou ${result.newAwards.length} novas conquistas! 🏆';
      }

      if (snackMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              snackMessage,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.primaryNeon,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/dashboard',
        (route) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      AnalyticsService().recordError(
        e,
        StackTrace.current,
        reason: 'save_run_failed',
      );
    }
  }

  void _showAutoResumeSnackBar() {
    final now = DateTime.now();
    final lastShown = _lastAutoResumeSnackAt;
    if (lastShown != null && now.difference(lastShown).inSeconds < 5) return;
    _lastAutoResumeSnackAt = now;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Treino retomado automaticamente'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bool canExit = !_isRunning && !_isFinished;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double safeTopInset = MediaQuery.viewPaddingOf(context).top;

    return PopScope(
      canPop: _isExiting || canExit,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isExiting) return;
        _handleBackPress();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            ActiveRunMapView(
              isDark: isDark,
              hasPermissions: _hasPermissions,
              isFinished: _isFinished,
              isMapReady: _isMapReady,
              mapStyle: _getMapStyle(),
              safeTopInset: safeTopInset,
              distanceGoal: _distanceGoal,
              routePoints: _routePoints,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (mounted) {
                    setState(() => _isMapReady = true);
                  }
                });
              },
            ),

            // Top bar: back button | ad | eye+lock column
            ActiveRunTopBar(
              isDark: isDark,
              isRunning: _isRunning,
              isPaused: _isPaused,
              isAutoPaused: _isAutoPaused,
              showMinimalMap: _showMinimalMap,
              autoPauseEnabled: _autoPauseEnabled,
              onBack: _handleBackPress,
              onToggleMinimalMap: _toggleMinimalMap,
              onToggleAutoPause: _toggleAutoPause,
              onLock: _lockScreen,
            ),

            // Bottom Dashboard Card
            ActiveRunBottomPanel(
              isDark: isDark,
              isRunning: _isRunning,
              isPaused: _isPaused,
              isAutoPaused: _isAutoPaused,
              isFinished: _isFinished,
              isSaving: _isSaving,
              distanceKm: _distanceKm,
              distanceGoal: _distanceGoal,
              formattedTime: _formatTime(),
              pace: _calculatePace(),
              calories: _calculateCalories().toString(),
              eta: _calculateETA(),
              pacingFeedback: _pacingFeedback,
              onStart: _startRun,
              onPause: _pauseRun,
              onResume: _resumeRun,
              onStop: _stopRun,
              onShowGoalDialog: _showGoalDialog,
              onDiscard: _discardFinishedRun,
              onSave: _saveRun,
            ),

            // Screen Lock Overlay
            if (_isScreenLocked)
              ActiveRunLockOverlay(
              onUnlock: _unlockScreen,
              ),
          ],
        ),
      ),
    );
  }

  int _calculateCalories() {
    return RunMetricsService.calculateCalories(
      _distanceKm,
      _userProfile?.weight ?? 70.0,
    );
  }

  String _calculatePace() {
    if (_isRunning && !_isFinished) {
      return _currentSmoothedPace;
    }
    return RunMetricsService.calculatePace(_secondsElapsed, _distanceKm);
  }

  String _calculateETA() {
    return RunMetricsService.calculateETA(
      currentDistanceKm: _distanceKm,
      goalDistanceKm: _distanceGoal ?? 0,
      elapsedSeconds: _secondsElapsed,
    );
  }

  String _formatTime() {
    return TimeUtils.formatDuration(_secondsElapsed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    _themeService?.removeListener(_onThemeChanged);
    super.dispose();
  }
}
