import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/time_utils.dart';

class RunShareScreen extends StatefulWidget {
  final RunModel run;

  const RunShareScreen({super.key, required this.run});

  @override
  State<RunShareScreen> createState() => _RunShareScreenState();
}

class _RunShareScreenState extends State<RunShareScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  File? _backgroundImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSharing = false;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _backgroundImage = File(image.path);
      });
    }
  }

  Future<void> _shareWorkout() async {
    setState(() => _isSharing = true);
    
    try {
      final imageBytes = await _screenshotController.capture();
      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/runlab_share_${DateTime.now().millisecondsSinceEpoch}.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(imageBytes);

        await Share.shareXFiles(
          [XFile(imagePath)],
          text: 'Meu treino no RunLab! 🔥 #RunLab #Corrida #Fitness',
        );
      }
    } catch (e) {
      debugPrint('Erro ao compartilhar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao gerar imagem para compartilhar.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDarkGreen,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Compartilhar Treino',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
           body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AspectRatio(
                  aspectRatio: 1, // Square for Instagram
                  child: Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDarkGreen,
                        // Blurred background fallback for the square area
                        image: _backgroundImage != null ? DecorationImage(
                          image: FileImage(_backgroundImage!),
                          fit: BoxFit.cover,
                          opacity: 0.25,
                        ) : null,
                      ),
                      child: Stack(
                        children: [
                          // Main Photo (Full Bleed)
                          if (_backgroundImage != null)
                            Positioned.fill(
                              child: Image.file(
                                _backgroundImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          // Dark Gradient Overlay for readability
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.3),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.85),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Watermark
                          Positioned(
                            top: 20,
                            right: 20,
                            child: Row(
                              children: [
                                const Icon(LucideIcons.zap, color: AppColors.primaryNeon, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'RUNLAB',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // User Stats Footer
                          Positioned(
                            bottom: 24,
                            left: 20,
                            right: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.run.distanceKm.toStringAsFixed(2),
                                  style: GoogleFonts.outfit(
                                    color: AppColors.primaryNeon,
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                    height: 0.9,
                                  ),
                                ),
                                Text(
                                  'KILÔMETROS',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _buildSmallStat(LucideIcons.clock, widget.run.pace, '/km'),
                                    const SizedBox(width: 24),
                                    _buildSmallStat(LucideIcons.timer, _formatDuration(widget.run.durationSeconds), 'min'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _formatDate(widget.run.date),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Action Buttons
          Container(
            padding: EdgeInsets.fromLTRB(
              24, 
              24, 
              24, 
              24 + MediaQuery.of(context).padding.bottom
            ),
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
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(LucideIcons.image),
                        label: const Text('GALERIA'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(LucideIcons.camera),
                        label: const Text('CÂMERA'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isSharing ? null : _shareWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNeon,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: _isSharing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(LucideIcons.share2),
                  label: Text(
                    _isSharing ? 'GERANDO...' : 'COMPARTILHAR',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(IconData icon, String value, String unit) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          unit,
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    return TimeUtils.formatDuration(seconds);
  }
}

class RoutePainter extends CustomPainter {
  final List<LatLng> route;
  final Color color;

  RoutePainter({required this.route, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (route.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Add a glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    // 1. Encontrar limites
    double minLat = route[0].latitude;
    double maxLat = route[0].latitude;
    double minLng = route[0].longitude;
    double maxLng = route[0].longitude;

    for (var p in route) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // 2. Normalizar e desenhar
    final path = Path();
    for (int i = 0; i < route.length; i++) {
      final p = route[i];
      final offset = _getOffset(p, minLat, maxLat, minLng, maxLng, size);

      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // 3. Draw Start/End points for clarity (even in short or single-point runs)
    final startPoint = _getOffset(route.first, minLat, maxLat, minLng, maxLng, size);
    final endPoint = _getOffset(route.last, minLat, maxLat, minLng, maxLng, size);

    // Start Dot
    canvas.drawCircle(startPoint, 8.0, Paint()..color = Colors.greenAccent..style = PaintingStyle.fill);
    
    // Only draw end dot if it's different from start or if we have movement
    if (route.length > 1) {
      canvas.drawCircle(endPoint, 8.0, Paint()..color = AppColors.primaryNeon..style = PaintingStyle.fill);
    }
  }

  Offset _getOffset(LatLng p, double minLat, double maxLat, double minLng, double maxLng, Size size) {
    final double latRange = (maxLat - minLat).abs() + 0.0001;
    final double lngRange = (maxLng - minLng).abs() + 0.0001;
    double x = lngRange == 0 ? size.width / 2 : ((p.longitude - minLng) / lngRange) * size.width;
    double y = latRange == 0 ? size.height / 2 : (1 - (p.latitude - minLat) / latRange) * size.height;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
