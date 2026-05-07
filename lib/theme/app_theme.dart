import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static const _borderRadius = 10.0;
  static const _borderRadiusLg = 14.0;

  static TextTheme _buildTextTheme(Color primary, Color secondary, Color tertiary) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: primary, fontWeight: FontWeight.w700, letterSpacing: -1.5),
      displayMedium: base.displayMedium?.copyWith(color: primary, fontWeight: FontWeight.w700, letterSpacing: -1.0),
      displaySmall: base.displaySmall?.copyWith(color: primary, fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineLarge: base.headlineLarge?.copyWith(color: primary, fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineMedium: base.headlineMedium?.copyWith(color: primary, fontWeight: FontWeight.w600),
      headlineSmall: base.headlineSmall?.copyWith(color: primary, fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(color: primary, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: base.titleMedium?.copyWith(color: primary, fontWeight: FontWeight.w500, fontSize: 15),
      titleSmall: base.titleSmall?.copyWith(color: secondary, fontWeight: FontWeight.w500, fontSize: 13),
      bodyLarge: base.bodyLarge?.copyWith(color: primary, fontSize: 15, height: 1.6),
      bodyMedium: base.bodyMedium?.copyWith(color: secondary, fontSize: 14, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(color: tertiary, fontSize: 12, height: 1.4),
      labelLarge: base.labelLarge?.copyWith(color: primary, fontWeight: FontWeight.w600, fontSize: 14),
      labelMedium: base.labelMedium?.copyWith(color: secondary, fontWeight: FontWeight.w500, fontSize: 12),
      labelSmall: base.labelSmall?.copyWith(color: tertiary, fontWeight: FontWeight.w500, fontSize: 11),
    );
  }

  static ThemeData dark() {
    const cs = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: Colors.black,
      primaryContainer: AppColors.accentSurface,
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.info,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF1A1D3A),
      onSecondaryContainer: AppColors.info,
      tertiary: AppColors.idle,
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFF2B2200),
      onTertiaryContainer: AppColors.idle,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: Color(0xFF3A0A0A),
      onErrorContainer: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.surfaceBorder,
      outlineVariant: AppColors.textMuted,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.accentDim,
      surfaceTint: AppColors.accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _buildTextTheme(AppColors.textPrimary, AppColors.textSecondary, AppColors.textTertiary),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_borderRadius)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.surfaceBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_borderRadius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_borderRadius)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceElevated,
        selectedColor: AppColors.accentSurface,
        disabledColor: AppColors.surfaceElevated,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        secondaryLabelStyle: const TextStyle(color: AppColors.accent, fontSize: 12),
        side: const BorderSide(color: AppColors.surfaceBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadiusLg),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.surfaceElevated,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadiusLg),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        titleTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        contentTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accentSurface;
          return AppColors.surfaceElevated;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accentBorder;
          return AppColors.surfaceBorder;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceElevated,
        circularTrackColor: AppColors.surfaceElevated,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.textMuted),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(4),
        thumbVisibility: WidgetStateProperty.all(false),
      ),
    );
  }

  static ThemeData light() {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accentDim,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD4F5E4),
      onPrimaryContainer: Color(0xFF005228),
      secondary: AppColors.info,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE4E6FF),
      onSecondaryContainer: Color(0xFF1A1D6A),
      tertiary: AppColors.idle,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFF4CC),
      onTertiaryContainer: Color(0xFF4A3500),
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: Color(0xFFFFE4E4),
      onErrorContainer: Color(0xFF6D0000),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      outline: AppColors.lightSurfaceBorder,
      outlineVariant: Color(0xFFD0D5DD),
      shadow: Colors.black,
      scrim: Colors.black38,
      inverseSurface: AppColors.lightTextPrimary,
      onInverseSurface: AppColors.lightBackground,
      inversePrimary: AppColors.accent,
      surfaceTint: AppColors.accentDim,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: _buildTextTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary, AppColors.lightTextTertiary),
      cardTheme: CardTheme(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          side: const BorderSide(color: AppColors.lightSurfaceBorder, width: 1),
        ),
      ),
    );
  }
}
