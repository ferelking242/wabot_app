import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// Palette Wabot — vert WhatsApp
class WabotPalette {
  WabotPalette._();
  static const Color green    = Color(0xFF25D366);
  static const Color greenDk  = Color(0xFF128C7E);
  static const Color greenLt  = Color(0xFF34E07E);
  static const Color dark     = Color(0xFF0A0C0F);
  static const Color darkCard = Color(0xFF111316);
  static const Color border   = Color(0xFF1E2128);
  static const Color ink      = Color(0xFFF2F3F5);
  static const Color muted    = Color(0xFF8A9199);
}

/// Garde l'ancien alias pour les widgets qui l'utilisent encore
class ScolarisPalette {
  ScolarisPalette._();
  static const Color terracotta  = WabotPalette.green;
  static const Color orange      = WabotPalette.greenDk;
  static const Color gold        = WabotPalette.greenLt;
  static const Color forestGreen = WabotPalette.green;
  static const Color cream       = Color(0xFF0D0E11);
}

class AppTheme {
  AppTheme._();

  static ThemeData light({Color? accent}) {
    final seed = accent ?? WabotPalette.green;
    return FlexThemeData.light(
      colors: FlexSchemeColor.from(primary: seed, brightness: Brightness.light),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      appBarStyle: FlexAppBarStyle.surface,
      subThemesData: const FlexSubThemesData(
        defaultRadius: 12, inputDecoratorRadius: 12,
        cardRadius: 16, dialogRadius: 20,
        elevatedButtonSchemeColor: SchemeColor.primary,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
    );
  }

  static ThemeData dark({Color? accent}) {
    final seed = accent ?? WabotPalette.green;
    return FlexThemeData.dark(
      colors: FlexSchemeColor.from(primary: seed, brightness: Brightness.dark),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      appBarStyle: FlexAppBarStyle.background,
      subThemesData: const FlexSubThemesData(
        defaultRadius: 12, inputDecoratorRadius: 12,
        cardRadius: 16, dialogRadius: 20,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
    );
  }
}
