import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/ad_banner_widget.dart';

class ActiveRunTopBar extends StatelessWidget {
  final bool isDark;
  final bool isRunning;
  final bool isPaused;
  final bool isAutoPaused;
  final bool showMinimalMap;
  final bool autoPauseEnabled;

  final VoidCallback onBack;
  final VoidCallback onToggleMinimalMap;
  final VoidCallback onToggleAutoPause;
  final VoidCallback onLock;

  const ActiveRunTopBar({
    super.key,
    required this.isDark,
    required this.isRunning,
    required this.isPaused,
    required this.isAutoPaused,
    required this.showMinimalMap,
    required this.autoPauseEnabled,
    required this.onBack,
    required this.onToggleMinimalMap,
    required this.onToggleAutoPause,
    required this.onLock,
  });

  String get _statusText {
    if (isPaused) return 'PAUSADO';
    if (isAutoPaused) return 'AUTO PAUSADO';
    return 'GPS ATIVO';
  }

  Color get _statusColor {
    if (isPaused || isAutoPaused) return Colors.orange;
    return AppColors.primaryNeon;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Botão Voltar (Esquerda)
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                child: IconButton(
                  icon: Icon(
                    LucideIcons.arrowLeft,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: onBack,
                ),
              ),
              // Título + Anúncio Centralizado
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDark) ...[
                      Text(
                        'CORRIDA ATUAL',
                        style: GoogleFonts.outfit(
                          color: AppColors.primaryNeon,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 6),
                            Shadow(color: Colors.black54, blurRadius: 14),
                          ],
                        ),
                      ),
                      if (isRunning)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _statusText,
                              style: GoogleFonts.outfit(
                                color: _statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 6),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                    ],
                    AdBannerWidget(
                      adSize: AdSize(width: 200, height: 50),
                    ),
                  ],
                ),
              ),
              // Coluna direita: Olho + Auto Pause + Cadeado
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                    child: IconButton(
                      icon: Icon(
                        showMinimalMap ? LucideIcons.eyeOff : LucideIcons.eye,
                        color: AppColors.primaryNeon,
                      ),
                      onPressed: onToggleMinimalMap,
                      tooltip: 'Alternar Mapa Minimalista',
                    ),
                  ),
                  const SizedBox(height: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                    child: IconButton(
                      icon: Icon(
                        LucideIcons.pauseCircle,
                        color: autoPauseEnabled ? AppColors.primaryNeon : Colors.white70,
                      ),
                      onPressed: onToggleAutoPause,
                      tooltip: 'Auto Pause',
                    ),
                  ),
                  if (isRunning) ...[
                    const SizedBox(height: 8),
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                      child: IconButton(
                        icon: const Icon(
                          LucideIcons.lock,
                          color: Colors.white70,
                        ),
                        onPressed: onLock,
                        tooltip: 'Bloquear Tela',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
