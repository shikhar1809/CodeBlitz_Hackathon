import 'package:flutter/foundation.dart';

import 'core/geo.dart';

/// Build-time switches (`--dart-define`). Web is always a demo build.
const bool _demoFlag = bool.fromEnvironment('WINGER_DEMO');
bool get isDemo => _demoFlag || kIsWeb;

/// ElevenLabs voice agent for the call. Empty = offline companion only.
const String wingerAgentId = String.fromEnvironment('WINGER_AGENT_ID');

/// ElevenLabs text agent for the Help chat. Empty = bundled guides only.
const String wingerChatAgentId = String.fromEnvironment('WINGER_CHAT_AGENT_ID');

class Demo {
  static const name = 'Demo User';
  static const guardianName = 'Guardian';
  static const guardianPhone = '+91 98000 00001';
  static const pin = '2580';
  static const duressPin = '1379';
  static const checkInEvery = Duration(seconds: 60);

  /// Hazratganj, Lucknow, and the demo destination Charbagh Station.
  static const here = LatLon(26.8485, 80.9420);
  static const charbagh = LatLon(26.8320, 80.9220);
}

const Duration realCheckInEvery = Duration(minutes: 15);
const double maxPhoneWidth = 440;
