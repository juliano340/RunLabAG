import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/utils/time_utils.dart';
import '../../domain/models/run_model.dart';

class FullMapScreen extends StatefulWidget {
  final RunModel run;

  const FullMapScreen({super.key, required this.run});

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  GoogleMapController? _mapController;
  String? _mapStyle;
  String? _minimalMapStyle;
  String? _darkMinimalMapStyle;
  ThemeService? _themeService;
  bool _isMapReady = false;
  MapType _currentMapType = MapType.normal;
  bool _showCustomStyle = true;

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
    if (!_showCustomStyle) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _darkMinimalMapStyle : _minimalMapStyle;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _recenterRoute() {
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
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
      }
    }
  }

  void _cycleMapType() {
    setState(() {
      if (_currentMapType == MapType.normal && _showCustomStyle) {
        // Standard normal map without minimal style
        _showCustomStyle = false;
      } else if (!_showCustomStyle && _currentMapType == MapType.normal) {
        // Satellite mode
        _currentMapType = MapType.satellite;
      } else if (_currentMapType == MapType.satellite) {
        // Terrain mode
        _currentMapType = MapType.terrain;
      } else {
        // Back to minimal standard map
        _currentMapType = MapType.normal;
        _showCustomStyle = true;
      }
      _mapStyle = _getMapStyleString();
    });
  }

  String _getMapTypeLabel() {
    if (_currentMapType == MapType.satellite) return 'Satélite';
    if (_currentMapType == MapType.terrain) return 'Relevo';
    if (!_showCustomStyle) return 'Padrão';
    return 'Minimalista';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fullscreen Google Map
          GoogleMap(
            style: _mapStyle,
            mapType: _currentMapType,
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
            },
            polylines: widget.run.route.asMap().entries.map((entry) {
              return Polyline(
                polylineId: PolylineId('full_route_${entry.key}'),
                points: entry.value,
                color: _currentMapType == MapType.satellite ? Colors.amberAccent : AppColors.primaryNeon,
                width: 6,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              );
            }).toSet(),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              _recenterRoute();
              Future.delayed(const Duration(milliseconds: 150), () {
                if (mounted) {
                  setState(() => _isMapReady = true);
                }
              });
            },
          ),

          // Cobertura anti-flash
          if (!_isMapReady && isDark)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: const Color(0xFF1d2c2c)),
              ),
            ),

          // Gradient Top Shadow for status bar and header readable text
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                  ),
                  child: IconButton(
                    icon: Icon(LucideIcons.arrowLeft, color: isDark ? Colors.white : Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mapa do Percurso',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(widget.run.date),
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNeon.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.run.type.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Floating Stats Overlay
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 16,
            right: 80, // Leave room for control buttons
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF162222).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricChip(
                    context,
                    label: 'DISTÂNCIA',
                    value: '${widget.run.distanceKm.toStringAsFixed(2)} km',
                    icon: LucideIcons.mapPin,
                  ),
                  Container(height: 30, width: 1, color: cs.outline.withValues(alpha: 0.2)),
                  _buildMetricChip(
                    context,
                    label: 'TEMPO',
                    value: TimeUtils.formatDuration(widget.run.durationSeconds),
                    icon: LucideIcons.timer,
                  ),
                  Container(height: 30, width: 1, color: cs.outline.withValues(alpha: 0.2)),
                  _buildMetricChip(
                    context,
                    label: 'PACE',
                    value: '${widget.run.pace}/km',
                    icon: LucideIcons.zap,
                  ),
                ],
              ),
            ),
          ),

          // Floating Controls (Right Side)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Map style toggle button
                GestureDetector(
                  onTap: _cycleMapType,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162222).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Tooltip(
                      message: _getMapTypeLabel(),
                      child: Icon(
                        _currentMapType == MapType.satellite ? LucideIcons.globe : LucideIcons.layers,
                        color: AppColors.primaryNeon,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Recenter button
                GestureDetector(
                  onTap: _recenterRoute,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNeon,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryNeon.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.crosshair,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(BuildContext context, {required String label, required String value, required IconData icon}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primaryNeon),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}
