import 'package:flutter/material.dart';

/// 宣纸米白 + 墨黑 + 朱砂红。
class ZiliColors {
  ZiliColors._();

  static const paper = Color(0xFFFAF6EF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF4EEE4);
  static const surfaceTint = Color(0xFFF7EDE7);

  static const ink = Color(0xFF2A2724);
  static const inkSoft = Color(0xFF6E665C);
  static const inkFaint = Color(0xFF8C8378);

  static const line = Color(0xFFE5DCCC);
  static const gridLine = Color(0xFFDCD2C0);

  static const cinnabar = Color(0xFFB23A2E);
  static const cinnabarDeep = Color(0xFF8E2C22);
  static const cinnabarSoft = Color(0xFFF6E7E3);
}

class ZiliTheme {
  ZiliTheme._();

  static ThemeData build() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: ZiliColors.paper,
      colorScheme: base.colorScheme.copyWith(
        primary: ZiliColors.cinnabar,
        onPrimary: Colors.white,
        secondary: ZiliColors.cinnabarDeep,
        surface: ZiliColors.surface,
        onSurface: ZiliColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ZiliColors.paper,
        foregroundColor: ZiliColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: ZiliColors.ink,
        displayColor: ZiliColors.ink,
      ),
      dividerTheme: const DividerThemeData(
        color: ZiliColors.line,
        thickness: 0.5,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ZiliColors.cinnabar,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZiliColors.cinnabar,
          side: const BorderSide(color: ZiliColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Serif family suits character display better than the default sans.
  static const String glyphFontFamily = 'serif';
}
