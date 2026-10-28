import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const brand = Color(0xFF10706B);

  static final light = ThemeData(
    fontFamily: 'kalameh',
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF7F8FA),
    colorScheme: ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Color(0xFFF7F8FA),
      surfaceTintColor: Colors.transparent,
    ),
  );
}
