import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0061A4),
        brightness: Brightness.light,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        isDense: true,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF75B8F5),
        brightness: Brightness.dark,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        isDense: true,
      ),
    );
  }
}
