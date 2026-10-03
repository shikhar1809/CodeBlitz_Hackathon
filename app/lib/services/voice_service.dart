import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Speaks Winger's lines and the offline companion with the phone's voice.
class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool speaking = false;

  Future<void> _init(String lang) async {
    try {
      await _tts.setLanguage(lang == 'hi' ? 'hi-IN' : 'en-IN');
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } catch (_) {}
  }

  Future<void> say(String text, {String lang = 'en'}) async {
    if (!_ready) await _init(lang);
    speaking = true;
    try {
      await _tts.speak(text).timeout(const Duration(seconds: 15));
    } catch (_) {
    } finally {
      speaking = false;
    }
  }

  Future<void> stop() async {
    speaking = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
