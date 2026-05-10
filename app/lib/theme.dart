import 'package:flutter/material.dart';

class AppTheme {
  static const Color creamLight = Color(0xFFF8F3D9);
  static const Color beigeMid = Color(0xFFEBE5C2); 
  static const Color oliveMuted = Color(0xFFB9B28A); 
  static const Color deepCharcoal = Color(0xFF504B38);
  static const Color white = Colors.white;

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: creamLight,
      
      colorScheme: const ColorScheme.light(
        primary: deepCharcoal,
        secondary: oliveMuted,
        surface: white,
        onPrimary: creamLight,
        onSurface: deepCharcoal,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: deepCharcoal),
        titleTextStyle: TextStyle(
          color: deepCharcoal,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),

      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: deepCharcoal, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: deepCharcoal),
      ),
    );
  }
}