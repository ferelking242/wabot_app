import 'package:flutter/material.dart';

abstract final class AppColors {
  // Base surfaces
  static const Color background = Color(0xFF0D0E11);
  static const Color surface = Color(0xFF161719);
  static const Color surfaceElevated = Color(0xFF1C1E21);
  static const Color surfaceBorder = Color(0xFF2A2D32);
  static const Color surfaceHover = Color(0xFF1F2125);

  // Brand / accent
  static const Color accent = Color(0xFF25D366);
  static const Color accentDim = Color(0xFF1AAD4B);
  static const Color accentSurface = Color(0xFF0D2B1A);
  static const Color accentBorder = Color(0xFF1A4D2E);

  // Text hierarchy
  static const Color textPrimary = Color(0xFFF2F3F5);
  static const Color textSecondary = Color(0xFF9EA3AD);
  static const Color textTertiary = Color(0xFF5E636E);
  static const Color textMuted = Color(0xFF3D4047);

  // Status colors
  static const Color online = Color(0xFF25D366);
  static const Color idle = Color(0xFFFAA61A);
  static const Color offline = Color(0xFF747F8D);
  static const Color error   = Color(0xFFED4245);
  static const Color warning = Color(0xFFFAA61A);
  static const Color success = Color(0xFF25D366);
  static const Color info = Color(0xFF5865F2);

  // Log level colors
  static const Color logInfo = Color(0xFF57B6FF);
  static const Color logWarn = Color(0xFFFAA61A);
  static const Color logError = Color(0xFFED4245);
  static const Color logSuccess = Color(0xFF25D366);
  static const Color logDebug = Color(0xFF9EA3AD);

  // Light theme
  static const Color lightBackground = Color(0xFFF5F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF8F9FA);
  static const Color lightSurfaceBorder = Color(0xFFE4E7EB);
  static const Color lightTextPrimary = Color(0xFF0D0E11);
  static const Color lightTextSecondary = Color(0xFF5E636E);
  static const Color lightTextTertiary = Color(0xFF9EA3AD);

  // Chart palette
  static const List<Color> chartPalette = [
    Color(0xFF25D366),
    Color(0xFF5865F2),
    Color(0xFFFAA61A),
    Color(0xFFED4245),
    Color(0xFF57B6FF),
    Color(0xFFEB459E),
  ];
}
