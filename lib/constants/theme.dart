import 'package:flutter/material.dart';

class AppTheme {
  // 星空应用的颜色常量
  static const Color darkBlue = Color(0xFF0A1128);
  static const Color midBlue = Color(0xFF1C2541);
  static const Color lightBlue = Color(0xFF4CC9F0);
  static const Color purple = Color(0xFF7B2CBF);
  static const Color white = Color(0xFFE9ECEF);
  static const Color orange = Color(0xFFFF8500);

  static ThemeData lightTheme = ThemeData(
    primaryColor: purple,
    colorScheme: ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: purple,
      foregroundColor: white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: purple,
        foregroundColor: white,
      ),
    ),
    useMaterial3: true,
  );

  static ThemeData darkTheme = ThemeData(
    primaryColor: purple,
    colorScheme: ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.dark,
      primary: purple,
      secondary: lightBlue,
      background: darkBlue,
      surface: midBlue,
    ),
    scaffoldBackgroundColor: darkBlue,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBlue,
      foregroundColor: white,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkBlue,
      selectedItemColor: lightBlue,
      unselectedItemColor: white,
    ),
    cardTheme: CardTheme(
      color: midBlue.withOpacity(0.8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(color: white, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: white, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: white),
      bodyLarge: TextStyle(color: white),
      bodyMedium: TextStyle(color: white),
    ),
    iconTheme: const IconThemeData(
      color: white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: purple,
        foregroundColor: white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    useMaterial3: true,
  );
}
