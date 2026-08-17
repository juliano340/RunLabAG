import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/services/backup_service.dart';
import '../../../run/presentation/widgets/metric_card.dart';
import '../../../run/presentation/screens/run_share_screen.dart';
import '../../../../core/utils/time_utils.dart';
import 'full_map_screen.dart';

class RunDetailScreen extends StatefulWidget {
  final RunModel run;

  const RunDetailScreen({super.key, required this.run});

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<RunDetailScreen> {
  GoogleMapController? _mapController;
  String? _mapStyle;
  String? _minimalMapStyle;
  String? _darkMinimalMapStyle;
  ThemeService? _themeService;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
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
    setState(() {
      _mapStyle = _getMapStyleString();
    });
  }

  @override
  void dispose() {
    _themeService?.removeListener(_onThemeChanged);
    _mapController?.dispose();
    super.dispose();
  }

  void _loadMapStyle() async {
    try {
      _minimalMapStyle = await rootBundle.loadString('assets/map_style_minimal.json');
      _darkMinimalMapStyle = await rootBundle.loadString('assets/map_style_dark_minimal.json');

      if (mounted) {
        setState(() {
          _mapStyle = _getMapStyleString();
        });
      }
    } catch (e) {
      debugPrint("Error loading map style: $e");
    }
  }

  String? _getMapStyleString() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _darkMinimalMapStyle : _minimalMapStyle;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    return TimeUtils.formatDuration(seconds);
  }

  void _recenterMap() {
    if (_mapController == null) return;
    if (widget.run.route.isNotEmpty && widget.run.route.any((s) => s.isNotEmpty)) {
      double? minLat, minLng, maxLat, maxLng;
      for (var segment in widget.run.route) {
        for (var point in segment) {
          if (minLat == null || point.latitude < minLat) minLat = point.latitude;
          if (minLng == null || point.longitude < minLng) minLng = point.longitude;
          if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
          if (maxLng == null || point.longitude > maxLng) maxLng = point.longitude;
        }
      }

      if (minLat != null && minLng != null && maxLat != null && maxLng != null) {
        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }
    }
  }

  void _showSplitsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'VOLTAS (KM)',
                style: GoogleFonts.outfit(
                  color: cs.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(flex: 1, child: Text('KM', style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 12))),
                              Expanded(flex: 2, child: Text('TEMPO', style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 12))),
                              Expanded(flex: 2, child: Text('RITMO', style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 12))),
                              Expanded(flex: 1, child: Text('KCAL', style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 12), textAlign: TextAlign.right)),
                            ],
                          ),
                        ),
                        Divider(color: cs.outline.withValues(alpha: 0.2), height: 1),
                        ...List.generate(widget.run.splits.length, (index) {
                          final split = widget.run.splits[index];
                          final splitTime = split.timeSeconds;
                          final minutes = splitTime ~/ 60;
                          final seconds = splitTime % 60;
                          final paceStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15), width: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 1, child: Text('${index + 1}', style: GoogleFonts.outfit(color: cs.onSurface, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text(_formatDuration(splitTime), style: GoogleFonts.outfit(color: cs.onSurface))),
                                Expanded(flex: 2, child: Text('$paceStr/km', style: GoogleFonts.outfit(color: cs.primary, fontWeight: FontWeight.w600))),
                                Expanded(flex: 1, child: Text('${split.calories}', style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 13), textAlign: TextAlign.right)),
                              ],
                            ),
                          );
                        }),

                        if (widget.run.distanceKm > widget.run.splits.length + 0.01) (() {
                          final remainingDist = widget.run.distanceKm - widget.run.splits.length;
                          final consumedTime = widget.run.splits.fold(0, (sum, s) => sum + s.timeSeconds);
                          final remainingTime = (widget.run.durationSeconds - consumedTime).clamp(0, widget.run.durationSeconds);
                          final consumedCals = widget.run.splits.fold(0, (sum, s) => sum + s.calories);
                          final remainingCals = (widget.run.calories - consumedCals).clamp(0, widget.run.calories);

                          String partialPace = '--:--';
                          if (remainingDist > 0 && remainingTime > 0) {
                            double paceInMinutes = (remainingTime / 60) / remainingDist;
                            int mins = paceInMinutes.toInt();
                            int secs = ((paceInMinutes - mins) * 60).toInt();
                            partialPace = '$mins:${secs.toString().padLeft(2, '0')}';
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.03)),
                            child: Row(
                              children: [
                                Expanded(flex: 1, child: Text('RESTO', style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('${remainingDist.toStringAsFixed(2)} km', style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 13))),
                                Expanded(flex: 2, child: Text('$partialPace/km', style: GoogleFonts.outfit(color: cs.primary.withValues(alpha: 0.8), fontSize: 13))),
                                Expanded(flex: 1, child: Text('$remainingCals', style: GoogleFonts.outfit(color: Colors.orangeAccent.withValues(alpha: 0.8), fontSize: 13), textAlign: TextAlign.right)),
                              ],
                            ),
                          );
                        })(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAutoPausesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final totalAutoPauseSeconds = widget.run.autoPauses.fold(0, (sum, ap) => sum + ap.durationSeconds);
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.pauseCircle, color: Colors.amberAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'AUTOPAUSAS (${widget.run.autoPauses.length})',
                    style: GoogleFonts.outfit(
                      color: cs.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tempo total em autopausa: ${_formatDuration(totalAutoPauseSeconds)}',
                style: GoogleFonts.outfit(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(flex: 1, child: Text('#', style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold))),
                              Expanded(flex: 3, child: Text('DURAÇÃO DA PAUSA', style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('AÇÃO', style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                            ],
                          ),
                        ),
                        Divider(color: cs.outline.withValues(alpha: 0.2), height: 1),
                        ...List.generate(widget.run.autoPauses.length, (index) {
                          final autoPause = widget.run.autoPauses[index];

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15), width: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        autoPause.formattedDuration,
                                        style: GoogleFonts.outfit(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      if (autoPause.timestamp.isNotEmpty)
                                        Text(
                                          'Início: ${_formatDate(DateTime.tryParse(autoPause.timestamp) ?? DateTime.now())}',
                                          style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _mapController?.animateCamera(
                                        CameraUpdate.newLatLngZoom(autoPause.location, 17),
                                      );
                                    },
                                    icon: const Icon(LucideIcons.mapPin, size: 14, color: Colors.amberAccent),
                                    label: Text(
                                      'IR AO MAPA',
                                      style: GoogleFonts.outfit(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Treino de ${_formatDate(widget.run.date)}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.share2, color: cs.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RunShareScreen(run: widget.run),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map View showing the route with expanded height & action controls
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                GoogleMap(
                  style: _mapStyle,
                  initialCameraPosition: CameraPosition(
                    target: (widget.run.route.isNotEmpty && widget.run.route.first.isNotEmpty) 
                        ? widget.run.route.first.first 
                        : const LatLng(-23.5505, -46.6333),
                    zoom: 15,
                  ),
                  markers: {
                    if (widget.run.route.isNotEmpty && widget.run.route.first.isNotEmpty)
                      Marker(
                        markerId: const MarkerId('start'),
                        position: widget.run.route.first.first,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        infoWindow: const InfoWindow(title: 'Início'),
                      ),
                    if (widget.run.route.isNotEmpty && widget.run.route.last.isNotEmpty)
                      Marker(
                        markerId: const MarkerId('finish'),
                        position: widget.run.route.last.last,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        infoWindow: const InfoWindow(title: 'Chegada'),
                      ),
                    ...widget.run.autoPauses.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ap = entry.value;
                      return Marker(
                        markerId: MarkerId('marker_autopause_$idx'),
                        position: ap.location,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                        infoWindow: InfoWindow(
                          title: 'Autopausa #${idx + 1}',
                          snippet: 'Duração: ${ap.formattedDuration}',
                        ),
                      );
                    }),
                  },
                  circles: widget.run.autoPauses.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final ap = entry.value;
                    return Circle(
                      circleId: CircleId('detail_circle_autopause_$idx'),
                      center: ap.location,
                      radius: 20.0,
                      fillColor: Colors.amberAccent.withValues(alpha: 0.35),
                      strokeColor: Colors.amberAccent,
                      strokeWidth: 2,
                    );
                  }).toSet(),
                  polylines: widget.run.route.asMap().entries.map((entry) {
                    return Polyline(
                      polylineId: PolylineId('route_${entry.key}'),
                      points: entry.value,
                      color: AppColors.primaryNeon,
                      width: 5,
                      startCap: Cap.roundCap,
                      endCap: Cap.roundCap,
                    );
                  }).toSet(),
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _recenterMap();
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (mounted) {
                        setState(() => _isMapReady = true);
                      }
                    });
                  },
                ),

                // Gradient Overlay to blend with app background
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.transparent,
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                        stops: const [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),

                // Anti-flash cover
                if (!_isMapReady && isDark)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(color: const Color(0xFF1d2c2c)),
                    ),
                  ),

                // Floating Action Controls on top of map (Recenter & Expand Map)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _recenterMap,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF162222).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                            ],
                          ),
                          child: Icon(LucideIcons.crosshair, size: 18, color: cs.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullMapScreen(run: widget.run),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: cs.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.maximize2, size: 14, color: cs.onPrimary),
                              const SizedBox(width: 6),
                              Text(
                                'EXPANDIR MAPA',
                                style: GoogleFonts.outfit(
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Metrics Panel in Scrollable Sheet Container
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle visual indicator
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: (widget.run.type == 'Caminhada'
                                    ? Colors.blueAccent
                                    : widget.run.type == 'Corrida/Caminhada'
                                        ? Colors.orangeAccent
                                        : cs.primary)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (widget.run.type == 'Caminhada'
                                      ? Colors.blueAccent
                                      : widget.run.type == 'Corrida/Caminhada'
                                          ? Colors.orangeAccent
                                          : cs.primary)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.run.type == 'Caminhada'
                                    ? LucideIcons.footprints
                                    : widget.run.type == 'Corrida/Caminhada'
                                        ? LucideIcons.timer
                                        : LucideIcons.zap,
                                color: widget.run.type == 'Caminhada'
                                    ? Colors.blueAccent
                                    : widget.run.type == 'Corrida/Caminhada'
                                        ? Colors.orangeAccent
                                        : cs.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.run.type.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: widget.run.type == 'Caminhada'
                                      ? Colors.blueAccent
                                      : widget.run.type == 'Corrida/Caminhada'
                                          ? Colors.orangeAccent
                                          : cs.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (widget.run.mood.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(widget.run.mood, style: const TextStyle(fontSize: 32)),
                                const SizedBox(width: 12),
                                Text(
                                  widget.run.mood == '😣' ? 'Ruim'
                                      : widget.run.mood == '😐' ? 'Médio'
                                      : widget.run.mood == '🙂' ? 'Bom'
                                      : 'Excelente',
                                  style: GoogleFonts.outfit(
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: MetricCard(
                                label: 'Distância',
                                value: widget.run.distanceKm.toStringAsFixed(2),
                                unit: 'km',
                              ),
                            ),
                            Expanded(
                              child: MetricCard(
                                label: 'Tempo',
                                value: _formatDuration(widget.run.durationSeconds),
                                unit: 'min',
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
                                label: 'Pace Médio',
                                value: widget.run.pace,
                                unit: '/km',
                              ),
                            ),
                            Expanded(
                              child: MetricCard(
                                label: 'Calorias',
                                value: widget.run.calories.toString(),
                                unit: 'kcal',
                              ),
                            ),
                          ],
                        ),
                        if (widget.run.pausedDurationSeconds > 0) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: MetricCard(
                                  label: 'Tempo Total',
                                  value: _formatDuration(
                                    widget.run.durationSeconds +
                                        widget.run.pausedDurationSeconds,
                                  ),
                                  unit: 'min',
                                ),
                              ),
                              Expanded(
                                child: MetricCard(
                                  label: 'Tempo Pausado',
                                  value: _formatDuration(widget.run.pausedDurationSeconds),
                                  unit: 'min',
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        
                        if (widget.run.splits.isNotEmpty || widget.run.autoPauses.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                if (widget.run.splits.isNotEmpty)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                      side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    onPressed: _showSplitsModal,
                                    icon: Icon(LucideIcons.list, color: cs.primary, size: 18),
                                    label: Text(
                                      'VER VOLTAS',
                                      style: GoogleFonts.outfit(
                                        color: cs.primary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                if (widget.run.autoPauses.isNotEmpty)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.6)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    onPressed: _showAutoPausesModal,
                                    icon: const Icon(LucideIcons.pauseCircle, color: Colors.amberAccent, size: 18),
                                    label: Text(
                                      'AUTOPAUSAS (${widget.run.autoPauses.length})',
                                      style: GoogleFonts.outfit(
                                        color: Colors.amberAccent,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: cs.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(LucideIcons.check, color: cs.onPrimary),
                            label: Text(
                              'VOLTAR',
                              style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.error, width: 1),
          ),
          title: Text(
            'Excluir Treino?',
            style: GoogleFonts.outfit(color: cs.onSurface, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Esta ação não pode ser desfeita. Deseja realmente remover este registro?',
            style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCELAR', style: GoogleFonts.outfit(color: cs.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final dbService = DatabaseService();
                await dbService.deleteRun(widget.run.id);

                // Atualiza backup automático após exclusão. Falha silencioso.
                unawaited(BackupService().runAutoBackupIfEnabled());

                if (context.mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to history
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Treino excluído com sucesso.', style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: Text(
                'EXCLUIR',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
