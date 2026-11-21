import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/theme/app_colors.dart';

enum _DrawMode { retas, desenhar }

/// Mapa de desenho de rota, reutilizado por "Editar Rota" e "Novo Treino".
///
/// Dois modos:
/// * **Retas** — toque por toque (segmentos retos), o modo clássico;
/// * **Desenhar** — arrasta o dedo acompanhando o caminho real; pontos são
///   capturados continuamente, com mínimo de ~8 m entre eles para não
///   inflar a rota. Enquanto desenha, a câmera fica travada — troque de
///   modo para navegar pelo mapa.
///
/// Ao confirmar, chama [onConfirm] com os pontos na ordem do traçado.
class RouteDrawingMap extends StatefulWidget {
  const RouteDrawingMap({
    super.key,
    required this.title,
    required this.onConfirm,
    this.confirmLabel = 'CONFIRMAR ROTA',
    this.initialPoints = const [],
    this.guideRoute = const [],
    this.busy = false,
  });

  final String title;
  final void Function(List<LatLng> points) onConfirm;
  final String confirmLabel;
  final List<LatLng> initialPoints;
  final List<List<LatLng>> guideRoute;
  final bool busy;

  /// Distância (km) ao longo dos pontos, pelo caminho mais curto entre eles.
  static double distanceKm(List<LatLng> points) {
    double meters = 0;
    for (int i = 1; i < points.length; i++) {
      meters += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return meters / 1000;
  }

  @override
  State<RouteDrawingMap> createState() => _RouteDrawingMapState();
}

class _RouteDrawingMapState extends State<RouteDrawingMap> {
  GoogleMapController? _mapController;
  String? _mapStyle;
  String? _minimalMapStyle;
  String? _darkMinimalMapStyle;
  ThemeService? _themeService;
  bool _isMapReady = false;

  _DrawMode _mode = _DrawMode.retas;
  final List<LatLng> _points = [];
  // Índice onde cada traço (toque ou arrasto) começa — alimenta o "desfazer".
  final List<int> _strokeStarts = [];
  bool _capturingPoint = false; // getLatLng em voo no modo desenhar

  static const LatLng _defaultTarget = LatLng(-23.5505, -46.6333);

  @override
  void initState() {
    super.initState();
    _points.addAll(widget.initialPoints);
    // Cada ponto herdado é um traço próprio: desfazer remove um por vez.
    for (var i = 0; i < _points.length; i++) {
      _strokeStarts.add(i);
    }
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
      _minimalMapStyle =
          await rootBundle.loadString('assets/map_style_minimal.json');
      _darkMinimalMapStyle =
          await rootBundle.loadString('assets/map_style_dark_minimal.json');

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

  // ── Câmera inicial ────────────────────────────────────────────────────

  void _frameInitialView() async {
    final controller = _mapController;
    if (controller == null) return;

    // 1) Rota-guia: enquadra os limites dela.
    final guide = widget.guideRoute;
    if (guide.isNotEmpty && guide.any((s) => s.isNotEmpty)) {
      double? minLat, minLng, maxLat, maxLng;
      for (var segment in guide) {
        for (var point in segment) {
          if (minLat == null || point.latitude < minLat) minLat = point.latitude;
          if (minLng == null || point.longitude < minLng) minLng = point.longitude;
          if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
          if (maxLng == null || point.longitude > maxLng) maxLng = point.longitude;
        }
      }

      if (minLat != null && minLng != null && maxLat != null && maxLng != null) {
        // Rota "pontual" (bounds vazios) quebra o newLatLngBounds — usa zoom direto.
        if ((maxLat - minLat).abs() < 0.00001 &&
            (maxLng - minLng).abs() < 0.00001) {
          controller.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 16));
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

    // 2) Sem guia: tenta a posição atual (silencioso se não houver permissão).
    try {
      final pos = await LocationService().getCurrentLocation();
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
        );
      }
    } catch (_) {
      // Sem permissão/GPS — mantém o alvo padrão.
    }
  }

  // ── Interação ─────────────────────────────────────────────────────────

  bool get _interactive => !widget.busy;

  void _addTapPoint(LatLng point) {
    if (!_interactive) return;
    setState(() {
      _strokeStarts.add(_points.length);
      _points.add(point);
    });
  }

  void _undoLastStroke() {
    if (_points.isEmpty || !_interactive) return;
    setState(() {
      if (_strokeStarts.isNotEmpty) {
        final start = _strokeStarts.removeLast();
        if (start < _points.length) _points.removeRange(start, _points.length);
      } else {
        _points.removeLast();
      }
    });
  }

  void _clearAll() {
    if (_points.isEmpty || !_interactive) return;
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
            style: GoogleFonts.outfit(
                color: cs.onSurface, fontWeight: FontWeight.bold),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() {
                  _points.clear();
                  _strokeStarts.clear();
                });
              },
              child: Text(
                'LIMPAR',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Modo "desenhar": captura o arrasto contínuo do dedo.

  void _onDrawStart(DragStartDetails details) {
    if (!_interactive) return;
    _strokeStarts.add(_points.length);
    _captureDrawnPoint(details.localPosition);
  }

  void _onDrawUpdate(DragUpdateDetails details) {
    if (!_interactive) return;
    _captureDrawnPoint(details.localPosition);
  }

  /// Converte a posição lógica do dedo em LatLng. O getLatLng do
  /// google_maps_flutter espera pixels FÍSICOS na plataforma nativa —
  /// sem o devicePixelRatio o ponto cai longe de onde o dedo toca.
  Future<void> _captureDrawnPoint(Offset position) async {
    if (_capturingPoint) return;
    final controller = _mapController;
    if (controller == null) return;

    _capturingPoint = true;
    try {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final latLng = await controller.getLatLng(
        ScreenCoordinate(
          x: (position.dx * dpr).round(),
          y: (position.dy * dpr).round(),
        ),
      );
      if (!mounted) return;
      final last = _points.isEmpty ? null : _points.last;
      final tooClose = last != null &&
          Geolocator.distanceBetween(
                last.latitude,
                last.longitude,
                latLng.latitude,
                latLng.longitude,
              ) <
              8;
      if (!tooClose) {
        setState(() => _points.add(latLng));
      }
    } catch (_) {
      // getLatLng pode falhar durante transições de câmera — ignora.
    } finally {
      _capturingPoint = false;
    }
  }

  void _confirm() {
    if (_points.length < 2 || !_interactive) return;
    widget.onConfirm(_points.toList());
  }

  void _zoomIn() => _mapController?.animateCamera(CameraUpdate.zoomIn());

  void _zoomOut() => _mapController?.animateCamera(CameraUpdate.zoomOut());

  // ── UI ────────────────────────────────────────────────────────────────

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
      // Rota-guia — esmaecida e tracejada (rota original na edição).
      ...widget.guideRoute.asMap().entries.map((entry) {
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

  Widget _buildModeToggle(ColorScheme cs, bool isDark) {
    Widget pill(_DrawMode mode, IconData icon, String label) {
      final selected = _mode == mode;
      return GestureDetector(
        onTap: _interactive ? () => setState(() => _mode = mode) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color:
                      selected ? cs.onPrimary : cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: selected ? cs.onPrimary : cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF162222) : Colors.white)
              .withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            pill(_DrawMode.retas, LucideIcons.navigation, 'Retas'),
            pill(_DrawMode.desenhar, LucideIcons.pencil, 'Desenhar'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ColorScheme cs, bool isDark, double drawnKm) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF162222) : Colors.white)
              .withValues(alpha: 0.95),
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
                    ? (_mode == _DrawMode.retas
                        ? 'Toque no mapa para marcar sua rota'
                        : 'Arraste o dedo para desenhar o caminho')
                    : '${_points.length} ponto${_points.length == 1 ? '' : 's'}'
                        ' · ${drawnKm.toStringAsFixed(2)} km',
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

  Widget _buildZoomButton(
    ColorScheme cs,
    bool isDark,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF162222) : Colors.white)
              .withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
          ],
        ),
        child: Icon(icon, size: 20, color: cs.onSurface),
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
          color:
              enabled ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawnKm = RouteDrawingMap.distanceKm(_points);
    final canConfirm = _points.length >= 2 && _interactive;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
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
            onTap:
                _mode == _DrawMode.retas && _interactive ? _addTapPoint : null,
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

          // Modo desenhar: captura o arrasto por cima do mapa. A câmera fica
          // travada durante o traço — troque para "Retas" para navegar.
          if (_mode == _DrawMode.desenhar)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onDrawStart,
                onPanUpdate: _onDrawUpdate,
              ),
            ),

          // Topo: seletor de modo + chip de status
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _buildModeToggle(cs, isDark),
                const SizedBox(height: 8),
                _buildStatusChip(cs, isDark, drawnKm),
              ],
            ),
          ),

          // Zoom manual durante o desenho: a pinça fica bloqueada pelo
          // overlay de captura do traço. No modo Retas, pinça nativa.
          if (_mode == _DrawMode.desenhar)
            Positioned(
              top: 0,
              bottom: 0,
              right: 12,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildZoomButton(cs, isDark, LucideIcons.plus, _zoomIn),
                    const SizedBox(height: 12),
                    _buildZoomButton(cs, isDark, LucideIcons.minus, _zoomOut),
                  ],
                ),
              ),
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
                  enabled: _points.isNotEmpty && _interactive,
                  onTap: _undoLastStroke,
                ),
                const SizedBox(width: 12),
                _buildCircleAction(
                  icon: LucideIcons.eraser,
                  enabled: _points.isNotEmpty && _interactive,
                  onTap: _clearAll,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: canConfirm ? _confirm : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: canConfirm
                            ? cs.primary
                            : cs.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: canConfirm
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
                            widget.confirmLabel,
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
