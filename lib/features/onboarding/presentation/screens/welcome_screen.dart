import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/backup_service.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backupService = BackupService();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    AppColors.primaryNeon.withValues(alpha: 0.15),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 64),
                  // Logo/Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primaryNeon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primaryNeon.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.zap,
                      color: AppColors.primaryNeon,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Title
                  Text(
                    'REDEFINA\nSEUS LIMITES',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  Text(
                    'O laboratório de performance para corredores que buscam a elite.',
                    style: GoogleFonts.outfit(
                      color: AppColors.textMuted,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Main Action
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/onboarding'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNeon,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'COMEÇAR AGORA',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.arrowRight, size: 20),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Secondary Action (Backup)
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );

                        if (result != null) {
                          final file = File(result.files.single.path!);
                          final content = await file.readAsString();
                          final success = await backupService.importBackup(content);
                          
                          if (context.mounted) {
                            if (success) {
                              // Se restaurou com sucesso, marca onboarding como feito
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('hasCompletedOnboarding', true);
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(context, '/dashboard');
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Erro ao importar backup')),
                              );
                            }
                          }
                        }
                      },
                      child: Text(
                        'JÁ TENHO UM BACKUP',
                        style: GoogleFonts.outfit(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
