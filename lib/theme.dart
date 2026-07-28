import 'package:flutter/material.dart';

const navyBlue = Color(0xFF16223B);
const taupe = Color(0xFFC9B79C);

Color _tint(Color base, double amount) => Color.lerp(base, Colors.white, amount)!;

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: navyBlue,
    brightness: Brightness.light,
  ).copyWith(
    primary: navyBlue,
    onPrimary: Colors.white,
    primaryContainer: _tint(navyBlue, 0.85),
    onPrimaryContainer: navyBlue,
    secondary: taupe,
    onSecondary: navyBlue,
    secondaryContainer: _tint(taupe, 0.55),
    onSecondaryContainer: navyBlue,
    surface: Colors.white,
    surfaceContainerLow: _tint(navyBlue, 0.96),
    surfaceContainer: _tint(navyBlue, 0.94),
    surfaceContainerHigh: _tint(navyBlue, 0.9),
    outlineVariant: _tint(navyBlue, 0.8),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: colorScheme.onPrimary),
    ),
    dividerTheme: DividerThemeData(color: _tint(navyBlue, 0.82)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F2F5),
      hintStyle: TextStyle(color: Colors.grey.shade500),
      iconColor: Colors.grey.shade500,
      prefixIconColor: Colors.grey.shade500,
      suffixIconColor: Colors.grey.shade500,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: navyBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
    ),
  );
}
