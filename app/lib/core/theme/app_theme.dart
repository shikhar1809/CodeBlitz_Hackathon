import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The elderly-first type and spacing scale, baked into [ThemeData] so that no
/// screen can quietly break it.
///
/// Body text never drops below 20pt on a patient-facing screen, and every button
/// and tile starts at a 64px tap target. Those two numbers are the whole
/// accessibility story of this app, so they live in the theme rather than in a
/// style guide nobody reads.
abstract final class AppTheme {
  /// Every button and tile starts here.
  static const double tapTarget = 64;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );

  static const double radius = 20;

  /// The portrait phone frame used on desktop and web.
  static const double phoneWidth = 412;
  static const double phoneHeight = 892;

  static const String fontFamily = 'NotoSans';

  /// Devanagari is a fallback on *every* text style, not a separate theme — a
  /// Hindi medicine note inside an English screen still has to render.
  static const List<String> fontFamilyFallback = <String>['NotoSansDevanagari'];

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: Colors.white,
      secondary: AppColors.amber,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.red,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: AppColors.paper,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        surfaceTintColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        iconTheme: IconThemeData(color: AppColors.inkSoft, size: 28),
        actionsIconTheme: IconThemeData(color: AppColors.inkSoft, size: 28),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(color: AppColors.ink, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
        hintStyle: const TextStyle(fontSize: 20, color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.hairline, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.hairline, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.ink, width: 2),
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.ink : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 18,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    TextStyle style(double size, FontWeight weight, {Color? color}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: size,
          fontWeight: weight,
          color: color ?? AppColors.ink,
          height: 1.32,
        );

    return base.copyWith(
      displayLarge: style(40, FontWeight.w700),
      displayMedium: style(34, FontWeight.w700),
      headlineLarge: style(30, FontWeight.w700),
      headlineMedium: style(26, FontWeight.w700),
      titleLarge: style(24, FontWeight.w700),
      titleMedium: style(22, FontWeight.w600),
      // Body never drops below 20 on a patient-facing screen.
      bodyLarge: style(22, FontWeight.w400),
      bodyMedium: style(20, FontWeight.w400),
      bodySmall: style(18, FontWeight.w400, color: AppColors.muted),
      labelLarge: style(22, FontWeight.w700),
      labelMedium: style(18, FontWeight.w600, color: AppColors.muted),
    );
  }
}
