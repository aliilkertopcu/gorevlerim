import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF667eea);
  static const Color primaryDark = Color(0xFF5a6fd6);
  static const Color completedColor = Color(0xFF28a745);
  static const Color blockedColor = Color(0xFFdc3545);
  static const Color postponedColor = Color(0xFFfd7e14);
  static const Color pendingColor = Color(0xFFffc107);
  static const Color background = Color(0xFFf0f2f5);
  static const Color cardBackground = Color(0xFFf8f9fa);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primaryColor,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFdddddd)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'completed':
        return completedColor;
      case 'blocked':
        return blockedColor;
      case 'postponed':
        return postponedColor;
      default:
        return pendingColor;
    }
  }

  static Color statusBackground(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFFd4edda);
      case 'blocked':
        return const Color(0xFFf8d7da);
      case 'postponed':
        return const Color(0xFFfff3cd);
      default:
        return cardBackground;
    }
  }
}
