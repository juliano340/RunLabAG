import 'package:flutter/material.dart';

class AppColors {
  // Common Colors
  static const Color primaryNeon = Color(0xFF39FF14);
  static const Color primaryNeonLight = Color(0xFF7FFF00);
  static const Color primaryNeonDark = Color(0xFF2EB311);
  static const Color error = Color(0xFFFF3333);

  // Dark Theme Palette
  static const Color background = Color(0xFF000000);
  static const Color backgroundDarkGreen = Color(0xFF0A1F0A);
  static const Color cardBackground = Color(0x3300FF00); // 20% opacity green
  static const Color cardBorder = Color(0x8039FF14); // 50% opacity neon
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFB0D0B0);

  // Light Theme Palette — Neon Kinetic Light
  static const Color lightPrimary = Color(0xFF4BA01A);       // Primary forest green
  static const Color lightSecondary = Color(0xFF2D342B);     // Dark charcoal (secondary / text)
  static const Color lightTertiary = Color(0xFF6AF425);      // Lime accent — use sparingly
  static const Color lightNeutral = Color(0xFFF8FAF7);       // Card / surface neutral
  static const Color backgroundLight = Color(0xFFEEF0EB);    // Scaffold — cards float on this
  static const Color cardLight = Color(0xFFF8FAF7);          // Card surface (neutral)
  static const Color surfaceContainerLight = Color(0xFFE3F0D8); // Tinted green container (primaryContainer)
  static const Color tertiaryContainerLight = Color(0xFFD4F5A0); // Lime suave — fundo de badges/tags
  static const Color borderLight = Color(0xFFDADDD6);        // Warm-gray border
  static const Color textDark = Color(0xFF2D342B);           // Primary text = secondary color
  static const Color textMutedDark = Color(0xFF5C6358);      // Muted text
  static const Color textHintLight = Color(0xFF9BA598);      // Hint / placeholder
  static const Color accentEmerald = Color(0xFF4BA01A);      // Kept as alias → lightPrimary
  static const Color accentEmeraldLight = Color(0xFF6AF425); // Kept as alias → lightTertiary
  static const Color errorLight = Color(0xFFDC2626);         // Error red

  // Badge helpers — lime SEMPRE como fundo, texto SEMPRE escuro
  // Uso: Container(color: AppColors.badgeBg, child: Text('INTERVALS', style: TextStyle(color: AppColors.badgeText)))
  static const Color badgeBg = lightTertiary;               // #6AF425 — fundo do badge
  static const Color badgeText = lightSecondary;            // #2D342B — texto sobre o badge
}
