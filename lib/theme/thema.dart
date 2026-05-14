import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const primary = Color(0xFF4BC5D9); // Turquoise / Cyan - warna dominan brand
  static const primaryDark = Color(0xFF485C69); // Dark Slate / Abu kebiruan gelap
  static const primaryLight = Color(0xFF4BC5D9); // Turquoise

  static const background = Color(0xFFFAFAFA); // Light Gray
  static const surface = Color(0xFFFFFFFF); // White
  static const altSurface = Color(0xFFF5F5F5); // Very Light Gray

  static const accent = Color(0xFFF7943A); // Orange - warna aksen
  static const accentLight = Color(0xFFFFB366);
  static const accentDark = Color(0xFFE67E22);

static const textPrimary = Color(0xFF485C69); // Dark Slate untuk text primary
  static const textSecondary = Color(0xFF7A8B99); // Light slate untuk text secondary

  static const error = Color(0xFFE53935);
  static const success = Color(0xFF4CAF50);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,

      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        error: Color(0xFFE53935),
        onError: Colors.white,
        background: AppColors.background,
        onBackground: AppColors.textPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),

      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
