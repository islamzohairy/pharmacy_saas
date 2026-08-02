import 'package:flutter/material.dart';

/// Application-wide theme. Material 3 with a seeded color scheme.
class AppTheme {
  const AppTheme._();

  static const Color _seedColor = Color(0xFF0F766E);

  static ThemeData get light =>
      ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seedColor));
}
