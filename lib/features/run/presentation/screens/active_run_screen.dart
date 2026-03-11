import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/database_service.dart';
import '../widgets/metric_card.dart';

class ActiveRunScreen extends StatefulWidget {
  const ActiveRunScreen({super.key});

  @override
  State<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends State<ActiveRunScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = LocationService();
  
  StreamSubscription<Position>? _positionStream;
  List<LatLng> _routePoints = [];
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isFinished = false;
  bool _hasPermissions = false;
  bool _showMinimalMap = false;
  String? _minimalMapStyle;
  
  // Metrics
  double _distanceKm = 0.0;
  double? _distanceGoal;
  int _secondsElapsed = 0;
  Timer? _timer;
  UserProfile? _userProfile;
  
  // Smoothing fields
  List<Position> _paceBuffer = [];
  String _currentSmoothedPace = '0:00';
  
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _initLocation();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await DatabaseService().getUserProfile();
    setState(() {
      _userProfile = profile;
    });
  }

  Future<void> _loadMapStyle() async {
    try {
      _minimalMapStyle = await rootBundle.loadString('assets/map_style_minimal.json');
    } catch (e) {
      debugPrint("Error loading map style: $e");
    }
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
          _routePoints = [latLng];
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
      if (currentPos != null) {
        _routePoints = [LatLng(currentPos.latitude, currentPos.longitude)];
      } else {
        _routePoints = [];
      }
      _isRunning = true;
      _isPaused = false;
      _isFinished = false;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });

    try {
      _positionStream = _locationService.getLocationStream().listen((Position position) {
        if (_isPaused) return;

        // 1. Filtro de Precisão (Ignorar se o erro for maior que 25 metros)
        if (position.accuracy > 25) {
          debugPrint("GPS impreciso ignorado: ${position.accuracy}m");
          return;
        }

        final newPoint = LatLng(position.latitude, position.longitude);
        
        if (_routePoints.isNotEmpty) {
          final lastPoint = _routePoints.last;
          final distanceInMeters = Geolocator.distanceBetween(
            lastPoint.latitude, lastPoint.longitude,
            newPoint.latitude, newPoint.longitude,
          );

          // 2. Filtro de Jitter (Ignorar pequenos movimentos < 2.5 metros)
          if (distanceInMeters > 2.5) {
            setState(() {
              _distanceKm += distanceInMeters / 1000;
              
              // 3. Atualizar buffer para ritmo suavizado
              _paceBuffer.add(position);
              if (_paceBuffer.length > 10) _paceBuffer.removeAt(0);
              _updateSmoothedPace();
            });
            
            setState(() {
              _routePoints = List.from(_routePoints)..add(newPoint);
            });
            
            _updateCamera(newPoint);
          }
        } else {
          setState(() {
            _routePoints = [newPoint];
            _paceBuffer = [position];
          });
          _updateCamera(newPoint);
        }
      });
    } catch (e) {
      debugPrint("Error starting location stream: $e");
    }
  }

  void _updateSmoothedPace() {
    if (_paceBuffer.length < 2) {
      _currentSmoothedPace = '0:00';
      return;
    }

    final first = _paceBuffer.first;
    final last = _paceBuffer.last;
    
    final distMeters = Geolocator.distanceBetween(
      first.latitude, first.longitude,
      last.latitude, last.longitude,
    );
    
    final timeSeconds = last.timestamp.difference(first.timestamp).inSeconds;

    if (timeSeconds > 0 && distMeters > 5) {
      double paceInMinutes = (timeSeconds / 60) / (distMeters / 1000);
      if (paceInMinutes > 0 && paceInMinutes < 30) { // Limite razoável de 30 min/km
        int minutes = paceInMinutes.toInt();
        int seconds = ((paceInMinutes - minutes) * 60).toInt();
        _currentSmoothedPace = '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
    }
  }

  void _pauseRun() {
    setState(() {
      _isPaused = true;
    });
    _timer?.cancel();
  }

  void _resumeRun() {
    setState(() {
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  void _stopRun() {
    _pauseRun();
    _positionStream?.cancel();

    // Check for short run: less than 100m or 30s
    if (_distanceKm < 0.1 && _secondsElapsed < 30) {
      _showShortRunWarning();
    } else {
      setState(() {
        _isRunning = false;
        _isFinished = true;
      });
    }
  }

  void _showShortRunWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
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
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Este treino parece muito curto (${(_distanceKm * 1000).toInt()}m em $_secondsElapsed s). Deseja descartá-lo ou salvar assim mesmo?',
          style: GoogleFonts.outfit(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _stopRunInternals();
              Navigator.pop(context); // Return home (discarded)
            },
            child: Text(
              'DESCARTAR',
              style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNeon,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isRunning = false;
                _isFinished = true;
              });
            },
            child: Text(
              'SALVAR ASSIM MESMO',
              style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold),
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
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Definir Meta de Distância', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _goalOption(1.0, '1 km (Velocidade)'),
            _goalOption(3.0, '3 km (Leve)'),
            _goalOption(5.0, '5 km (Avançado)'),
            _goalOption(10.0, '10 km (Resistência)'),
            const Divider(color: Colors.white24),
            ListTile(
              title: const Text('Sem meta', style: TextStyle(color: Colors.white70)),
              onTap: () {
                setState(() => _distanceGoal = null);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalOption(double value, String label) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: _distanceGoal == value ? const Icon(LucideIcons.check, color: AppColors.primaryNeon) : null,
      onTap: () {
        setState(() => _distanceGoal = value);
        Navigator.pop(context);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<bool?> _showExitConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        title: const Text('Sair da Corrida?', style: TextStyle(color: Colors.white)),
        content: const Text('Tem certeza que deseja sair? O progresso não salvo será perdido.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SAIR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _handleBackPress() async {
    final bool canExit = !_isRunning && !_isFinished;

    if (canExit) {
      if (mounted) Navigator.pop(context);
      return;
    }
    
    final shouldExit = await _showExitConfirmation();
    if (shouldExit == true) {
      _stopRunInternals(); // cancel streams
      if (mounted) {
        Navigator.pop(context); // Force pop
      }
    }
  }

  void _stopRunInternals() {
    _timer?.cancel();
    _positionStream?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final bool canExit = !_isRunning && !_isFinished;
    
    return PopScope(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            myLocationEnabled: _hasPermissions,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            style: _showMinimalMap ? _minimalMapStyle : null,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routePoints,
                color: AppColors.primaryNeon,
                width: 6,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            },
          ),
          
          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.background.withValues(alpha: 0.8),
                    child: IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                      onPressed: _handleBackPress,
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: AppColors.background.withValues(alpha: 0.8),
                    child: IconButton(
                      icon: Icon(
                        _showMinimalMap ? LucideIcons.eyeOff : LucideIcons.eye, 
                        color: AppColors.primaryNeon,
                      ),
                      onPressed: () {
                        setState(() {
                          _showMinimalMap = !_showMinimalMap;
                        });
                      },
                      tooltip: 'Alternar Mapa Minimalista',
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Dashboard Card
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDarkGreen.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Tempo',
                          value: _formatTime(),
                          unit: 'min',
                        ),
                      ),
                      Expanded(
                        child: MetricCard(
                          label: 'Distância',
                          value: _distanceKm.toStringAsFixed(2),
                          unit: 'km',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Ritmo',
                          value: _calculatePace(),
                          unit: '/km',
                        ),
                      ),
                      Expanded(
                        child: MetricCard(
                          label: 'Calorias',
                          value: _calculateCalories().toString(),
                          unit: 'kcal',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (_isFinished)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('DESCARTAR', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppColors.primaryNeon,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () async {
                              final dbService = DatabaseService();
                              final run = RunModel(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                date: DateTime.now(),
                                distanceKm: _distanceKm,
                                durationSeconds: _secondsElapsed,
                                pace: _calculatePace(),
                                calories: _calculateCalories(),
                                route: List.from(_routePoints), // Salva o percurso
                              );
                              await dbService.saveRun(run);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text('SALVAR TREINO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: _distanceGoal != null ? AppColors.primaryNeon : Colors.white24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: _showGoalDialog,
                            icon: Icon(LucideIcons.target, color: _distanceGoal != null ? AppColors.primaryNeon : Colors.white70),
                            label: Text(
                              _distanceGoal != null ? 'META: ${_distanceGoal!.toInt()}KM' : 'DEFINIR META',
                              style: TextStyle(color: _distanceGoal != null ? AppColors.primaryNeon : Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppColors.primaryNeon,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: _startRun,
                            child: const Text('INICIAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        if (_distanceGoal != null && _secondsElapsed >= 90)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.clock, size: 16, color: AppColors.primaryNeon),
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
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (_isPaused)
                              FloatingActionButton.extended(
                                heroTag: 'resume',
                                backgroundColor: AppColors.primaryNeonLight,
                                onPressed: _resumeRun,
                                icon: const Icon(LucideIcons.play),
                                label: const Text('RETOMAR', style: TextStyle(color: Colors.black)),
                              )
                            else
                              FloatingActionButton.extended(
                                heroTag: 'pause',
                                backgroundColor: Colors.orange,
                                onPressed: _pauseRun,
                                icon: const Icon(LucideIcons.pause),
                                label: const Text('PAUSAR', style: TextStyle(color: Colors.black)),
                              ),
                            FloatingActionButton.extended(
                              heroTag: 'stop',
                              backgroundColor: Colors.redAccent,
                              onPressed: _stopRun,
                              icon: const Icon(LucideIcons.square),
                              label: const Text('PARAR', style: TextStyle(color: Colors.white)),
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
    DateTime eta = DateTime.now().add(Duration(seconds: (remainingMinutes * 60).toInt()));
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime() {
    int minutes = _secondsElapsed ~/ 60;
    int seconds = _secondsElapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
