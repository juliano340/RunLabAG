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

  static TextTheme get _lightTextTheme {
    // Headlines & Labels: Space Grotesk | Body: Inter
    final base = ThemeData.light().textTheme;
    final spaceGrotesk = GoogleFonts.spaceGroteskTextTheme(base);
    final inter = GoogleFonts.interTextTheme(base);
    return base.copyWith(
      displayLarge: spaceGrotesk.displayLarge?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w700),
      displayMedium: spaceGrotesk.displayMedium?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w700),
      displaySmall: spaceGrotesk.displaySmall?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w700),
      headlineLarge: spaceGrotesk.headlineLarge?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w700),
      headlineMedium: spaceGrotesk.headlineMedium?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w600),
      headlineSmall: spaceGrotesk.headlineSmall?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w600),
      titleLarge: spaceGrotesk.titleLarge?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w600),
      titleMedium: spaceGrotesk.titleMedium?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w500),
      titleSmall: spaceGrotesk.titleSmall?.copyWith(color: AppColors.textMutedDark, fontWeight: FontWeight.w500),
      bodyLarge: inter.bodyLarge?.copyWith(color: AppColors.textDark),
      bodyMedium: inter.bodyMedium?.copyWith(color: AppColors.textDark),
      bodySmall: inter.bodySmall?.copyWith(color: AppColors.textMutedDark),
      labelLarge: spaceGrotesk.labelLarge?.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w600),
      labelMedium: spaceGrotesk.labelMedium?.copyWith(color: AppColors.textMutedDark, fontWeight: FontWeight.w500),
      labelSmall: spaceGrotesk.labelSmall?.copyWith(color: AppColors.textHintLight, fontWeight: FontWeight.w500),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.lightPrimary,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.surfaceContainerLight,
        onPrimaryContainer: AppColors.lightSecondary,
        secondary: AppColors.lightSecondary,
        onSecondary: Colors.white,
        // Lime (#6AF425): BACKGROUND USE ONLY — nunca em texto ou ícone.
        // Use tertiaryContainer para badges/tags; onTertiary/onTertiaryContainer sempre escuros.
        tertiary: AppColors.lightTertiary,
        onTertiary: AppColors.lightSecondary,        // texto ESCURO sobre fundo lime
        tertiaryContainer: AppColors.tertiaryContainerLight,
        onTertiaryContainer: AppColors.lightSecondary, // texto ESCURO sobre container lime suave
        surface: AppColors.cardLight,
        onSurface: AppColors.textDark,
        onSurfaceVariant: AppColors.textMutedDark,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.borderLight,
        error: AppColors.errorLight,
        onError: Colors.white,
      ),
      textTheme: _lightTextTheme,
      inputDecorationTheme: _inputDecorationTheme(isDark: false),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardLight,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.borderLight,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardLight,
        selectedItemColor: AppColors.lightPrimary,
        unselectedItemColor: AppColors.textMutedDark,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardLight,
        indicatorColor: AppColors.surfaceContainerLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.lightPrimary);
          }
          return const IconThemeData(color: AppColors.textMutedDark);
        }),
      ),
      iconTheme: const IconThemeData(color: AppColors.textMutedDark),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
      ),
      dividerColor: AppColors.borderLight,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightSecondary,
          side: const BorderSide(color: AppColors.lightSecondary),
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightPrimary,
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerLight,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.lightPrimary,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: AppColors.borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.lightPrimary : AppColors.textHintLight),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.surfaceContainerLight : AppColors.borderLight),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({required bool isDark}) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? AppColors.cardBackground.withValues(alpha: 0.5)
          : AppColors.cardLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.cardBorder.withValues(alpha: 0.5) : AppColors.borderLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.cardBorder.withValues(alpha: 0.3) : AppColors.borderLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.primaryNeon : AppColors.accentEmerald,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.error : AppColors.errorLight,
        ),
      ),
      labelStyle: TextStyle(
        color: isDark ? AppColors.textMuted : AppColors.textMutedDark,
      ),
      hintStyle: TextStyle(
        color: isDark ? AppColors.textMuted.withValues(alpha: 0.5) : AppColors.textHintLight,
      ),
    );
  }
}
