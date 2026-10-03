import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// SMS, calls and vibration. On Android these go through the `winger/alerts`
/// channel (direct SMS, direct call); on web and in tests they are simulated.
class AlertService {
  static const _ch = MethodChannel('winger/alerts');

  /// Set in tests and on web: nothing leaves the phone.
  final bool simulate;
  AlertService({bool? simulate}) : simulate = simulate ?? kIsWeb;

  /// Returns true when the SMS really went out.
  Future<bool> sendSms(String to, String body) async {
    if (simulate) return false;
    try {
      return await _ch.invokeMethod<bool>('sendSms', {'to': to, 'body': body}) ??
          false;
    } catch (_) {
      // No channel: hand it to the SMS app instead.
      return launchUrl(Uri(scheme: 'sms', path: to, queryParameters: {'body': body}));
    }
  }

  Future<bool> call(String number) async {
    if (simulate) return false;
    try {
      return await _ch.invokeMethod<bool>('call', {'to': number}) ?? false;
    } catch (_) {
      return launchUrl(Uri(scheme: 'tel', path: number));
    }
  }

  Future<void> vibrate() async {
    try {
      await HapticFeedback.heavyImpact();
      if (!simulate) await _ch.invokeMethod('vibrate');
    } catch (_) {}
  }

  /// Opens the dialler with 112 ready (always a real action, never automatic
  /// on web).
  Future<void> dial112() => launchUrl(Uri(scheme: 'tel', path: '112'));
}
