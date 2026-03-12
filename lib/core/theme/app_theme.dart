import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryNeon,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryNeon,
        secondary: AppColors.primaryNeonLight,
        surface: AppColors.background,
        onSurface: AppColors.textLight,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      inputDecorationTheme: _inputDecorationTheme(isDark: true),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      dividerColor: AppColors.cardBorder.withValues(alpha: 0.2),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.accentEmerald,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentEmerald,
        secondary: AppColors.primaryNeon,
        surface: AppColors.cardLight,
        onSurface: AppColors.textDark,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      inputDecorationTheme: _inputDecorationTheme(isDark: false),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0, // Elevation is handled by custom shadows in containers
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none, // Pure White aesthetic uses shadows over borders
        ),
      ),
      dividerColor: AppColors.borderLight,
    );
  }

  static InputDecorationTheme _inputDecorationTheme({required bool isDark}) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark 
          ? AppColors.cardBackground.withValues(alpha: 0.5) 
          : AppColors.borderLight.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.cardBorder.withValues(alpha: 0.5) : AppColors.borderLight
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.cardBorder.withValues(alpha: 0.3) : AppColors.borderLight
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.primaryNeon : AppColors.accentEmerald, 
          width: 2
        ),
      ),
      labelStyle: TextStyle(
        color: isDark ? AppColors.textMuted : AppColors.textMutedDark
      ),
      hintStyle: TextStyle(
        color: isDark ? AppColors.textMuted.withValues(alpha: 0.5) : AppColors.textMutedDark.withValues(alpha: 0.5)
      ),
    );
  }
}
