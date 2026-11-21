import 'dart:async';
import 'dart:math' as math;

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
/// * **Desenhar** — um dedo traça o caminho real (pontos a cada ~8 m);
///   dois dedos fazem pan e pinça da câmera sem sair do modo. Segure o
///   botão de desfazer para rebobinar o traço ponto a ponto.
///
/// Ao confirmar, chama [onConfirm] com os pontos na ordem do traçado e um
/// flag indicando se o traçado deve ser **somado** à rota-guia (modo
/// "Adicionar trecho", usado na edição para completar pedaços que o GPS
/// não registrou) ou **substituí-la** (refazer do zero).
class RouteDrawingMap extends StatefulWidget {
  const RouteDrawingMap({
    super.key,
    required this.title,
    required this.onConfirm,
    this.confirmLabel = 'CONFIRMAR ROTA',
    this.initialPoints = const [],
    this.guideRoute = const [],
    this.busy = false,
    this.allowAppend = false,
    this.appendConfirmLabel,
  });

  final String title;

  /// [appendToGuide] = true → o traçado é SOMADO à [guideRoute] (novo
  /// segmento); false → substitui.
  final void Function(List<LatLng> points, bool appendToGuide) onConfirm;
  final String confirmLabel;
  final List<LatLng> initialPoints;
  final List<List<LatLng>> guideRoute;
  final bool busy;

  /// Habilita o seletor "Adicionar trecho / Refazer": com rota-guia
  /// presente, o traçado pode ser somado a ela em vez de substituí-la.
  final bool allowAppend;

  /// Rótulo do botão de confirmar no modo adicionar (ex.: 'ADICIONAR TRECHO').
  final String? appendConfirmLabel;

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

  /// Modo da edição: somar o traçado à rota-guia (true) ou substituí-la.
  late bool _appendMode = widget.allowAppend;
  bool _capturingPoint = false; // getLatLng em voo no modo desenhar

  // Pan/pinça com dois dedos durante o desenho.
  double _lastScale = 1.0;
  Offset? _lastFocalPoint;

  // Momento do último frame com >= 2 dedos. Desenhar só retoma 500 ms
  // depois — senão o dedo remanescente da pinça desenharia ao soltá-la.
  DateTime? _lastTwoFingerAt;

  // Segurar o botão de desfazer rebobina o traço.
  Timer? _undoTimer;

  static const LatLng _defaultTarget = LatLng(-23.5505, -46.6333);

  @override
  void initState() {
    super.initState();
    _points.addAll(widget.initialPoints);
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
    _undoTimer?.cancel();
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
    setState(() => _points.add(point));
  }

  /// Desfazer aos pouquinhos: um ponto por toque; segurando, rebobina.
  void _undoLastPoint() {
    if (_points.isEmpty || !_interactive) return;
    setState(() => _points.removeLast());
  }

  void _startUndoHold() {
    if (!_interactive) return;
    _undoLastPoint();
    _undoTimer?.cancel();
    _undoTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (mounted && _points.isNotEmpty && _interactive) {
        setState(() => _points.removeLast());
      }
    });
  }

  void _stopUndoHold() {
    _undoTimer?.cancel();
    _undoTimer = null;
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
                setState(_points.clear);
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

  // Modo "desenhar": um dedo traça; dois dedos controlam a câmera.

  void _onScaleStart(ScaleStartDetails details) {
    if (!_interactive) return;
    // O recognizer re-dispara onStart a cada mudança de dedos no meio do
    // gesto — não confiamos nele. A decisão vem do pointerCount por update.
    _lastScale = 1.0;
    _lastFocalPoint = details.focalPoint;
    if (details.pointerCount >= 2) {
      _lastTwoFingerAt = DateTime.now();
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_interactive) return;
    final controller = _mapController;
    if (controller == null) return;

    if (details.pointerCount >= 2) {
      _lastTwoFingerAt = DateTime.now();
      // Pinça: zoom incremental pela variação da escala.
      final incremental = details.scale / _lastScale;
      _lastScale = details.scale;
      final zoomDelta = math.log(incremental) / math.ln2;
      if (zoomDelta.abs() > 0.001) {
        controller.moveCamera(CameraUpdate.zoomBy(zoomDelta));
      }

      // Pan: o mapa segue na direção oposta ao movimento do ponto focal.
      final delta =
          details.focalPoint - (_lastFocalPoint ?? details.focalPoint);
      _lastFocalPoint = details.focalPoint;
      if (delta.distance > 0.5) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        controller.moveCamera(CameraUpdate.scrollBy(
          -delta.dx * dpr,
          -delta.dy * dpr,
        ));
      }
      return;
    }

    // Um dedo logo após um gesto de dois: cooldown evita pontos fantasma
    // enquanto os dedos estão transicionando (re-disparos de onStart,
    // dedo remanescente deslizando ao soltar a pinça).
    final last = _lastTwoFingerAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(milliseconds: 500)) {
      return;
    }
    _captureDrawnPoint(details.localFocalPoint);
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
    widget.onConfirm(_points.toList(), _appendMode);
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
      // Rota-guia: no modo "adicionar" ela faz parte do resultado (sólida);
      // no modo refazer fica esmaecida e tracejada, só como referência.
      ...widget.guideRoute.asMap().entries.map((entry) {
        return Polyline(
          polylineId: PolylineId('guide_${entry.key}'),
          points: entry.value,
          color: _appendMode
              ? AppColors.primaryNeon.withValues(alpha: 0.85)
              : cs.onSurfaceVariant.withValues(alpha: 0.4),
          width: _appendMode ? 5 : 4,
          patterns: _appendMode
              ? const <PatternItem>[]
              : [PatternItem.dash(15), PatternItem.gap(10)],
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

  /// Seletor "Adicionar trecho / Refazer": define se o traçado é somado à
  /// rota-guia (completar um pedaço que o GPS não registrou) ou se ela é
  /// substituída. Só aparece na edição com rota existente.
  Widget _buildAppendToggle(ColorScheme cs, bool isDark) {
    Widget pill({
      required bool append,
      required IconData icon,
      required String label,
    }) {
      final selected = _appendMode == append;
      return GestureDetector(
        onTap: _interactive ? () => setState(() => _appendMode = append) : null,
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
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant),
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
            pill(append: true, icon: LucideIcons.plus, label: 'Adicionar'),
            pill(append: false, icon: LucideIcons.refreshCw, label: 'Refazer'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    ColorScheme cs,
    bool isDark,
    double drawnKm,
    double guideKm,
  ) {
    final showAppendTotals = _appendMode && guideKm > 0;
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
                    : showAppendTotals
                        ? '+${drawnKm.toStringAsFixed(2)} km riscado'
                            ' · total ${(guideKm + drawnKm).toStringAsFixed(2)} km'
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
    VoidCallback? onLongPressStart,
    VoidCallback? onLongPressEnd,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      // Os callbacks de long-press do GestureDetector chegam com detalhes
      // (aridade 1); os nossos são VoidCallback — envolvemos aqui.
      onLongPressStart: (enabled && onLongPressStart != null)
          ? (_) => onLongPressStart()
          : null,
      onLongPressEnd: (enabled && onLongPressEnd != null)
          ? (_) => onLongPressEnd()
          : null,
      onLongPressCancel: enabled ? onLongPressEnd : null,
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
    final guideKm = widget.guideRoute.fold<double>(
      0,
      (sum, s) => sum + RouteDrawingMap.distanceKm(s),
    );
    final showAppendToggle =
        widget.allowAppend && widget.guideRoute.any((s) => s.isNotEmpty);
    final canConfirm = _points.length >= 2 && _interactive;
    final confirmLabel = _appendMode && widget.appendConfirmLabel != null
        ? widget.appendConfirmLabel!
        : widget.confirmLabel;

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

          // Modo desenhar: um dedo traça por cima do mapa; dois dedos
          // viram pan/pinça (traduzidos para moveCamera aqui mesmo).
          if (_mode == _DrawMode.desenhar)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
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
                if (showAppendToggle) ...[
                  const SizedBox(height: 8),
                  _buildAppendToggle(cs, isDark),
                ],
                const SizedBox(height: 8),
                _buildStatusChip(cs, isDark, drawnKm, guideKm),
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
                  onTap: _undoLastPoint,
                  onLongPressStart: _startUndoHold,
                  onLongPressEnd: _stopUndoHold,
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
                            confirmLabel,
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
