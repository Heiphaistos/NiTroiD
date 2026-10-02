import 'package:flutter/material.dart';

/// Palette partagée avec NiTriTe (site web et éditions desktop).
class NxColors {
  static const primary = Color(0xFF00D4FF);
  static const secondary = Color(0xFF7C3AED);
  static const accent = Color(0xFFF59E0B);
  static const dark = Color(0xFF0A0E27);
  static const surface = Color(0xFF121735);
  static const surfaceHigh = Color(0xFF1A2046);
  static const ok = Color(0xFF22C55E);
  static const warn = Color(0xFFF59E0B);
  static const bad = Color(0xFFEF4444);
  static const muted = Color(0xFF8B93B8);

  static Color forStatus(String status) {
    switch (status) {
      case 'ok':
        return ok;
      case 'warn':
        return warn;
      case 'bad':
        return bad;
      default:
        return primary;
    }
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NxColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: NxColors.primary,
    secondary: NxColors.secondary,
    tertiary: NxColors.accent,
    surface: NxColors.dark,
    surfaceContainerLowest: NxColors.dark,
    surfaceContainerLow: NxColors.surface,
    surfaceContainer: NxColors.surface,
    surfaceContainerHigh: NxColors.surfaceHigh,
    surfaceContainerHighest: NxColors.surfaceHigh,
    error: NxColors.bad,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NxColors.dark,
    appBarTheme: const AppBarTheme(
      backgroundColor: NxColors.dark,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3),
    ),
    cardTheme: CardThemeData(
      color: NxColors.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: NxColors.primary.withValues(alpha: 0.12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NxColors.surface,
      indicatorColor: NxColors.primary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: NxColors.primary),
    dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.06), space: 1),
  );
}
