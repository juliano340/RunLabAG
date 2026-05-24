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

class RunDetailScreen extends StatefulWidget {
  final RunModel run;

  const RunDetailScreen({super.key, required this.run});

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<RunDetailScreen> {
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

  @override
  Widget build(BuildContext context) {
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
          icon: Icon(LucideIcons.arrowLeft, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.share2, color: Theme.of(context).colorScheme.primary),
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
          // Map View showing the route
          Expanded(
            flex: 3,
            child: Stack(
              children: [                GoogleMap(
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
                  },
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
                    if (widget.run.route.isNotEmpty && widget.run.route.any((s) => s.isNotEmpty)) {
                      // Encontrar limites em todos os segmentos
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
                        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
                      }
                    }
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (mounted) {
                        setState(() => _isMapReady = true);
                      }
                    });
                  },
                ),
                // Overlay to make map look integrated
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
                // Cobertura anti-flash: esconde o mapa branco até o estilo ser aplicado
                if (!_isMapReady && Theme.of(context).brightness == Brightness.dark)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(color: const Color(0xFF1d2c2c)),
                    ),
                  ),
              ],
            ),
          ),
          
          // Metrics Card
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (widget.run.type == 'Caminhada'
                              ? Colors.blueAccent
                              : widget.run.type == 'Corrida/Caminhada'
                                  ? Colors.orangeAccent
                                  : Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (widget.run.type == 'Caminhada'
                                ? Colors.blueAccent
                                : widget.run.type == 'Corrida/Caminhada'
                                    ? Colors.orangeAccent
                                    : Theme.of(context).colorScheme.primary)
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
                                  : Theme.of(context).colorScheme.primary,
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
                                    : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.run.mood.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(widget.run.mood, style: const TextStyle(fontSize: 36)),
                          const SizedBox(width: 12),
                          Text(
                            widget.run.mood == '😣' ? 'Ruim'
                                : widget.run.mood == '😐' ? 'Médio'
                                : widget.run.mood == '🙂' ? 'Bom'
                                : 'Excelente',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 20,
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
                const SizedBox(height: 24),
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
                  const SizedBox(height: 24),
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
                const SizedBox(height: 32),
                
                if (widget.run.splits.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _showSplitsModal,
                      icon: Icon(LucideIcons.list, color: Theme.of(context).colorScheme.primary, size: 18),
                      label: Text(
                        'VER VOLTAS',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(LucideIcons.check, color: Theme.of(context).colorScheme.onPrimary),
                    label: Text(
                      'VOLTAR',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
