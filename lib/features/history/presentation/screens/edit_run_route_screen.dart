import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../run/domain/services/run_metrics_service.dart';

/// Tela para editar a rota de um treino já registrado.
///
/// O usuário toca no mapa para marcar os pontos da rota que fez e a linha
/// é traçada ao vivo. Ao salvar, um diálogo pergunta se a distância, o pace
/// e as calorias do treino devem ser recalculados com base na rota desenhada.
/// A rota original (se existir) fica visível como guia esmaecida.
class EditRunRouteScreen extends StatefulWidget {
  final RunModel run;

  const EditRunRouteScreen({super.key, required this.run});

  @override
  State<EditRunRouteScreen> createState() => _EditRunRouteScreenState();
}

class _EditRunRouteScreenState extends State<EditRunRouteScreen> {
  GoogleMapController? _mapController;
  String? _mapStyle;
  String? _minimalMapStyle;
  String? _darkMinimalMapStyle;
  ThemeService? _themeService;
  bool _isMapReady = false;
  bool _isSaving = false;

  /// Pontos marcados pelo usuário — a nova rota.
  final List<LatLng> _points = [];

  static const LatLng _defaultTarget = LatLng(-23.5505, -46.6333);

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
      debugPrint('Error loading map style: $e');
    }
  }

  String? _getMapStyleString() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _darkMinimalMapStyle : _minimalMapStyle;
  }

  // ── Interação com a rota ──────────────────────────────────────────────

  void _addPoint(LatLng point) {
    setState(() => _points.add(point));
  }

  void _undoLastPoint() {
    if (_points.isEmpty || _isSaving) return;
    setState(() => _points.removeLast());
  }

  void _clearAll() {
    if (_points.isEmpty || _isSaving) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
          ),
          title: Text(
            'Limpar pontos?',
            style: GoogleFonts.outfit(color: cs.onSurface, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Todos os pontos marcados serão removidos e você poderá começar novamente.',
            style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'CANCELAR',
                style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(_points.clear);
              },
              child: Text(
                'LIMPAR',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  double _calcDrawnDistanceKm() {
    double meters = 0;
    for (int i = 1; i < _points.length; i++) {
      meters += Geolocator.distanceBetween(
        _points[i - 1].latitude,
        _points[i - 1].longitude,
        _points[i].latitude,
        _points[i].longitude,
      );
    }
    return meters / 1000;
  }

  // ── Câmera inicial ────────────────────────────────────────────────────

  void _frameInitialView() async {
    final controller = _mapController;
    if (controller == null) return;

    // 1) Se o treino já tem rota, enquadra os limites dela.
    final route = widget.run.route;
    if (route.isNotEmpty && route.any((s) => s.isNotEmpty)) {
      double? minLat, minLng, maxLat, maxLng;
      for (var segment in route) {
        for (var point in segment) {
          if (minLat == null || point.latitude < minLat) minLat = point.latitude;
          if (minLng == null || point.longitude < minLng) minLng = point.longitude;
          if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
          if (maxLng == null || point.longitude > maxLng) maxLng = point.longitude;
        }
      }

      if (minLat != null && minLng != null && maxLat != null && maxLng != null) {
        // Rota "pontual" (bounds vazios) quebra o newLatLngBounds — usa zoom direto.
        if ((maxLat - minLat).abs() < 0.00001 && (maxLng - minLng).abs() < 0.00001) {
          controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 16));
        } else {
          final bounds = LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          );
          controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
        }
      }
      return;
    }

    // 2) Sem rota: tenta a posição atual (silencioso se não houver permissão).
    try {
      final pos = await LocationService().getCurrentLocation();
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
        );
      }
    } catch (_) {
      // Sem permissão/GPS — mantém o alvo padrão.
    }
  }

  // ── Salvamento ────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_points.length < 2 || _isSaving) return;
    setState(() => _isSaving = true);

    final drawnKm = _calcDrawnDistanceKm();
    var updated = widget.run.copyWith(route: [_points.toList()]);
    var didUpdateMetrics = false;

    if (drawnKm > 0) {
      final shouldUpdate = await _askUpdateMetrics(drawnKm);
      if (shouldUpdate == true) {
        final profile = await DatabaseService().getUserProfile();
        final newPace = RunMetricsService.calculatePace(widget.run.durationSeconds, drawnKm);
        final newCalories = (profile != null && profile.weight > 0)
            ? RunMetricsService.calculateCalories(drawnKm, profile.weight)
            : updated.calories;
        updated = updated.copyWith(
          distanceKm: drawnKm,
          pace: newPace,
          calories: newCalories,
        );
        didUpdateMetrics = true;
      }
    }

    try {
      await DatabaseService().saveRun(updated);
      unawaited(BackupService().runAutoBackupIfEnabled());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            didUpdateMetrics ? 'Rota e métricas atualizadas!' : 'Rota atualizada!',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.primaryNeonDark,
        ),
      );
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao salvar a rota. Tente novamente.', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<bool?> _askUpdateMetrics(double drawnKm) {
    final newPace = RunMetricsService.calculatePace(widget.run.durationSeconds, drawnKm);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
          ),
          title: Text(
            'Atualizar métricas?',
            style: GoogleFonts.outfit(color: cs.onSurface, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rota desenhada: ${drawnKm.toStringAsFixed(2)} km',
                style: GoogleFonts.outfit(color: cs.onSurface, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Distância registrada: ${widget.run.distanceKm.toStringAsFixed(2)} km',
                style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(
                'Ao atualizar, a distância, o pace (${widget.run.pace}/km → $newPace/km) e as calorias serão recalculados com base na rota desenhada.',
                style: GoogleFonts.outfit(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'MANTER REGISTRADO',
                style: GoogleFonts.outfit(color: cs.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'ATUALIZAR',
                style: GoogleFonts.outfit(color: cs.onPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  Set<Marker> _buildMarkers() {
    return {
      if (_points.isNotEmpty)
        Marker(
          markerId: const MarkerId('draw_start'),
          position: _points.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Início'),
        ),
      if (_points.length >= 2)
        Marker(
          markerId: const MarkerId('draw_end'),
          position: _points.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Fim'),
        ),
    };
  }

  Set<Polyline> _buildPolylines(ColorScheme cs) {
    return {
      // Rota original — guia esmaecida e tracejada.
      ...widget.run.route.asMap().entries.map((entry) {
        return Polyline(
          polylineId: PolylineId('guide_${entry.key}'),
          points: entry.value,
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          width: 4,
          patterns: [PatternItem.dash(15), PatternItem.gap(10)],
        );
      }),
      // Rota desenhada pelo usuário.
      if (_points.length >= 2)
        Polyline(
          polylineId: const PolylineId('drawn'),
          points: _points,
          color: AppColors.primaryNeon,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };
  }

  Widget _buildStatusChip(ColorScheme cs, bool isDark, double drawnKm) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF162222) : Colors.white).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.mapPin, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _points.isEmpty
                    ? 'Toque no mapa para marcar sua rota'
                    : '${_points.length} ponto${_points.length == 1 ? '' : 's'} · ${drawnKm.toStringAsFixed(2)} km',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF162222) : Colors.white)
              .withValues(alpha: enabled ? 0.95 : 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawnKm = _calcDrawnDistanceKm();
    final canSave = _points.length >= 2 && !_isSaving;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Editar Rota',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            style: _mapStyle,
            initialCameraPosition: const CameraPosition(
              target: _defaultTarget,
              zoom: 15,
            ),
            markers: _buildMarkers(),
            polylines: _buildPolylines(cs),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onTap: _isSaving ? null : _addPoint,
            onMapCreated: (controller) {
              _mapController = controller;
              _frameInitialView();
              Future.delayed(const Duration(milliseconds: 150), () {
                if (mounted) {
                  setState(() => _isMapReady = true);
                }
              });
            },
          ),

          // Anti-flash cover (dark mode)
          if (!_isMapReady && isDark)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: const Color(0xFF1d2c2c)),
              ),
            ),

          // Chip de status
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _buildStatusChip(cs, isDark, drawnKm),
          ),

          // Barra de ações
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Row(
              children: [
                _buildCircleAction(
                  icon: LucideIcons.undo2,
                  enabled: _points.isNotEmpty && !_isSaving,
                  onTap: _undoLastPoint,
                ),
                const SizedBox(width: 12),
                _buildCircleAction(
                  icon: LucideIcons.eraser,
                  enabled: _points.isNotEmpty && !_isSaving,
                  onTap: _clearAll,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: canSave ? _save : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: canSave
                            ? cs.primary
                            : cs.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: canSave
                            ? [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.check, size: 16, color: cs.onPrimary),
                          const SizedBox(width: 8),
                          Text(
                            'SALVAR ROTA',
                            style: GoogleFonts.outfit(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
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
}
