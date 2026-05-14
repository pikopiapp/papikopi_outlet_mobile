import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6B4226);
  static const primaryDark = Color(0xFF3E2723);
  static const primaryLight = Color(0xFFA47148);

  static const background = Color(0xFFF5EDE6);
  static const surface = Color(0xFFFFFFFF);
  static const altSurface = Color(0xFFEDE0D4);

  static const accent = Color(0xFFF59E0B);
  static const accentLight = Color(0xFFFFD166);
  static const accentDark = Color(0xFFE67E22);

static const textPrimary = Color(0xFF2B2B2B);
  static const textSecondary = Color(0xFF6E6E6E);

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
