import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  useMaterial3: true,

  // 👇 Scaffold (screen background)
  scaffoldBackgroundColor: const Color(0xfff5f6fa), // Soft light grey
  // 👇 AppBar theme
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
    elevation: 0,
  ),

  // 👇 Text styles
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 16.0, color: Colors.black87),
    bodyMedium: TextStyle(fontSize: 14.0, color: Colors.black54),
    titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
  ),

  // 👇 Card style
  cardColor: Colors.white,

  cardTheme: CardThemeData(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 3,
  ),

  // 👇 Icon colors
  iconTheme: const IconThemeData(color: Colors.blue),

  // 👇 Button styles
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);
