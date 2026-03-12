import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:lucide_icons/lucide_icons.dart';

class StartRunButton extends StatefulWidget {
  final VoidCallback onPressed;

  const StartRunButton({super.key, required this.onPressed});

  @override
  State<StartRunButton> createState() => _StartRunButtonState();
}

class _StartRunButtonState extends State<StartRunButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _glowAnimation = Tween<double>(begin: 10.0, end: 25.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onPressed,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryNeon,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryNeon.withValues(alpha: 0.6),
                    blurRadius: _glowAnimation.value,
                    spreadRadius: _glowAnimation.value / 4,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  LucideIcons.play,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.black 
                      : Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
