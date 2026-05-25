import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../../core/theme/app_colors.dart';

class ActiveRunLockOverlay extends StatefulWidget {
  final VoidCallback onUnlock;

  const ActiveRunLockOverlay({
    super.key,
    required this.onUnlock,
  });

  @override
  State<ActiveRunLockOverlay> createState() => _ActiveRunLockOverlayState();
}

class _ActiveRunLockOverlayState extends State<ActiveRunLockOverlay> {
  bool _showHint = false;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _showHint = true;
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showHint = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _showHint = true;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showHint = false;
        });
      }
    });
  }

  void _handleLongPress() {
    widget.onUnlock();
    _hintTimer?.cancel();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          child: Align(
            alignment: const Alignment(0, -0.4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.lock,
                  color: AppColors.primaryNeon,
                  size: 64,
                ),
                const SizedBox(height: 16),
                AnimatedOpacity(
                  opacity: _showHint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    'Pressione e segure para desbloquear',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
