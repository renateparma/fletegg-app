// lib/theme/colors.dart
// FleteGG — Paleta de colores de marca

import 'package:flutter/material.dart';

class FleteGGColors {
  // Primario
  static const Color primary = Color(0xFFFF6B00);      // Naranjo energía
  static const Color primaryLight = Color(0xFFFF8C42);
  static const Color primaryDark = Color(0xFFCC5500);

  // Neutros
  static const Color background = Color(0xFF0A0A0A);    // Negro profundo
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF222222);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF999999);

  // Estados
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFD600);
  static const Color error = Color(0xFFF44336);

  // Vehículos
  static const Color camionColor = Color(0xFFFF6B00);
  static const Color furgonColor = Color(0xFF2196F3);
  static const Color camionetaColor = Color(0xFF4CAF50);
}

class FleteGGTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FleteGGColors.primary,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: FleteGGColors.primary,
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FleteGGColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FleteGGColors.primary, width: 2),
      ),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FleteGGColors.primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: FleteGGColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: FleteGGColors.surface,
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: FleteGGColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FleteGGColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
  );
}