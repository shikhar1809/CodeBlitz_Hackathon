import 'package:flutter/material.dart';

/// The whole palette, in one place.
///
/// The status colours are darkened well past the Material defaults on purpose:
/// they carry the green / amber / red language used on verification cards, strip
/// checks and the dose calendar, and they have to stay apart for older eyes.
abstract final class AppColors {
  /// Brand accent — the amber of the logo mark.
  static const amber = Color(0xFFF6B20A);

  /// Accent on light fills, and "due now".
  static const amberDark = Color(0xFFC98D00);

  /// Attention fill.
  static const amberSoft = Color(0xFFFFF7DA);

  /// Attention border.
  static const amberBorder = Color(0xFFD9C06C);

  /// Primary text, and primary buttons.
  static const ink = Color(0xFF111111);

  /// Icons.
  static const inkSoft = Color(0xFF1B1A17);

  /// Secondary text.
  static const muted = Color(0xFF5D574B);

  /// Scaffold background.
  static const paper = Color(0xFFFFFDF5);

  /// Cards.
  static const surface = Color(0xFFFFFFFF);

  /// Borders.
  static const hairline = Color(0xFFE4DDCB);

  /// Agreed, and taken.
  static const green = Color(0xFF1B7A3D);
  static const greenSoft = Color(0xFFE3F3E8);

  /// Needs a look.
  static const warn = Color(0xFFB4690E);
  static const warnSoft = Color(0xFFFDF0DC);

  /// Conflict, and missed.
  static const red = Color(0xFFB3261E);
  static const redSoft = Color(0xFFFBE7E5);
}
