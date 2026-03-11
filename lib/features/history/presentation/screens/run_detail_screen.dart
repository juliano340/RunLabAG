import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/database_service.dart';
import '../../../run/presentation/widgets/metric_card.dart';

class RunDetailScreen extends StatefulWidget {
  final RunModel run;

  const RunDetailScreen({super.key, required this.run});

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<RunDetailScreen> {
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  void _loadMapStyle() async {
    final style = await rootBundle.loadString('assets/map_style_minimal.json');
    setState(() {
      _mapStyle = style;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDarkGreen,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Treino de ${_formatDate(widget.run.date)}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
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
              children: [
                GoogleMap(
                  style: _mapStyle,
                  initialCameraPosition: CameraPosition(
                    target: widget.run.route.isNotEmpty 
                        ? widget.run.route.first 
                        : const LatLng(-23.5505, -46.6333),
                    zoom: 15,
                  ),
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: widget.run.route,
                      color: AppColors.primaryNeon,
                      width: 5,
                    ),
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) {
                    if (widget.run.route.isNotEmpty) {
                      // Fit bounds to show entire route
                      LatLngBounds bounds;
                      double minLat = widget.run.route.first.latitude;
                      double minLng = widget.run.route.first.longitude;
                      double maxLat = widget.run.route.first.latitude;
                      double maxLng = widget.run.route.first.longitude;

                      for (var point in widget.run.route) {
                        if (point.latitude < minLat) minLat = point.latitude;
                        if (point.longitude < minLng) minLng = point.longitude;
                        if (point.latitude > maxLat) maxLat = point.latitude;
                        if (point.longitude > maxLng) maxLng = point.longitude;
                      }

                      bounds = LatLngBounds(
                        southwest: LatLng(minLat, minLng),
                        northeast: LatLng(maxLat, maxLng),
                      );

                      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
                    }
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
                          AppColors.backgroundDarkGreen.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.transparent,
                          AppColors.backgroundDarkGreen,
                        ],
                        stops: const [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Metrics Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.backgroundDarkGreen,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
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
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primaryNeon,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.check, color: Colors.black),
                    label: const Text(
                      'VOLTAR',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        title: Text(
          'Excluir Treino?',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Esta ação não pode ser desfeita. Deseja realmente remover este registro?',
          style: GoogleFonts.outfit(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR', style: GoogleFonts.outfit(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final dbService = DatabaseService();
              await dbService.deleteRun(widget.run.id);
              if (context.mounted) {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to history
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Treino excluído com sucesso.'),
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
      ),
    );
  }
}
