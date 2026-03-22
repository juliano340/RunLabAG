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

enum ShareTemplate { boxed, center, bottomBar, minimalist, verticalModern }

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
  
  // Customization State
  double _aspectRatio = 1.0; // 1.0 = Square, 0.5625 = 9:16 (Story)
  Offset _statsPosition = const Offset(20, 100); // Initial position from bottom
  bool _showRoute = false;
  Color _accentColor = AppColors.primaryNeon;
  ShareTemplate _currentTemplate = ShareTemplate.boxed;
  double _overlayOpacity = 0.4; // Background dimming

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
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Preview Labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.eye, color: Colors.white54, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            _aspectRatio == 1.0 ? 'PRÉVIA: FEED (1:1)' : 'PRÉVIA: STORY (9:16)',
                            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // The Shareable Item
                      Screenshot(
                        controller: _screenshotController,
                        child: AspectRatio(
                          aspectRatio: _aspectRatio,
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundDarkGreen,
                              image: _backgroundImage != null ? DecorationImage(
                                image: FileImage(_backgroundImage!),
                                fit: BoxFit.cover,
                              ) : null,
                            ),
                            child: Stack(
                              children: [
                                // Gradient Overlay for contrast
                                if (_backgroundImage != null)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.1),
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.6),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // Optional Route Map
                                if (_showRoute && widget.run.route.isNotEmpty)
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(40),
                                      child: CustomPaint(
                                        painter: RoutePainter(
                                          route: widget.run.route,
                                          color: _accentColor,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Watermark (Fixed Top Right)
                                Positioned(
                                  top: _aspectRatio == 1.0 ? 16 : 48,
                                  right: 16,
                                  child: Opacity(
                                    opacity: 0.8,
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.zap, color: _accentColor, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'RUNLAB',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Draggable Stats Overlay
                                _buildStatsOverlay(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_currentTemplate == ShareTemplate.boxed)
                        Text(
                          'DICA: ARRASTE O BLOCO DE DADOS PARA POSICIONAR',
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: AppColors.backgroundDarkGreen,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Layout Customization Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOptionButton(
                        LucideIcons.maximize, 
                        'QUADRADO', 
                        _aspectRatio == 1.0, 
                        () => setState(() {
                          _aspectRatio = 1.0;
                          _statsPosition = const Offset(20, 24);
                        })
                      ),
                      const SizedBox(width: 8),
                      _buildOptionButton(
                        LucideIcons.smartphone, 
                        'STORY', 
                        _aspectRatio == 9/16, 
                        () => setState(() {
                          _aspectRatio = 9/16;
                          _statsPosition = const Offset(20, 48);
                        })
                      ),
                      const SizedBox(width: 8),
                      _buildOptionButton(
                        LucideIcons.map, 
                        'MAPA', 
                        _showRoute, 
                        () => setState(() => _showRoute = !_showRoute)
                      ),
                      const SizedBox(width: 8),
                      _buildOptionButton(
                        LucideIcons.layers, 
                        'ESTILO', 
                        true, 
                        _toggleTemplate
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Color & Opacity Controls
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildColorCircle(AppColors.primaryNeon),
                            _buildColorCircle(Colors.white),
                            _buildColorCircle(const Color(0xFFFC6100)), // Strava Orange
                            _buildColorCircle(Colors.deepPurpleAccent),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          const Icon(LucideIcons.sun, color: Colors.white54, size: 14),
                          Expanded(
                            child: Slider(
                              value: _overlayOpacity,
                              onChanged: (v) => setState(() => _overlayOpacity = v),
                              activeColor: _accentColor,
                              inactiveColor: Colors.white10,
                            ),
                          ),
                          const Icon(LucideIcons.moon, color: Colors.white54, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: const Icon(LucideIcons.image, size: 20),
                        label: const Text('FOTO', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSharing ? null : _shareWorkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNeon,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: _isSharing 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(LucideIcons.share2, size: 20),
                        label: Text(
                          _isSharing ? '...' : 'GERAR',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleTemplate() {
    setState(() {
      int next = (_currentTemplate.index + 1) % ShareTemplate.values.length;
      _currentTemplate = ShareTemplate.values[next];
      // Reset position for centered templates
      if (_currentTemplate == ShareTemplate.bottomBar) _statsPosition = const Offset(0, 0);
      if (_currentTemplate == ShareTemplate.minimalist) _statsPosition = const Offset(0, 0);
      if (_currentTemplate == ShareTemplate.verticalModern) _statsPosition = const Offset(0, 0);
    });
  }

  Widget _buildColorCircle(Color color) {
    bool isSelected = _accentColor == color;
    return GestureDetector(
      onTap: () => setState(() => _accentColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isSelected) BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverlay() {
    switch (_currentTemplate) {
      case ShareTemplate.boxed:
        return _buildBoxedTemplate();
      case ShareTemplate.center:
        return _buildCenterTemplate();
      case ShareTemplate.bottomBar:
        return _buildBottomBarTemplate();
      case ShareTemplate.minimalist:
        return _buildMinimalistTemplate();
      case ShareTemplate.verticalModern:
        return _buildVerticalModernTemplate();
    }
  }

  Widget _buildBoxedTemplate() {
    return Positioned(
      left: _statsPosition.dx,
      bottom: _statsPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _statsPosition += Offset(details.delta.dx, -details.delta.dy);
            _statsPosition = Offset(
              _statsPosition.dx.clamp(10, 200),
              _statsPosition.dy.clamp(20, 500),
            );
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: _overlayOpacity),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.run.distanceKm.toStringAsFixed(2),
                style: GoogleFonts.outfit(
                  color: _accentColor,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              Text(
                'KILÔMETROS',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSmallStat(LucideIcons.clock, widget.run.pace, '/km'),
                  const SizedBox(width: 20),
                  _buildSmallStat(LucideIcons.timer, _formatDuration(widget.run.durationSeconds), 'min'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterTemplate() {
    return Positioned.fill(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.black.withValues(alpha: _overlayOpacity * 0.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'RUNLAB',
              style: GoogleFonts.outfit(
                color: _accentColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.run.distanceKm.toStringAsFixed(2),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 80,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            Text(
              'KILÔMETROS',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildColumnStat('RITMO', widget.run.pace),
                  _buildColumnStat('TEMPO', _formatDuration(widget.run.durationSeconds)),
                  _buildColumnStat('KCAL', widget.run.calories.toString()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBarTemplate() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: _overlayOpacity + 0.2),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.run.distanceKm.toStringAsFixed(2),
                    style: GoogleFonts.outfit(
                      color: _accentColor,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'KILÔMETROS @ RUNLAB',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSmallStat(LucideIcons.clock, widget.run.pace, '/km'),
                const SizedBox(height: 4),
                _buildSmallStat(LucideIcons.timer, _formatDuration(widget.run.durationSeconds), 'min'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalistTemplate() {
    return Positioned(
      top: _aspectRatio == 1.0 ? 40 : 80,
      left: 24,
      right: 24,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.run.distanceKm.toStringAsFixed(2),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'KM',
                    style: GoogleFonts.outfit(
                      color: _accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.run.pace,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'RITMO',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 2, width: double.infinity, color: _accentColor.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildVerticalModernTemplate() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: _overlayOpacity * 0.4),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildVerticalStat('Distância', '${widget.run.distanceKm.toStringAsFixed(2)} km'),
            const SizedBox(height: 24),
            _buildVerticalStat('Ritmo', '${widget.run.pace} /km'),
            const SizedBox(height: 24),
            _buildVerticalStat('Tempo', _formatDuration(widget.run.durationSeconds)),
            const SizedBox(height: 48),
            
            // Branding at the bottom
            Column(
              children: [
                Icon(LucideIcons.zap, color: _accentColor, size: 32),
                const SizedBox(height: 12),
                Text(
                  'RUNLAB',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildColumnStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildOptionButton(IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100, // Fixed width for horizontal scroll
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNeon.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryNeon : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryNeon : Colors.white54, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? AppColors.primaryNeon : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    // Add a glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

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
    canvas.drawCircle(startPoint, 5.0, Paint()..color = Colors.greenAccent..style = PaintingStyle.fill);
    
    // Only draw end dot if it's different from start or if we have movement
    if (route.length > 1) {
      canvas.drawCircle(endPoint, 5.0, Paint()..color = AppColors.primaryNeon..style = PaintingStyle.fill);
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
