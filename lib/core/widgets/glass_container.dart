import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final bool hasNeonBorder;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 16,
    this.hasNeonBorder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget container = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.cardBackground 
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(borderRadius),
        border: hasNeonBorder || isDark
            ? Border.all(
                color: hasNeonBorder 
                    ? AppColors.primaryNeon 
                    : AppColors.cardBorder,
                width: hasNeonBorder ? 1.5 : 1.0,
              )
            : null,
        boxShadow: [
          if (hasNeonBorder)
            BoxShadow(
              color: AppColors.primaryNeon.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          if (!isDark && !hasNeonBorder)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}
