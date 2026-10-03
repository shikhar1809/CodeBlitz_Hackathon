import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

/// Design tokens (plan section 4). Light theme always.
class W {
  static const page = Color(0xFFFAF7FC);
  static const card = Color(0xFFFFFFFF);
  static const container = Color(0xFFF2EEF7);
  static const containerHigh = Color(0xFFEDE8F4);
  static const containerHighest = Color(0xFFE6E0EE);
  static const outline = Color(0xFFE5DEEC);
  static const text = Color(0xFF241519);
  static const text2 = Color(0xFF6E5A5F);
  static const plum = Color(0xFF6B2A55);
  static const brandPlum = Color(0xFF4A1F3D);
  static const gold = Color(0xFFF6B042);
  static const coral = Color(0xFFE8674F);
  static const sos = Color(0xFFE5383B);
  static const leaf = Color(0xFF5B9A5A);
  static const indigo = Color(0xFF6B6FD6);
  static const marigold = Color(0xFFF08C1A);
  static const magenta = Color(0xFFC2417F);

  static const watching = Color(0xFF3DBE7B);
  static const checking = Color(0xFFFF8A00);
  static const alerting = Color(0xFFE5383B);
  static const silentHelp = Color(0xFFFFD400);

  static const green = [Color(0xFF7ADFA0), Color(0xFF34B36B)];
  static const orange = [Color(0xFFFFC15A), Color(0xFFF7861E)];
  static const violet = [Color(0xFFB9A4FF), Color(0xFF8662F0)];
  static const pink = [Color(0xFFFF9FB0), Color(0xFFF2557A)];

  static const shadow = [
    BoxShadow(color: Color(0x14101418), blurRadius: 18, offset: Offset(0, 6))
  ];

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: plum,
      primary: plum,
      surface: page,
      onSurface: text,
      error: sos,
    ).copyWith(
      surfaceContainerLow: card,
      surfaceContainer: container,
      surfaceContainerHigh: containerHigh,
      surfaceContainerHighest: containerHighest,
      outlineVariant: outline,
      onSurfaceVariant: text2,
    );
    const heading = TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.6);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      textTheme: const TextTheme(
        headlineLarge: heading,
        headlineMedium: heading,
        headlineSmall: heading,
        titleLarge: heading,
      ).apply(bodyColor: text, displayColor: text),
      appBarTheme: const AppBarTheme(
        backgroundColor: page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
            color: text, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: plum,
          minimumSize: const Size(64, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: outline)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: outline)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: page,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? plum : null),
      ),
    );
  }
}

/// The app's icons. Screens never name the icon pack directly.
class WIcons {
  static const home = IconsaxPlusBold.home_2;
  static const homeOff = IconsaxPlusLinear.home_2;
  static const help = IconsaxPlusBold.note_2;
  static const helpOff = IconsaxPlusLinear.note_2;
  static const profile = IconsaxPlusBold.profile_circle;
  static const profileOff = IconsaxPlusLinear.profile_circle;
  static const lock = IconsaxPlusBold.lock;
  static const route = IconsaxPlusBold.routing;
  static const shield = IconsaxPlusBold.shield_tick;
  static const locker = IconsaxPlusBold.lock_1;
  static const bell = IconsaxPlusBold.notification;
  static const mic = IconsaxPlusBold.microphone_2;
  static const keypad = IconsaxPlusBold.keyboard;
  static const shake = IconsaxPlusBold.mobile;
  static const call = IconsaxPlusBold.call_calling;
  static const camera = IconsaxPlusBold.camera;
  static const timer = IconsaxPlusBold.timer_1;
  static const location = IconsaxPlusBold.location;
  static const record = IconsaxPlusBold.record_circle;
  static const people = IconsaxPlusBold.people;
  static const danger = IconsaxPlusBold.danger;
  static const tick = IconsaxPlusBold.tick_circle;
  static const send = IconsaxPlusBold.send_1;
  static const user = IconsaxPlusBold.user;
  static const language = IconsaxPlusBold.language_square;
  static const voice = IconsaxPlusBold.voice_cricle;
  static const gallery = IconsaxPlusBold.gallery;
  static const key = IconsaxPlusBold.key;
  static const add = IconsaxPlusBold.user_add;
  static const close = IconsaxPlusBold.close_circle;
  static const info = IconsaxPlusBold.info_circle;
  static const activity = IconsaxPlusBold.activity;
  static const walk = IconsaxPlusBold.lamp_charge;
  static const car = IconsaxPlusBold.car;
  static const search = IconsaxPlusLinear.search_normal;
  static const arrowRight = IconsaxPlusBold.arrow_right_3;
  static const play = IconsaxPlusBold.play;
  static const pause = IconsaxPlusBold.pause;
  static const trash = IconsaxPlusBold.trash;
  static const share = IconsaxPlusBold.share;
  static const eye = IconsaxPlusBold.eye_slash;
  static const message = IconsaxPlusBold.message_text;
  static const warning = IconsaxPlusBold.warning_2;
  static const speaker = IconsaxPlusBold.volume_high;
  static const home3 = IconsaxPlusBold.house;
  static const flash = IconsaxPlusBold.flash_1;
}
