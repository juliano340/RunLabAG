import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/data/data_change_hub.dart';
import '../../../../core/domain/services/pace_zone_service.dart';
import '../../../../core/providers/runs_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/map_marker_helper.dart';
import '../../application/live_pace_trace.dart';
import '../../application/run_persistence_coordinator.dart';
import '../../application/run_session_controller.dart';
import '../../data/repositories/database_active_run_store.dart';
import '../../data/repositories/database_run_profile_source.dart';
import '../../domain/models/run_session_event.dart';
import '../widgets/active_run/active_run_bottom_panel.dart';
import '../widgets/active_run/active_run_dialogs.dart';
import '../widgets/active_run/active_run_lock_overlay.dart';
import '../widgets/active_run/active_run_map_view.dart';
import '../widgets/active_run/active_run_top_bar.dart';
import 'run_browse_screen.dart';

class ActiveRunScreen extends StatefulWidget {
  final Map<String, dynamic>? restoredState;

  /// Início expresso: dispara a corrida no primeiro toque, pulando a tela
  /// pré-início (META/INICIAR). Ignorado quando há estado restaurado.
  final bool autoStart;

  const ActiveRunScreen({
    super.key,
    this.restoredState,
    this.autoStart = false,
  });

  @override
  State<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends State<ActiveRunScreen>
    with WidgetsBindingObserver {
  final Completer<GoogleMapController> _controller = Completer();
  late final RunSessionController _session;
  late final Listenable _mapListenable;
  late final Listenable _panelListenable;
  StreamSubscription<RunSessionEvent>? _eventSubscription;

  Set<Polyline> _cachedRoutePolylines = const {};
  String _routeCacheKey = '';
  final LivePaceTrace _livePaceTrace = LivePaceTrace();
  List<int> _liveTracePointCounts = [];
  bool _liveTraceInitialized = false;
  int _reconciledSplitCount = 0;
  int _reconciledSegmentCount = 0;
  DateTime? _lastLiveReconciliationAt;
  DateTime? _lastLegacyRouteAnalysisAt;
  int _lastLegacyRoutePointCount = -1;
  Set<Marker>? _cachedMarkers;
  String _markerCacheKey = '';

  BitmapDescriptor? _pauseMarkerIcon;
  BitmapDescriptor? _resumeMarkerIcon;
  String? _minimalMapStyle;
  String? _darkMapStyle;
  String? _darkMinimalMapStyle;
  bool _showMinimalMap = false;
  bool _isMapReady = false;
  bool _isScreenLocked = false;
  bool _isSaving = false;
  DateTime? _lastCameraUpdateAt;
  DateTime? _lastAutoResumeSnackAt;
  ThemeService? _themeService;

  static const Duration _cameraUpdateInterval = Duration(seconds: 3);
  static const int _pointsPerPolyline = 250;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final databaseService = context.read<DatabaseService>();
    _session = RunSessionController(
      locations: LocationService(),
      clock: const SystemClock(),
      activeRunStore: DatabaseActiveRunStore(databaseService),
      profileSource: DatabaseRunProfileSource(databaseService),
      persistenceCoordinator: context.read<RunPersistenceCoordinator>(),
    );
    _mapListenable = Listenable.merge([
      _session.stateChanges,
      _session.routeChanges,
    ]);
    _panelListenable = Listenable.merge([
      _session.uiTick,
      _session.stateChanges,
      _session.routeChanges,
    ]);
    _eventSubscription = _session.events.listen(_onRunSessionEvent);
    _loadMapPreference();
    _loadMapStyle();
    _loadMarkerIcons();
    unawaited(
      _session.initialize(
        restoredState: widget.restoredState,
        autoStart: widget.autoStart,
      ),
    );
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // O foreground service mantém o GPS, mas não podemos depender dele para
      // garantir que a última rota chegou ao banco antes de ir para background.
      unawaited(_session.flushPersistence());
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final results = await Future.wait([
        MapMarkerHelper.getPauseMarkerIcon(),
        MapMarkerHelper.getResumeMarkerIcon(),
      ]);
      if (!mounted) return;
      setState(() {
        _pauseMarkerIcon = results[0];
        _resumeMarkerIcon = results[1];
        _markerCacheKey = '';
      });
    } catch (e) {
      debugPrint('Erro ao gerar marcadores premium: $e');
    }
  }

  Future<void> _loadMapPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _showMinimalMap = prefs.getBool('show_minimal_map') ?? false;
      });
    } catch (e) {
      debugPrint('Não foi possível ler a preferência do mapa: $e');
    }
  }

  Future<void> _saveMapPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_minimal_map', value);
  }

  void _toggleAutoPause() {
    unawaited(_session.setAutoPauseEnabled(!_session.autoPauseEnabled));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _session.autoPauseEnabled
              ? 'Auto Pause Ativado'
              : 'Auto Pause Desativado',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadMapStyle() async {
    try {
      _minimalMapStyle = await rootBundle.loadString(
        'assets/map_style_minimal.json',
      );
      _darkMapStyle = await rootBundle.loadString('assets/map_style_dark.json');
      _darkMinimalMapStyle = await rootBundle.loadString(
        'assets/map_style_dark_minimal.json',
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading map style: $e');
    }
  }

  String? _getMapStyle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return _showMinimalMap ? _darkMinimalMapStyle : _darkMapStyle;
    }
    return _showMinimalMap ? _minimalMapStyle : null;
  }

  Set<Marker> _buildMapMarkers() {
    final anchor = _session.autoPauseAnchor;
    final key =
        '${_session.autoPauses.length}:${_session.isAutoPaused}:'
        '${anchor?.latitude}:${anchor?.longitude}:'
        '${identityHashCode(_pauseMarkerIcon)}:'
        '${identityHashCode(_resumeMarkerIcon)}';
    if (key == _markerCacheKey && _cachedMarkers != null) {
      return _cachedMarkers!;
    }

    final pauseIcon =
        _pauseMarkerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    final resumeIcon =
        _resumeMarkerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

    final markers = <Marker>{
      ..._session.autoPauses.asMap().entries.expand((entry) {
        final index = entry.key;
        final autoPause = entry.value;
        return [
          Marker(
            markerId: MarkerId('active_autopause_$index'),
            position: autoPause.location,
            icon: pauseIcon,
            infoWindow: InfoWindow(
              title: 'Autopausa #${index + 1}',
              snippet: 'Duração: ${autoPause.formattedDuration}',
            ),
          ),
          if (autoPause.resumeLocation != null)
            Marker(
              markerId: MarkerId('active_autoresume_$index'),
              position: autoPause.resumeLocation!,
              icon: resumeIcon,
              infoWindow: const InfoWindow(title: 'Retomada'),
            ),
        ];
      }),
      if (_session.isAutoPaused && anchor != null)
        Marker(
          markerId: const MarkerId('current_autopause'),
          position: anchor,
          icon: pauseIcon,
          infoWindow: const InfoWindow(title: 'Pausando...'),
        ),
    };
    _cachedMarkers = markers;
    _markerCacheKey = key;
    return markers;
  }

  /// Rota ao vivo colorida por ritmo. O acumulador incremental só processa o
  /// ponto novo; a análise completa é reservada para checkpoints de integridade.
  Set<Polyline> _buildRoutePolylines() {
    final route = _session.routePoints;
    final routeTimes = _session.routePointTimes;
    final total = route.fold<int>(0, (sum, segment) => sum + segment.length);
    final key = '$total:${_session.splits.length}:${_session.isFinished}';
    if (key == _routeCacheKey) return _cachedRoutePolylines;

    final now = DateTime.now();
    final canUseLiveTrace = _hasUsablePointTimes(route, routeTimes);
    final lastReconciliation = _lastLiveReconciliationAt;
    final liveReconciliationDue =
        lastReconciliation == null ||
        now.difference(lastReconciliation) >= const Duration(seconds: 30);
    final shouldReconcile =
        _session.isFinished ||
        _session.splits.length != _reconciledSplitCount ||
        route.length != _reconciledSegmentCount ||
        liveReconciliationDue;
    final PaceZoneResult result;

    if (canUseLiveTrace) {
      _syncLiveTrace(route, routeTimes);
      if (shouldReconcile) {
        result = _analyzeFullRoute();
        _reconciledSplitCount = _session.splits.length;
        _reconciledSegmentCount = route.length;
        _lastLiveReconciliationAt = now;
        _resetLiveTrace();
        _syncLiveTrace(route, routeTimes);
      } else {
        final runAvg = _session.distanceKm > 0 && _session.elapsedSeconds > 0
            ? _session.elapsedSeconds / _session.distanceKm
            : null;
        result = _livePaceTrace.build(
          centerSecPerKm: PaceZoneService.centerSecPerKm(
            runAvgSecPerKm: runAvg,
          ),
        );
      }
    } else {
      // Formato antigo sem tempos por ponto: mantém o fallback, mas limita
      // a reanálise para não repetir o custo antigo a cada fix.
      final last = _lastLegacyRouteAnalysisAt;
      final enoughPoints = total - _lastLegacyRoutePointCount >= 5;
      final enoughTime =
          last == null || now.difference(last) >= const Duration(seconds: 5);
      if (!shouldReconcile && !enoughPoints && !enoughTime) {
        _routeCacheKey = key;
        return _cachedRoutePolylines;
      }
      result = _analyzeFullRoute();
      _reconciledSplitCount = _session.splits.length;
      _reconciledSegmentCount = route.length;
      _lastLiveReconciliationAt = now;
      _lastLegacyRouteAnalysisAt = now;
      _lastLegacyRoutePointCount = total;
    }

    final polylines = <Polyline>{};
    for (var si = 0; si < result.segments.length; si++) {
      final segment = result.segments[si];
      final points = segment.points;
      if (points.isEmpty) continue;

      var block = 0;
      for (var start = 0; start < points.length; start += _pointsPerPolyline) {
        final end = (start + _pointsPerPolyline).clamp(0, points.length);
        final from = start == 0 ? 0 : start - 1;
        polylines.add(
          Polyline(
            polylineId: PolylineId('route_${si}_$block'),
            points: points.sublist(from, end),
            color: segment.color,
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
        block++;
      }
    }

    _cachedRoutePolylines = polylines;
    _routeCacheKey = key;
    return polylines;
  }

  PaceZoneResult _analyzeFullRoute() {
    return PaceZoneService.analyze(
      route: _session.routePoints,
      routeTimes: _session.routePointTimes,
      distanceKm: _session.distanceKm,
      durationSeconds: _session.elapsedSeconds,
      splits: _session.splits,
    );
  }

  bool _hasUsablePointTimes(
    List<List<LatLng>> route,
    List<List<int>> routeTimes,
  ) {
    if (routeTimes.length != route.length) return false;
    for (var i = 0; i < route.length; i++) {
      if (routeTimes[i].length != route[i].length) return false;
      if (route[i].length >= 2 &&
          routeTimes[i].every((time) => time == routeTimes[i].first)) {
        return false;
      }
    }
    return true;
  }

  void _syncLiveTrace(List<List<LatLng>> route, List<List<int>> routeTimes) {
    final counts = [for (final segment in route) segment.length];
    var restart = !_liveTraceInitialized;
    if (!restart && counts.length < _liveTracePointCounts.length) {
      restart = true;
    }
    if (!restart) {
      for (var i = 0; i < counts.length; i++) {
        final previous = i < _liveTracePointCounts.length
            ? _liveTracePointCounts[i]
            : 0;
        if (counts[i] < previous) {
          restart = true;
          break;
        }
      }
    }
    if (restart) _resetLiveTrace();

    for (var si = 0; si < route.length; si++) {
      final previous = si < _liveTracePointCounts.length
          ? _liveTracePointCounts[si]
          : 0;
      for (var pi = previous; pi < route[si].length; pi++) {
        _livePaceTrace.addPoint(
          route[si][pi],
          routeTimes[si][pi],
          startsNewSegment: pi == 0,
        );
      }
    }
    _liveTracePointCounts = counts;
    _liveTraceInitialized = true;
  }

  void _resetLiveTrace() {
    _livePaceTrace.reset();
    _liveTracePointCounts = [];
    _liveTraceInitialized = false;
  }

  void _onRunSessionEvent(RunSessionEvent event) {
    if (!mounted) return;
    switch (event) {
      case RunLocationReady(:final position):
        _centerMapInitially(position);
      case RunPositionUpdated(:final position):
        unawaited(_updateCamera(position));
      case RunAutoPauseStarted():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treino pausado automaticamente'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case RunAutoPauseResumed():
        _showAutoResumeSnackBar();
      case RunKilometerReached(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.trophy, color: AppColors.primaryNeon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
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
      case RunSessionError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _centerMapInitially(LatLng position) async {
    try {
      final controller = await _controller.future;
      if (!mounted) return;
      _lastCameraUpdateAt = DateTime.now();
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude - 0.002, position.longitude),
          16,
        ),
      );
    } catch (e) {
      debugPrint('Error centering map: $e');
    }
  }

  Future<void> _updateCamera(LatLng target) async {
    final now = DateTime.now();
    final last = _lastCameraUpdateAt;
    if (last != null && now.difference(last) < _cameraUpdateInterval) return;
    _lastCameraUpdateAt = now;
    try {
      final controller = await _controller.future;
      if (!mounted) return;
      await controller.animateCamera(CameraUpdate.newLatLng(target));
    } catch (e) {
      debugPrint('Error updating map camera: $e');
    }
  }

  Future<void> _startRun() async {
    await _session.start();
  }

  void _pauseRun() => _session.pause();

  void _resumeRun() => _session.resume();

  Future<void> _stopRun() async {
    _session.pause();
    final shouldStop = await showDialog<bool>(
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
    if (!mounted) return;
    if (shouldStop == true) {
      await _finalizeRun();
    } else {
      _session.resume();
    }
  }

  Future<void> _finalizeRun() async {
    final needsConfirmation = await _session.finish();
    if (needsConfirmation && mounted) {
      await _showShortRunWarning();
    }
  }

  Future<void> _showShortRunWarning() async {
    final shouldDiscard = await ActiveRunDialogs.showShortRunWarning(
      context,
      (_session.distanceKm * 1000).toInt(),
      _session.elapsedSeconds,
    );
    if (!mounted) return;

    if (shouldDiscard == true) {
      await _session.discardActiveRun();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    } else if (shouldDiscard == false) {
      // Preserva o snapshot finalizado. Nada é apagado antes do save real.
      await _session.finish(forceSave: true);
    }
  }

  void _handleBackPress() async {
    if (_session.canExit) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final shouldExit = await ActiveRunDialogs.showExitConfirmation(context);
    if (shouldExit == true && mounted) {
      await _session.suspendAndPersist();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    }
  }

  void _showGoalDialog() {
    ActiveRunDialogs.showGoalDialog(
      context,
      initialDistanceGoal: _session.distanceGoal,
      onGoalSet: (distance, targetTimeSeconds, pacingService) {
        _session.setGoal(
          distanceKm: distance,
          targetTimeSeconds: targetTimeSeconds,
          pacingService: pacingService,
        );
      },
      onNoGoal: () => _session.setGoal(
        distanceKm: null,
        targetTimeSeconds: null,
        pacingService: null,
      ),
    );
  }

  void _toggleMinimalMap() {
    setState(() => _showMinimalMap = !_showMinimalMap);
    unawaited(_saveMapPreference(_showMinimalMap));
  }

  void _lockScreen() {
    setState(() => _isScreenLocked = true);
    HapticFeedback.heavyImpact();
  }

  void _unlockScreen() {
    setState(() => _isScreenLocked = false);
  }

  Future<void> _discardFinishedRun() async {
    final confirmed = await ActiveRunDialogs.showDiscardConfirmation(context);
    if (confirmed != true || !mounted) return;
    await _session.discardActiveRun();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
  }

  Future<void> _saveRun() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final selectedType = await ActiveRunDialogs.showTrainingTypePicker(
        context,
      );
      if (!mounted) return;
      if (selectedType == null) {
        setState(() => _isSaving = false);
        return;
      }

      final selectedMood = await ActiveRunDialogs.showMoodPicker(context) ?? '';
      if (!mounted) return;

      final result = await _session.saveCompletedRun(
        type: selectedType,
        mood: selectedMood,
      );
      if (!mounted) return;

      context.read<RunsProvider>().notifyDataChanged(
        scopes: {DataScope.achievements},
      );

      String snackMessage = '';
      if (result.isPlanSuccessful) {
        snackMessage = 'SESSÃO DO PLANO CONCLUÍDA! 🎯';
      } else if (result.newAwards.isNotEmpty) {
        snackMessage =
            'PARABÉNS! Você ganhou ${result.newAwards.length} novas conquistas! 🏆';
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

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar o treino. Seus dados continuam salvos '
              'no aparelho — tente novamente.',
            ),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 6),
          ),
        );
      }
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

  /// Minimiza o treino: empurra o modo navegação por cima. O controller
  /// continua vivo na rota de baixo, contando e persistindo normalmente.
  void _minimizeRun() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RunBrowseScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeTopInset = MediaQuery.viewPaddingOf(context).top;

    return PopScope(
      canPop: _session.canExit,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _session.canExit) return;
        _handleBackPress();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            ListenableBuilder(
              listenable: _mapListenable,
              builder: (context, _) => ActiveRunMapView(
                isDark: isDark,
                hasPermissions: _session.hasPermissions,
                isFinished: _session.isFinished,
                isMapReady: _isMapReady,
                mapStyle: _getMapStyle(),
                safeTopInset: safeTopInset,
                distanceGoal: _session.distanceGoal,
                polylines: _buildRoutePolylines(),
                markers: _buildMapMarkers(),
                onMapCreated: (controller) {
                  _controller.complete(controller);
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (mounted) setState(() => _isMapReady = true);
                  });
                },
              ),
            ),
            ListenableBuilder(
              listenable: _session.stateChanges,
              builder: (context, _) => ActiveRunTopBar(
                isDark: isDark,
                isRunning: _session.isRunning,
                isPaused: _session.isPaused,
                isAutoPaused: _session.isAutoPaused,
                showMinimalMap: _showMinimalMap,
                autoPauseEnabled: _session.autoPauseEnabled,
                onBack: _handleBackPress,
                onMinimize: _minimizeRun,
                onToggleMinimalMap: _toggleMinimalMap,
                onToggleAutoPause: _toggleAutoPause,
                onLock: _lockScreen,
              ),
            ),
            // Só o painel escuta o tick; mapa e top bar usam canais próprios.
            ListenableBuilder(
              listenable: _panelListenable,
              builder: (context, _) => ActiveRunBottomPanel(
                isDark: isDark,
                isRunning: _session.isRunning,
                isPaused: _session.isPaused,
                isAutoPaused: _session.isAutoPaused,
                isFinished: _session.isFinished,
                isSaving: _isSaving,
                distanceKm: _session.distanceKm,
                distanceGoal: _session.distanceGoal,
                formattedTime: _session.formattedTime,
                pace: _session.pace,
                calories: _session.calories.toString(),
                eta: _session.eta,
                pausedSeconds: _session.pausedSeconds,
                pacingFeedback: _session.pacingFeedback,
                onStart: () => unawaited(_startRun()),
                onPause: _pauseRun,
                onResume: _resumeRun,
                onStop: () => unawaited(_stopRun()),
                onShowGoalDialog: _showGoalDialog,
                onDiscard: _discardFinishedRun,
                onSave: _saveRun,
              ),
            ),
            if (_isScreenLocked) ActiveRunLockOverlay(onUnlock: _unlockScreen),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    _themeService?.removeListener(_onThemeChanged);
    _session.dispose();
    super.dispose();
  }
}
