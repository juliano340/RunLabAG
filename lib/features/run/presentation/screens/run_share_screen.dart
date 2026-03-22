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
  bool _showRoute = false;
  Color _accentColor = AppColors.primaryNeon;
  ShareTemplate _currentTemplate = ShareTemplate.boxed;
  double _overlayOpacity = 0.4; // Background dimming
  
  // Freeform Transformation
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _statsPosition = const Offset(20, 100); 
  bool _isOperating = false; // UX feedback flag

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
          // 1. Preview Area (Fits screen height automatically)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  
                  // The Shareable Item (Now wrapped in Expanded + FittedBox to fit screen)
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Screenshot(
                          controller: _screenshotController,
                          child: SizedBox(
                            width: 380, // Base width; FittedBox will scale it down if needed
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

                                    // Draggable/Scalable Stats Overlay
                                    _buildInteractiveOverlay(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Controls Section (Fixed Bottom Footer)
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: AppColors.backgroundDarkGreen,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DICA: PINÇA PARA ZOOM / ARRASTE P/ POSICIONAR',
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
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
                        _aspectRatio < 1.0, 
                        () => setState(() {
                          _aspectRatio = 0.5625;
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
      // Reset position/scale for a fresh start with the new template
      _scale = 1.0;
      _statsPosition = const Offset(20, 24);
      if (_currentTemplate == ShareTemplate.center) _statsPosition = const Offset(20, 150);
      if (_currentTemplate == ShareTemplate.verticalModern) _statsPosition = const Offset(20, 40);
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

  Widget _buildInteractiveOverlay() {
    return Positioned(
      left: _statsPosition.dx,
      bottom: _statsPosition.dy,
      child: GestureDetector(
        onScaleStart: (details) {
          setState(() {
            _baseScale = _scale;
            _isOperating = true;
          });
        },
        onScaleEnd: (details) {
          setState(() {
            _isOperating = false;
          });
        },
        onScaleUpdate: (details) {
          setState(() {
            _scale = (_baseScale * details.scale).clamp(0.4, 4.0);
            _statsPosition += Offset(details.focalPointDelta.dx, -details.focalPointDelta.dy);
            
            // Much more generous bounds to work across all aspect ratios
            _statsPosition = Offset(
              _statsPosition.dx.clamp(-200, 500),
              _statsPosition.dy.clamp(-100, 1200),
            );
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: _isOperating 
                ? Border.all(color: _accentColor.withValues(alpha: 0.8), width: 2, style: BorderStyle.solid) 
                : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Transform.scale(
            scale: _scale,
            child: Padding(
              padding: const EdgeInsets.all(12), // Extra hit area
              child: _buildStatsOverlayContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverlayContent() {
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
    return Container(
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
    );
  }

  Widget _buildCenterTemplate() {
    return Container(
      width: 280, // Fixed width to allow scaling/centering
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: _overlayOpacity * 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              fontSize: 64, // Slightly smaller than before to fit in container
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          Text(
            'KILÔMETROS',
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColumnStat('RITMO', widget.run.pace),
                const SizedBox(width: 8),
                _buildColumnStat('TEMPO', _formatDuration(widget.run.durationSeconds)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBarTemplate() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      color: Colors.black.withValues(alpha: _overlayOpacity),
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
    );
  }

  Widget _buildMinimalistTemplate() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
    return Container(
      width: 280,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: _overlayOpacity * 0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildVerticalStat('Distância', '${widget.run.distanceKm.toStringAsFixed(2)} km'),
          const SizedBox(height: 16),
          _buildVerticalStat('Ritmo', '${widget.run.pace} /km'),
          const SizedBox(height: 16),
          _buildVerticalStat('Tempo', _formatDuration(widget.run.durationSeconds)),
          const SizedBox(height: 32),
          
          Column(
            children: [
              Icon(LucideIcons.zap, color: _accentColor, size: 28),
              const SizedBox(height: 8),
              Text(
                'RUNLAB',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ],
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
