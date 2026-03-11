import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/database_service.dart';

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

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
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
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        image: _backgroundImage != null
                            ? DecorationImage(
                                image: FileImage(_backgroundImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          // Overlay to ensure text readability
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.2),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                          
                          // RunLab Watermark (Top Right)
                          Positioned(
                            top: 16,
                            right: 16,
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
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Main Stats (Bottom Left)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.run.distanceKm.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.primaryNeon,
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
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
                                const SizedBox(height: 12),
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
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
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
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(LucideIcons.image),
                  label: const Text('ESCOLHER FOTO'),
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
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
