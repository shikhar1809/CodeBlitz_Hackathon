import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../core/l10n/app_language.dart';

/// Speech to text, for what the doctor and the chemist said.
///
/// Speaking must produce text, or the feature is a lie (ADR-27): a recording
/// nobody can read does not cross-check against anything.
class Dictation {
  Dictation({SpeechToText? engine}) : _injected = engine;

  final SpeechToText? _injected;
  SpeechToText? _lazy;
  SpeechToText get _stt => _injected ?? (_lazy ??= SpeechToText());

  bool? _available;

  bool get listening => _available == true && _stt.isListening;

  /// Whether this device can dictate at all. Asked once.
  Future<bool> available() async {
    if (_available != null) return _available!;
    try {
      return _available = await _stt.initialize();
    } catch (_) {
      return _available = false;
    }
  }

  /// Listen until [onFinal] fires or [stop] is called. Partial results stream
  /// through [onWords] so the screen shows the words as they arrive.
  ///
  /// [onLevel], when given, hears how loud the room is, from 0 to 1, for a
  /// level meter — so a person can see the phone is hearing them.
  Future<bool> listen({
    required AppLanguage language,
    required void Function(String words, bool done) onWords,
    void Function(double level)? onLevel,
  }) async {
    if (!await available()) return false;
    final scale = SoundLevelScale();
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: language.locale.replaceAll('-', '_'),
          // A doctor explaining three medicines takes a while, and pauses
          // to think; six seconds of quiet is not the end of the visit.
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 6),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (r) => onWords(r.recognizedWords, r.finalResult),
        onSoundLevelChange: onLevel == null
            ? null
            : (dB) => onLevel(scale.normalise(dB)),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    if (_available != true) return;
    try {
      await _stt.stop();
    } catch (_) {}
  }
}

/// Turns the engine's sound level into 0..1 for a meter.
///
/// The number means different things on different phones: Android reports an
/// RMS level of roughly -2 to 10 dB, iOS a negative dB figure, the web
/// nothing at all. So the scale starts at Android's range and widens to
/// whatever it actually sees — a meter that moves, not a measurement. Whether
/// anything was *heard* is decided by the words, never by this.
class SoundLevelScale {
  double _low = -2;
  double _high = 10;

  double normalise(double dB) {
    if (!dB.isFinite) return 0;
    if (dB < _low) _low = dB;
    if (dB > _high) _high = dB;
    return ((dB - _low) / (_high - _low)).clamp(0.0, 1.0);
  }
}
