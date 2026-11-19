import 'package:flutter/material.dart';

enum PaintbenchTheme { darkGold, warmWhite, whiteGreen, lightRed }

extension PaintbenchThemeDetails on PaintbenchTheme {
  String get label => switch (this) {
    PaintbenchTheme.darkGold => 'Dark & Gold',
    PaintbenchTheme.warmWhite => 'Warm White',
    PaintbenchTheme.whiteGreen => 'White & Green',
    PaintbenchTheme.lightRed => 'Light & Red',
  };

  String get description => switch (this) {
    PaintbenchTheme.darkGold => 'Charcoal surfaces with muted gold accents',
    PaintbenchTheme.warmWhite => 'Warm, premium workbench neutrals',
    PaintbenchTheme.whiteGreen => 'Fresh, clean hobby workspace',
    PaintbenchTheme.lightRed => 'A tabletop-inspired palette',
  };

  AppPalette get palette => switch (this) {
    PaintbenchTheme.darkGold => AppTheme.darkPalette,
    PaintbenchTheme.warmWhite => AppTheme.warmWhitePalette,
    PaintbenchTheme.whiteGreen => AppTheme.whiteGreenPalette,
    PaintbenchTheme.lightRed => AppTheme.lightRedPalette,
  };
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.elevatedSurface,
    required this.accent,
    required this.primaryText,
    required this.mutedText,
    required this.border,
    required this.onAccent,
  });

  final Color background;
  final Color surface;
  final Color elevatedSurface;
  final Color accent;
  final Color primaryText;
  final Color mutedText;
  final Color border;
  final Color onAccent;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? elevatedSurface,
    Color? accent,
    Color? primaryText,
    Color? mutedText,
    Color? border,
    Color? onAccent,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    elevatedSurface: elevatedSurface ?? this.elevatedSurface,
    accent: accent ?? this.accent,
    primaryText: primaryText ?? this.primaryText,
    mutedText: mutedText ?? this.mutedText,
    border: border ?? this.border,
    onAccent: onAccent ?? this.onAccent,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      border: Color.lerp(border, other.border, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get appPalette => Theme.of(this).extension<AppPalette>()!;
}

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

  static const darkPalette = AppPalette(
    background: background,
    surface: surface,
    elevatedSurface: elevatedSurface,
    accent: accent,
    primaryText: primaryText,
    mutedText: mutedText,
    border: subtleBorder,
    onAccent: Color(0xFF211B11),
  );

  static const warmWhitePalette = AppPalette(
    background: Color(0xFFF1F0EC),
    surface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFE8E6E2),
    accent: Color(0xFF82725D),
    primaryText: Color(0xFF252525),
    mutedText: Color(0xFF777777),
    border: Color(0xFFD6D3CC),
    onAccent: Color(0xFFFFFFFF),
  );

  static const whiteGreenPalette = AppPalette(
    background: Color(0xFFF7F8F7),
    surface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFE8EFE8),
    accent: Color(0xFF527452),
    primaryText: Color(0xFF202420),
    mutedText: Color(0xFF777777),
    border: Color(0xFFE4E7E4),
    onAccent: Color(0xFFFFFFFF),
  );

  static const lightRedPalette = AppPalette(
    background: Color(0xFFF2F1EE),
    surface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFE8E1DD),
    accent: Color(0xFF8C3434),
    primaryText: Color(0xFF292929),
    mutedText: Color(0xFF777777),
    border: Color(0xFFD6D4D0),
    onAccent: Color(0xFFFFFFFF),
  );

  static ThemeData get dark => themeFor(PaintbenchTheme.darkGold);

  static ThemeData themeFor(PaintbenchTheme theme) {
    final palette = theme.palette;
    final brightness = theme == PaintbenchTheme.darkGold
        ? Brightness.dark
        : Brightness.light;
    final generatedColorScheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      surface: palette.surface,
    );
    final colorScheme = brightness == Brightness.dark
        ? generatedColorScheme
        : generatedColorScheme.copyWith(
            primary: palette.accent,
            onPrimary: palette.onAccent,
            secondary: palette.accent,
            onSecondary: palette.onAccent,
            surface: palette.surface,
            onSurface: palette.primaryText,
            outline: palette.border,
          );
    final borderSide = BorderSide(color: palette.border);
    final textTheme = TextTheme(
      headlineMedium: TextStyle(
        color: palette.primaryText,
        fontSize: 27,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        height: 1.12,
      ),
      titleLarge: TextStyle(
        color: palette.primaryText,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleMedium: TextStyle(
        color: palette.primaryText,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: palette.primaryText,
        fontSize: 14,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        color: palette.mutedText,
        fontSize: 13,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        color: palette.mutedText,
        fontSize: 11,
        height: 1.35,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      colorScheme: colorScheme,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.primaryText,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: palette.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: borderSide,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: palette.primaryText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: borderSide,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.elevatedSurface,
        contentTextStyle: TextStyle(color: palette.primaryText),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        hintStyle: TextStyle(color: palette.mutedText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.accent, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.accent,
          side: BorderSide(color: palette.accent.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.accent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accent),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        height: 68,
        indicatorColor: palette.accent.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? palette.accent
              : palette.mutedText;
          return TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? palette.accent
              : palette.mutedText;
          return IconThemeData(color: color, size: 23);
        }),
      ),
      textTheme: textTheme,
    );
  }
}
