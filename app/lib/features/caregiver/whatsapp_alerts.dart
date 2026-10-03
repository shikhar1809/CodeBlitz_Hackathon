import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// What actually happened to a message. The screen never says "sent" when a
/// message was only drafted.
enum AlertDelivery { sentAutomatically, openedInWhatsApp, failed }

/// The outcome of an automatic send, with whether trying again could help.
class SendResult {
  const SendResult.ok() : sent = true, retryable = false;
  const SendResult.failed({required this.retryable}) : sent = false;

  final bool sent;

  /// A dropped connection is worth another go; a bad number never is.
  final bool retryable;
}

/// WhatsApp, two ways.
///
/// With Twilio credentials the message sends itself — a *missed* dose needs
/// that, because the patient has not done anything, so there is nobody to
/// press send. Without them, WhatsApp opens with the message ready and a
/// person presses send; for sharing a plan that is arguably the right answer,
/// not a degraded one.
class WhatsAppAlerts {
  WhatsAppAlerts({
    http.Client? client,
    Future<bool> Function(Uri)? launcher,
    this.accountSid = const String.fromEnvironment('TWILIO_ACCOUNT_SID'),
    this.authToken = const String.fromEnvironment('TWILIO_AUTH_TOKEN'),
    this.fromNumber = const String.fromEnvironment('TWILIO_WHATSAPP_FROM'),
  }) : _injected = client {
    _launcher = launcher;
  }

  final String accountSid;
  final String authToken;
  final String fromNumber;

  final http.Client? _injected;
  http.Client? _lazy;
  http.Client get _http => _injected ?? (_lazy ??= http.Client());

  late final Future<bool> Function(Uri)? _launcher;

  bool get automatic =>
      accountSid.isNotEmpty && authToken.isNotEmpty && fromNumber.isNotEmpty;

  /// Any way a person might type an Indian mobile number, to +91XXXXXXXXXX.
  /// Anything else is null — a typo becomes a visible error, not a message
  /// to nobody.
  static String? normalise(String? input) {
    if (input == null) return null;
    var digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) {
      digits = digits.substring(1);
      if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
      return null;
    }
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    if (digits.length == 10 && RegExp(r'^[6-9]').hasMatch(digits)) {
      return '+91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return null;
  }

  /// Twilio's Messages API, from the WhatsApp sender.
  Future<SendResult> sendAutomatic(String to, String body) async {
    if (!automatic) return const SendResult.failed(retryable: false);
    final number = normalise(to);
    if (number == null) return const SendResult.failed(retryable: false);
    try {
      final r = await _http
          .post(
            Uri.parse(
              'https://api.twilio.com/2010-04-01/Accounts/$accountSid/'
              'Messages.json',
            ),
            headers: {
              'Authorization':
                  'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'From': 'whatsapp:${_plus(fromNumber)}',
              'To': 'whatsapp:$number',
              'Body': body,
            },
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return const SendResult.ok();
      }
      // Rate-limited or the server is having a bad day: try again later.
      // Anything else in 4xx is this message's fault and always will be.
      return SendResult.failed(
        retryable: r.statusCode == 429 || r.statusCode >= 500,
      );
    } catch (_) {
      return const SendResult.failed(retryable: true);
    }
  }

  /// wa.me with the text ready. No credentials needed.
  static Uri deepLink(String to, String body) => Uri.parse(
    'https://wa.me/${to.replaceAll('+', '')}'
    '?text=${Uri.encodeComponent(body)}',
  );

  Future<AlertDelivery> openInWhatsApp(String to, String body) async {
    final number = normalise(to);
    if (number == null) return AlertDelivery.failed;
    try {
      final launch =
          _launcher ??
          (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
      return await launch(deepLink(number, body))
          ? AlertDelivery.openedInWhatsApp
          : AlertDelivery.failed;
    } catch (_) {
      return AlertDelivery.failed;
    }
  }

  /// A message a person asked to send: automatic when it can be, otherwise
  /// WhatsApp opened for them.
  Future<AlertDelivery> send(String to, String body) async {
    if (automatic) {
      final r = await sendAutomatic(to, body);
      if (r.sent) return AlertDelivery.sentAutomatically;
    }
    return openInWhatsApp(to, body);
  }

  static String _plus(String n) => n.startsWith('+') ? n : '+$n';
}
