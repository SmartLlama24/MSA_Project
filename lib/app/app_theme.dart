import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const background = Color(0xFF171719);
  static const surface = Color(0xFF222226);
  static const elevatedSurface = Color(0xFF302D28);
  static const accent = Color(0xFFC9A66B);
  static const primaryText = Color(0xFFF5F5F5);
  static const mutedText = Color(0xFFA0A0A0);
  static const subtleBorder = Color(0x1FFFFFFF);

  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space7 = 32.0;

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: primaryText,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: primaryText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: subtleBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: subtleBorder,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: const TextStyle(color: mutedText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: subtleBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: subtleBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: const Color(0xFF211B11),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      height: 68,
      indicatorColor: accent.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? accent
            : mutedText;
        return TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? accent
            : mutedText;
        return IconThemeData(color: color, size: 23);
      }),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: primaryText,
        fontSize: 27,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        height: 1.12,
      ),
      titleLarge: TextStyle(
        color: primaryText,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleMedium: TextStyle(
        color: primaryText,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: primaryText, fontSize: 14, height: 1.45),
      bodyMedium: TextStyle(color: mutedText, fontSize: 13, height: 1.4),
      bodySmall: TextStyle(color: mutedText, fontSize: 11, height: 1.35),
    ),
  );
}
