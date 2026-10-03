import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a buzz means. Four words, used the same way on every screen.
enum HapticKind {
  /// A choice was made: a tile, Next, Continue, the mic.
  tap,

  /// Something was saved or finished: "All taken", a recording kept.
  confirm,

  /// It did not work: a wrong OTP or PIN, a recording with nothing in it.
  error,

  /// Needs attention now.
  alarm,
}

/// The one place the app touches [HapticFeedback].
///
/// Screens say what happened ([tap], [confirm], [error], [alarm]), never which
/// motor to run, so the vocabulary stays consistent and one switch
/// ([enabled]) turns all of it off. Every call is fire-and-forget and never
/// throws: a phone without a motor is not an error.
abstract final class Haptics {
  /// The global switch, for a setting. Off means silent everywhere.
  static bool enabled = true;

  /// Test seam: when set, calls land here instead of on the motor.
  @visibleForTesting
  static void Function(HapticKind kind)? debugOverride;

  static void tap() => fire(HapticKind.tap);
  static void confirm() => fire(HapticKind.confirm);
  static void error() => fire(HapticKind.error);
  static void alarm() => fire(HapticKind.alarm);

  static void fire(HapticKind kind) {
    if (!enabled) return;
    final override = debugOverride;
    if (override != null) {
      override(kind);
      return;
    }
    switch (kind) {
      case HapticKind.tap:
        _run(HapticFeedback.selectionClick);
      case HapticKind.confirm:
        _run(HapticFeedback.mediumImpact);
      case HapticKind.error:
        _run(HapticFeedback.heavyImpact);
        _run(HapticFeedback.vibrate);
      case HapticKind.alarm:
        // The platform API has no pattern; three buzzes a beat apart is the
        // closest honest approximation.
        _run(HapticFeedback.vibrate);
        for (final ms in const [350, 700]) {
          Timer(Duration(milliseconds: ms), () => _run(HapticFeedback.vibrate));
        }
    }
  }

  /// [then], preceded by a buzz of [kind] — or null when [then] is null, so a
  /// disabled button stays disabled: `onPressed: Haptics.on(save)`.
  static VoidCallback? on(
    VoidCallback? then, [
    HapticKind kind = HapticKind.tap,
  ]) {
    if (then == null) return null;
    return () {
      fire(kind);
      then();
    };
  }

  static void _run(Future<void> Function() call) {
    try {
      unawaited(call().catchError((Object _) {}));
    } catch (_) {}
  }
}
