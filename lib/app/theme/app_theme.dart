import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark() {
    const background = Color(0xFF090D1A);
    const surface = Color(0xFF121A2F);
    const surfaceHigh = Color(0xFF1A2542);
    const primary = Color(0xFF6F7CFF);
    const secondary = Color(0xFF29C6FF);
    const tertiary = Color(0xFF34D399);
    const error = Color(0xFFFF6B7A);

    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: Color(0xFF0D1330),
      secondary: secondary,
      onSecondary: Color(0xFF001720),
      tertiary: tertiary,
      onTertiary: Color(0xFF032316),
      error: error,
      onError: Color(0xFF30040A),
      surface: surface,
      onSurface: Color(0xFFE8EEFF),
      onSurfaceVariant: Color(0xFFA6B5D9),
      outline: Color(0xFF35466F),
      outlineVariant: Color(0xFF253452),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE8EEFF),
      onInverseSurface: Color(0xFF0C1226),
      inversePrimary: Color(0xFF4758D8),
      surfaceContainerHighest: surfaceHigh,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF263556), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0C1327),
        indicatorColor: primary.withValues(alpha: 0.24),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF273556),
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: const BorderSide(color: Color(0xFF32466E)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF10182E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF304166)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF304166)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: Color(0xFF2A3A5A),
        thumbColor: Color(0xFFCAD4FF),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.4,
        ),
      ),
    );
  }

  static ThemeData light() {
    // Keep a light fallback for tests/previews, but app defaults to dark theme.
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF6F7CFF),
      brightness: Brightness.light,
    );
  }
}
