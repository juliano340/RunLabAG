import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../features/training/services/training_service.dart';
import '../../../../core/services/pacing_service.dart';
import '../widgets/metric_card.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/ad_banner_widget.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/services/achievement_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/services/backup_service.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/runs_provider.dart';

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
  String? _minimalMapStyle;
  String? _darkMapStyle;
  String? _darkMinimalMapStyle;
  bool _isMapStylesLoaded = false;
  bool _isMapReady = false;

  // Metrics
  double _distanceKm = 0.0;
  double? _distanceGoal;
  int? _targetTimeSeconds;
  PacingService? _pacingService;
  PacingFeedback? _pacingFeedback;
  int _secondsElapsed = 0;
  int _lastKmNotified = 0;
  List<RunSplit> _splits = [];
  int _lastSplitTimeSeconds = 0;
  int _lastSplitCalories = 0;
  Timer? _timer;
  UserProfile? _userProfile;
  final AchievementService _achievementService = AchievementService();

  // Smoothing fields
  List<Position> _paceBuffer = [];
  String _currentSmoothedPace = '0:00';
  bool _isFirstPointAfterResume = false;

  bool _isExiting = false;
  bool _isScreenLocked = false;
  bool _isSaving = false; // Guard contra double-save
  bool _showLockHint = false;
  Timer? _lockHintTimer;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 15,
  );

  ThemeService? _themeService;

  @override
  void initState() {
    super.initState();
    _loadMapPreference();
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

  void _restoreState(Map<String, dynamic> state) {
    setState(() {
      _distanceKm = state['distanceKm'] ?? 0.0;
      _secondsElapsed = state['secondsElapsed'] ?? 0;
      _lastKmNotified = state['lastKmNotified'] ?? 0;
      _distanceGoal = state['distanceGoal'];
      _targetTimeSeconds = state['targetTimeSeconds'];

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
      'startTime': DateTime.now().toIso8601String(),
      'distanceKm': _distanceKm,
      'secondsElapsed': _secondsElapsed,
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

    Position? currentPos;
    try {
      currentPos = await _locationService.getCurrentLocation();
    } catch (e) {
      debugPrint("Could not get initial position for run: $e");
    }

    setState(() {
      _distanceKm = 0.0;
      _secondsElapsed = 0;
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
    });

    _startTimersAndStreams(isNew: true);

    AnalyticsService().logRunStarted(
      runType: _distanceGoal != null ? 'meta_distancia' : 'livre',
    );
  }

  void _startTimersAndStreams({required bool isNew}) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

        // 1. Filtro de Precisão (Mais rigoroso nos primeiros 30s)
        double maxAllowedAccuracy = _secondsElapsed < 30 ? 15.0 : 25.0;
        if (position.accuracy > maxAllowedAccuracy) {
          debugPrint(
            "GPS impreciso ignorado: ${position.accuracy}m (Max: $maxAllowedAccuracy)",
          );
          return;
        }

        final newPoint = LatLng(position.latitude, position.longitude);

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
            if (timeDiff > 0) {
              final speed = distanceInMeters / timeDiff;
              if (speed > 10.0) {
                debugPrint(
                  "Salto de GPS detectado (velocidade excessiva): ${speed.toStringAsFixed(1)} m/s",
                );
                return;
              }
            }
          }

          // 3. Filtro de Jitter (Aumentado de 3.5m para 6.0m para evitar drift parado)
          if (distanceInMeters > 6.0) {
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
    });
    _timer?.cancel();
    WakelockPlus.disable(); // Allow screen to dim
    _persistState(); // Persist pause state
  }

  void _resumeRun() {
    setState(() {
      _isPaused = false;
      _isFirstPointAfterResume = true;
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

    // Check for short run: less than 100m or 30s
    if (_distanceKm < 0.1 && _secondsElapsed < 30) {
      _showShortRunWarning();
    } else {
      // Adicionar último split se estivermos muito próximos de fechar um km (ex: 4.99km)
      // ou se simplesmente sobrou uma parte significativa (> 100m)
      int currentKm = _distanceKm.floor();
      double decimalPart = _distanceKm - currentKm;

      // Se parou quase no cravo (ex: 4.99 ou 5.01) e o split final não foi salvo
      if ((_distanceKm > _lastKmNotified) &&
          (decimalPart > 0.99 || _distanceKm > _lastKmNotified + 0.99)) {
        final splitTime = _secondsElapsed - _lastSplitTimeSeconds;
        final totalCalories = _calculateCalories();
        final splitCalories = totalCalories - _lastSplitCalories;

        _splits.add(RunSplit(timeSeconds: splitTime, calories: splitCalories));
        _lastKmNotified = _distanceKm.round(); // Arredonda para o mais próximo
      }

      setState(() {
        _isRunning = false;
        _isFinished = true;
      });
      DatabaseService().clearActiveRun();
    }
  }

  void _showShortRunWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundDarkGreen
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orangeAccent, width: 1),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Text(
              'Treino Curto',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Este treino parece muito curto (${(_distanceKm * 1000).toInt()}m em $_secondsElapsed s). Deseja descartá-lo ou salvar assim mesmo?',
          style: GoogleFonts.outfit(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textMuted
                : AppColors.textMutedDark,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () async {
                try {
                  Navigator.of(context).pop(); // Fecha o diálogo de aviso
                  _stopRunInternals();
                  await DatabaseService().clearActiveRun();
                } finally {
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                  }
                }
              },
            child: Text(
              'DESCARTAR AGORA!',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNeon,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              DatabaseService()
                  .clearActiveRun(); // Mark as finalized so recovery modal won't show
              setState(() {
                _isRunning = false;
                _isFinished = true;
              });
            },
            child: Text(
              'SALVAR ASSIM MESMO',
              style: GoogleFonts.outfit(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCamera(LatLng target) async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(target));
  }

  void _showGoalDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _GoalSelectionDialog(
        initialDistanceGoal: _distanceGoal,
        onGoalSelected: (distance, isCustom) {
          if (isCustom) {
            // Se for custom, fecha o seletor de distância e abre o de tempo
            Navigator.pop(ctx);
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted) _showTimeGoalDialog(distance);
            });
          } else {
            // Se for preset, já abre o tempo direto (ou faz o que o preset fazia)
            Navigator.pop(ctx);
            _showTimeGoalDialog(distance);
          }
        },
        onNoGoal: () {
          setState(() {
            _distanceGoal = null;
            _targetTimeSeconds = null;
            _pacingService = null;
            _pacingFeedback = null;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showTimeGoalDialog(double distance) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark
            ? AppColors.backgroundDarkGreen
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Definir Tempo Alvo para ${distance.toInt()}km',
          style: TextStyle(
            color: Theme.of(ctx).colorScheme.onSurface,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _timeOption(ctx, distance, 5, 'Pace 5:00 (Forte)'),
            _timeOption(ctx, distance, 6, 'Pace 6:00 (Moderado)'),
            _timeOption(ctx, distance, 7, 'Pace 7:00 (Leve)'),
            const Divider(color: Colors.white24),
            ListTile(
              title: const Text(
                'Sem tempo alvo',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () {
                setState(() {
                  _distanceGoal = distance;
                  _targetTimeSeconds = null;
                  _pacingService = null;
                  _pacingFeedback = null;
                });
                Navigator.pop(ctx); // Close time dialog
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeOption(
    BuildContext ctx,
    double distance,
    int paceMinutes,
    String label,
  ) {
    final int totalSeconds = (distance * paceMinutes * 60).toInt();
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        'Total: ${paceMinutes * distance.toInt()} min',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      onTap: () {
        setState(() {
          _distanceGoal = distance;
          _targetTimeSeconds = totalSeconds;
          _pacingService = PacingService(
            targetDistanceKm: _distanceGoal,
            targetTimeSeconds: _targetTimeSeconds,
          );
        });
        Navigator.pop(ctx);
      },
    );
  }

  Widget _goalOption(BuildContext ctx, double value, String label) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: _distanceGoal == value
          ? const Icon(LucideIcons.check, color: AppColors.primaryNeon)
          : null,
      onTap: () {
        Navigator.pop(ctx);
        _showTimeGoalDialog(value);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lockHintTimer?.cancel();
    _positionStream?.cancel();
    _themeService?.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<bool?> _showDiscardConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundDarkGreen
            : Colors.white,
        title: Text(
          'Descartar Treino?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Tem certeza? Todos os dados do treino serão perdidos e não poderão ser recuperados.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : AppColors.textMutedDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'CONFIRMAR DESCARTE AGORA',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showExitConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundDarkGreen
            : Colors.white,
        title: Text(
          'Sair da Corrida?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Tem certeza que deseja sair? O progresso não salvo será perdido.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : AppColors.textMutedDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'SAIR',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
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

  void _stopRunInternals() {
    _timer?.cancel();
    _positionStream?.cancel();
    WakelockPlus.disable();
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
            RepaintBoundary(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: _initialPosition,
                    myLocationEnabled: _hasPermissions,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapType: MapType.normal,
                    style: _getMapStyle(),
                    padding: EdgeInsets.only(
                      bottom: (_distanceGoal != null && _distanceGoal! > 0)
                          ? 380
                          : 280,
                      top: safeTopInset + 60,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (mounted) {
                          setState(() => _isMapReady = true);
                        }
                      });
                    },
                markers: {
                  if (_routePoints.isNotEmpty && _routePoints.first.isNotEmpty)
                    Marker(
                      markerId: const MarkerId('start'),
                      position: _routePoints.first.first,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                      infoWindow: const InfoWindow(title: 'Início'),
                    ),
                  if (_isFinished &&
                      _routePoints.isNotEmpty &&
                      _routePoints.last.isNotEmpty)
                    Marker(
                      markerId: const MarkerId('finish'),
                      position: _routePoints.last.last,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                      infoWindow: const InfoWindow(title: 'Chegada'),
                    ),
                },
                    polylines: _routePoints.asMap().entries.map((entry) {
                      final int idx = entry.key;
                      final List<LatLng> segment = entry.value;
                      return Polyline(
                        polylineId: PolylineId('route_$idx'),
                        points: segment,
                        color: AppColors.primaryNeon,
                        width: 5,
                        startCap: Cap.roundCap,
                        endCap: Cap.roundCap,
                      );
                    }).toSet(),
                  ),
                  // Cobertura anti-flash: esconde o mapa branco até o estilo ser aplicado
                  if (!_isMapReady && isDark)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(color: const Color(0xFF1d2c2c)),
                      ),
                    ),
                ],
              ),
            ),

            // Top bar: back button | ad | eye+lock column
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Botão Voltar (Esquerda)
                      CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.8),
                        child: IconButton(
                          icon: Icon(
                            LucideIcons.arrowLeft,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          onPressed: _handleBackPress,
                        ),
                      ),
                      // Título + Anúncio Centralizado
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDark) ...[
                              Text(
                                'CORRIDA ATUAL',
                                style: GoogleFonts.outfit(
                                  color: AppColors.primaryNeon,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 6,
                                    ),
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                              ),
                              if (_isRunning)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: _isPaused
                                            ? Colors.orange
                                            : AppColors.primaryNeon,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _isPaused ? 'PAUSADO' : 'GPS ATIVO',
                                      style: GoogleFonts.outfit(
                                        color: _isPaused
                                            ? Colors.orange
                                            : AppColors.primaryNeon,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black87,
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 4),
                            ],
                            AdBannerWidget(
                              adSize: AdSize(width: 200, height: 50),
                            ),
                          ],
                        ),
                      ),
                      // Coluna direita: Olho (cima) + Cadeado (baixo)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.8),
                            child: IconButton(
                              icon: Icon(
                                _showMinimalMap
                                    ? LucideIcons.eyeOff
                                    : LucideIcons.eye,
                                color: AppColors.primaryNeon,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showMinimalMap = !_showMinimalMap;
                                });
                                _saveMapPreference(_showMinimalMap);
                              },
                              tooltip: 'Alternar Mapa Minimalista',
                            ),
                          ),
                          if (_isRunning) ...[
                            const SizedBox(height: 8),
                            CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surface.withValues(alpha: 0.8),
                              child: IconButton(
                                icon: const Icon(
                                  LucideIcons.lock,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isScreenLocked = true;
                                    _showLockHint = true;
                                  });
                                  HapticFeedback.heavyImpact();
                                  _lockHintTimer?.cancel();
                                  _lockHintTimer = Timer(
                                    const Duration(seconds: 3),
                                    () {
                                      if (mounted) {
                                        setState(() {
                                          _showLockHint = false;
                                        });
                                      }
                                    },
                                  );
                                },
                                tooltip: 'Bloquear Tela',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Dashboard Card
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0A120A).withValues(alpha: 0.97)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? AppColors.primaryNeon.withValues(alpha: 0.15)
                          : AppColors.primaryNeon.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      if (Theme.of(context).brightness == Brightness.dark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Handle bar ──
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── DURAÇÃO label ──
                      Text(
                        'DURAÇÃO',
                        style: GoogleFonts.outfit(
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.textMutedDark,
                          fontSize: 11,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // ── Timer grande ──
                      Text(
                        _formatTime(),
                        style: GoogleFonts.outfit(
                          color: isDark
                              ? AppColors.primaryNeon
                              : AppColors.lightPrimary,
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ── 3 métricas em linha ──
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                isDark,
                                LucideIcons.footprints,
                                'DISTÂNCIA',
                                _distanceKm.toStringAsFixed(2),
                                'km',
                              ),
                            ),
                            VerticalDivider(
                              color: isDark ? Colors.white12 : Colors.black12,
                              thickness: 1,
                              width: 1,
                            ),
                            Expanded(
                              child: _buildMetricTile(
                                isDark,
                                LucideIcons.timer,
                                'RITMO',
                                _calculatePace(),
                                'min/km',
                              ),
                            ),
                            VerticalDivider(
                              color: isDark ? Colors.white12 : Colors.black12,
                              thickness: 1,
                              width: 1,
                            ),
                            Expanded(
                              child: _buildMetricTile(
                                isDark,
                                LucideIcons.zap,
                                'CALORIAS',
                                _calculateCalories().toString(),
                                'kcal',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Circular Goal Progress (only when goal is set)
                      if (_distanceGoal != null &&
                          _distanceGoal! > 0 &&
                          !_isFinished)
                        _buildGoalProgress(),
                      const SizedBox(height: 20),
                      if (_isFinished)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: () async {
                                  final confirmed =
                                      await _showDiscardConfirmation();
                                    if (confirmed == true && context.mounted) {
                                      await DatabaseService().clearActiveRun();
                                      if (context.mounted) {
                                        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                                      }
                                    }
                                },
                                child: const Text(
                                  'DESCARTAR',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: AppColors.primaryNeon,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: _isSaving
                                    ? null
                                    : () async {
                                        // Guard: impede double-save por duplo clique ou fluxo inesperado
                                        if (_isSaving) return;
                                        setState(() => _isSaving = true);

                                        try {
                                          final String? selectedType =
                                              await _showTrainingTypePicker();
                                          if (selectedType == null) {
                                            setState(() => _isSaving = false);
                                            return;
                                          }

                                          final String selectedMood =
                                              await _showMoodPicker() ?? '';

                                          final dbService = DatabaseService();
                                          final run = RunModel(
                                            id: DateTime.now()
                                                .millisecondsSinceEpoch
                                                .toString(),
                                            date: DateTime.now(),
                                            distanceKm: _distanceKm,
                                            durationSeconds: _secondsElapsed,
                                            pace: _calculatePace(),
                                            calories: _calculateCalories(),
                                            route: List.from(_routePoints),
                                            type: selectedType,
                                            mood: selectedMood,
                                            splits: List.from(_splits),
                                          );
                                          await dbService.saveRun(run);
                                          await dbService.clearActiveRun();

                                          // Backup automático se habilitado. Falha silencioso.
                                          unawaited(
                                            BackupService()
                                                .runAutoBackupIfEnabled(),
                                          );

                                          // Notifica o HistoryTab (e outros ouvintes) que há um novo treino.
                                          if (context.mounted) {
                                            context
                                                .read<RunsProvider>()
                                                .notifyRunSaved();
                                          }

                                          // Analytics: treino salvo com sucesso
                                          await AnalyticsService()
                                              .logRunCompleted(
                                                distanceKm: run.distanceKm,
                                                durationSeconds:
                                                    run.durationSeconds,
                                                pace: run.pace,
                                                calories: run.calories,
                                                runType:
                                                    run.type ?? 'desconhecido',
                                                mood: run.mood ?? '',
                                              );

                                          // Verificar se o treino cumpre a sessão do plano de treinamento
                                          final trainingService =
                                              TrainingService(dbService);
                                          final isPlanSuccessful =
                                              await trainingService
                                                  .matchRunToPlan(run);

                                          final newAwards =
                                              await _achievementService
                                                  .checkAwards(run);

                                          for (final award in newAwards) {
                                            AnalyticsService()
                                                .logAchievementUnlocked(
                                                  achievementId: award['id'],
                                                );
                                          }

                                          if (context.mounted) {
                                            String snackMessage = '';
                                            if (isPlanSuccessful) {
                                              snackMessage =
                                                  'SESSÃO DO PLANO CONCLUÍDA! 🎯';
                                            } else if (newAwards.isNotEmpty) {
                                              snackMessage =
                                                  'PARABÉNS! Você ganhou ${newAwards.length} novas conquistas! 🏆';
                                            }

                                            if (snackMessage.isNotEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    snackMessage,
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  backgroundColor:
                                                      AppColors.primaryNeon,
                                                  duration: const Duration(
                                                    seconds: 5,
                                                  ),
                                                ),
                                              );
                                            }

                                            if (context.mounted) {
                                              Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
                                            }
                                          }
                                        } catch (e) {
                                          // Em caso de erro, libera o botão para tentar novamente
                                          if (mounted)
                                            setState(() => _isSaving = false);
                                          AnalyticsService().recordError(
                                            e,
                                            StackTrace.current,
                                            reason: 'save_run_failed',
                                          );
                                        }
                                      },
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Text(
                                        'SALVAR TREINO',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        )
                      else if (!_isRunning)
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: BorderSide(
                                    color: _distanceGoal != null
                                        ? AppColors.primaryNeon
                                        : Colors.white24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: _showGoalDialog,
                                icon: Icon(
                                  LucideIcons.target,
                                  color: _distanceGoal != null
                                      ? AppColors.primaryNeon
                                      : Colors.white70,
                                ),
                                label: Text(
                                  _distanceGoal != null
                                      ? 'META: ${_distanceGoal!.toInt()}KM'
                                      : 'DEFINIR META',
                                  style: TextStyle(
                                    color: _distanceGoal != null
                                        ? AppColors.primaryNeon
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: AppColors.primaryNeon,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: _startRun,
                                child: const Text(
                                  'INICIAR',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            if (_pacingFeedback != null &&
                                _pacingFeedback!.status != PacingStatus.none)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildPacingCard(),
                              )
                            else if (_distanceGoal != null &&
                                _secondsElapsed >= 90)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      LucideIcons.clock,
                                      size: 16,
                                      color: AppColors.primaryNeon,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'CHEGADA ESTIMADA: ${_calculateETA()}',
                                      style: const TextStyle(
                                        color: AppColors.primaryNeon,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Row(
                              children: [
                                if (_isPaused)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? const Color(0xFF1E3D1A)
                                            : AppColors.lightPrimary,
                                        foregroundColor: isDark
                                            ? AppColors.primaryNeon
                                            : Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: _resumeRun,
                                      icon: const Icon(
                                        LucideIcons.play,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        'RETOMAR',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? const Color(0xFF3D2B0E)
                                            : Colors.orange.shade700,
                                        foregroundColor: isDark
                                            ? const Color(0xFFFFA726)
                                            : Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: _pauseRun,
                                      icon: const Icon(
                                        LucideIcons.pause,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        'PAUSAR',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? const Color(0xFF2B0E0E)
                                          : Colors.red.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _stopRun,
                                    icon: const Icon(
                                      LucideIcons.square,
                                      size: 20,
                                    ),
                                    label: const Text(
                                      'PARAR',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Screen Lock Overlay
            if (_isScreenLocked)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showLockHint = true;
                    });
                    _lockHintTimer?.cancel();
                    _lockHintTimer = Timer(const Duration(seconds: 3), () {
                      if (mounted) {
                        setState(() {
                          _showLockHint = false;
                        });
                      }
                    });
                  },
                  onLongPress: () {
                    setState(() {
                      _isScreenLocked = false;
                      _showLockHint = false;
                    });
                    _lockHintTimer?.cancel();
                    HapticFeedback.mediumImpact();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Align(
                      alignment: const Alignment(
                        0,
                        -0.4,
                      ), // Reposicionado para cima
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.lock,
                            color: AppColors.primaryNeon,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          AnimatedOpacity(
                            opacity: _showLockHint ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              'Pressione e segure para desbloquear',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _calculateCalories() {
    if (_distanceKm == 0) return 0;
    // Base: 1.036 kcal/kg/km ou 65 kcal/km fixos
    double weight = _userProfile?.weight ?? 70.0;
    return (weight * _distanceKm * 1.036).toInt();
  }

  String _calculatePace() {
    if (_isRunning && !_isFinished) {
      return _currentSmoothedPace;
    }

    if (_distanceKm == 0) return '0:00';
    double paceInMinutes = (_secondsElapsed / 60) / _distanceKm;
    int minutes = paceInMinutes.toInt();
    int seconds = ((paceInMinutes - minutes) * 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _calculateETA() {
    if (_distanceKm < 0.1 || _distanceGoal == null) return '--:--';
    double paceInMinutes = (_secondsElapsed / 60) / _distanceKm;
    double remainingDistance = _distanceGoal! - _distanceKm;
    if (remainingDistance <= 0) return 'Chegou!';

    double remainingMinutes = remainingDistance * paceInMinutes;
    DateTime eta = DateTime.now().add(
      Duration(seconds: (remainingMinutes * 60).toInt()),
    );
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime() {
    return TimeUtils.formatDuration(_secondsElapsed);
  }

  /// Card de métrica — layout unificado para dark e light mode
  Widget _buildMetricTile(
    bool isDark,
    IconData icon,
    String label,
    String value,
    String unit,
  ) {
    final Color accentColor = isDark
        ? AppColors.primaryNeon
        : AppColors.lightPrimary;
    final Color labelColor = isDark
        ? AppColors.textMuted
        : AppColors.textMutedDark;
    final Color valueColor = isDark ? Colors.white : AppColors.textDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: labelColor,
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: valueColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.outfit(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgress() {
    final goal = _distanceGoal!;
    final progress = (_distanceKm / goal).clamp(0.0, 1.0);
    final remaining = (goal - _distanceKm).clamp(0.0, goal);
    final goalColor = progress >= 1.0
        ? Colors.greenAccent
        : AppColors.primaryNeon;

    String etaText = '--:--';
    if (_distanceKm > 0.05 && _secondsElapsed > 0 && remaining > 0) {
      final secsRemaining = (remaining / (_distanceKm / _secondsElapsed))
          .toInt();
      final mins = secsRemaining ~/ 60;
      final secs = secsRemaining % 60;
      etaText =
          '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    final mutedColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textMuted
        : AppColors.textMutedDark;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: goalColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goalColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Mini ring
          SizedBox(
            width: 64,
            height: 64,
            child: CustomPaint(
              painter: _GoalRingPainter(progress: progress, color: goalColor),
              child: Center(
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: GoogleFonts.outfit(
                    color: goalColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Stats
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _goalStat(
                  'META',
                  '${goal.toStringAsFixed(1)} km',
                  Theme.of(context).colorScheme.onSurface,
                  mutedColor,
                ),
                _goalStat(
                  'FALTAM',
                  '${remaining.toStringAsFixed(2)} km',
                  AppColors.primaryNeonLight,
                  mutedColor,
                ),
                _goalStat(
                  'CHEGA EM',
                  etaText,
                  Theme.of(context).colorScheme.onSurface,
                  mutedColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalStat(
    String label,
    String value,
    Color valueColor,
    Color labelColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: labelColor,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<String?> _showTrainingTypePicker() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundDarkGreen
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          32,
          24,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como foi seu treino?',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Classifique sua atividade para melhor acompanhamento.',
              style: GoogleFonts.outfit(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textMuted
                    : AppColors.textMutedDark,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            _typeOption(
              context: context,
              type: 'Corrida',
              icon: LucideIcons.zap,
              color: AppColors.primaryNeon,
              description: 'Treino contínuo em ritmo de corrida.',
            ),
            const SizedBox(height: 16),
            _typeOption(
              context: context,
              type: 'Caminhada',
              icon: LucideIcons.footprints,
              color: Colors.blueAccent,
              description: 'Caminhada leve ou vigorosa.',
            ),
            const SizedBox(height: 16),
            _typeOption(
              context: context,
              type: 'Corrida/Caminhada',
              icon: LucideIcons.timer,
              color: Colors.orangeAccent,
              description: 'Alternância entre corrida e caminhada.',
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCELAR',
                  style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeOption({
    required BuildContext context,
    required String type,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textMuted
                          : AppColors.textMutedDark,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Future<String?> _showMoodPicker() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundDarkGreen
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          32,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Como você se sentiu?',
              style: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Avalie sua experiência neste treino.',
              style: GoogleFonts.outfit(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textMuted
                    : AppColors.textMutedDark,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _moodOption(context, '😣', 'Ruim'),
                _moodOption(context, '😐', 'Médio'),
                _moodOption(context, '🙂', 'Bom'),
                _moodOption(context, '🤩', 'Excelente'),
              ],
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(
                'PULAR',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textMuted
                      : AppColors.textMutedDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPacingCard() {
    if (_pacingFeedback == null) return const SizedBox.shrink();

    final statusColor = _pacingColor(_pacingFeedback!.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      borderColor: statusColor.withValues(alpha: 0.5),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _pacingIcon(_pacingFeedback!.status),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pacingFeedback!.message,
                      style: GoogleFonts.outfit(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'IDEAL: ${_pacingFeedback!.idealPace}/km',
                          style: GoogleFonts.outfit(
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.textMutedDark,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'ATUAL: ${_pacingFeedback!.currentPace}/km',
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white70 : AppColors.textDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moodOption(BuildContext context, String emoji, String label) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, emoji),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textMuted
                  : AppColors.textMutedDark,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _pacingColor(PacingStatus status) {
    switch (status) {
      case PacingStatus.behind:
        return Colors.redAccent;
      case PacingStatus.ahead:
        return Colors.orange;
      case PacingStatus.onTrack:
        return AppColors.primaryNeon;
      case PacingStatus.none:
        return Colors.grey;
    }
  }

  IconData _pacingIcon(PacingStatus status) {
    switch (status) {
      case PacingStatus.onTrack:
        return LucideIcons.checkCircle;
      case PacingStatus.ahead:
        return LucideIcons.trendingUp;
      case PacingStatus.behind:
        return LucideIcons.trendingDown;
      case PacingStatus.none:
        return LucideIcons.info;
    }
  }
}

// ─── CustomPainter para o anel de progresso da meta ───────────────────────────
class _GoalRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _GoalRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 5.0;

    // Trilha de fundo
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withAlpha(51)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    // Arco de progresso
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159265 / 2,
      2 * 3.14159265 * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GoalRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ─── Dialog customizado para seleção de meta ──────────────────────────────────
class _GoalSelectionDialog extends StatefulWidget {
  final double? initialDistanceGoal;
  final Function(double distance, bool isCustom) onGoalSelected;
  final VoidCallback onNoGoal;

  const _GoalSelectionDialog({
    required this.initialDistanceGoal,
    required this.onGoalSelected,
    required this.onNoGoal,
  });

  @override
  State<_GoalSelectionDialog> createState() => _GoalSelectionDialogState();
}

class _GoalSelectionDialogState extends State<_GoalSelectionDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _showingCustom = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _switchToCustom() {
    setState(() => _showingCustom = true);
    // Pequeno atraso para garantir que o campo foi renderizado antes do foco
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.backgroundDarkGreen : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        _showingCustom ? 'Distância Personalizada' : 'Definir Meta de Corrida',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: _showingCustom
          ? _buildCustomView(isDark)
          : _buildPresetView(isDark),
      actions: _showingCustom
          ? [
              TextButton(
                onPressed: () {
                  _focusNode.unfocus();
                  setState(() {
                    _showingCustom = false;
                    _controller.clear();
                  });
                },
                child: Text(
                  'VOLTAR',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.primaryNeon
                      : AppColors.lightPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final distance = double.tryParse(
                      _controller.text.replaceAll(',', '.'),
                    );
                    if (distance != null) {
                      widget.onGoalSelected(distance, true);
                    }
                  }
                },
                child: Text(
                  'CONFIRMAR',
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          : null,
    );
  }

  Widget _buildPresetView(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Distância Alvo:',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _goalItem(1.0, '1 km (Velocidade)'),
        _goalItem(3.0, '3 km (Leve)'),
        _goalItem(5.0, '5 km (Avançado)'),
        _goalItem(10.0, '10 km (Resistência)'),
        Divider(color: isDark ? Colors.white24 : Colors.black12),
        ListTile(
          leading: Icon(
            LucideIcons.pencil,
            color: isDark ? Colors.white38 : Colors.black38,
            size: 18,
          ),
          title: Text(
            'Personalizado...',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          onTap: _switchToCustom,
        ),
        Divider(color: isDark ? Colors.white24 : Colors.black12),
        ListTile(
          title: Text(
            'Sem meta',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          onTap: widget.onNoGoal,
        ),
      ],
    );
  }

  Widget _buildCustomView(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Digite a distância desejada em km:',
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.textMutedDark,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white : AppColors.textDark,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Ex: 7.5',
              hintStyle: TextStyle(
                color: isDark ? Colors.white24 : Colors.black26,
                fontSize: 24,
              ),
              suffixText: 'km',
              suffixStyle: TextStyle(
                color: isDark ? AppColors.primaryNeon : AppColors.lightPrimary,
                fontWeight: FontWeight.bold,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.primaryNeon
                      : AppColors.lightPrimary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Informe a distância';
              final parsed = double.tryParse(value.replaceAll(',', '.'));
              if (parsed == null) return 'Valor inválido';
              if (parsed < 0.5) return 'Mínimo: 0.5 km';
              if (parsed > 100) return 'Máximo: 100 km';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _goalItem(double value, String label) {
    final isSelected = widget.initialDistanceGoal == value;
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: isSelected
          ? const Icon(LucideIcons.check, color: AppColors.primaryNeon)
          : null,
      onTap: () => widget.onGoalSelected(value, false),
    );
  }
}
