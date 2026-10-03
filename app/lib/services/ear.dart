import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/phrase_match.dart';

enum Heard { safePhrase, cryForHelp, speech }

class HeardEvent {
  final Heard kind;
  final String words;
  final String? phrase;
  const HeardEvent(this.kind, this.words, [this.phrase]);
}

/// Listens on the phone and reports safe phrases, cries for help and plain
/// speech (for turn-taking). Restarts itself when the recogniser stops.
class Ear {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  bool _on = false;
  List<String> phrases = const [];
  void Function(HeardEvent e)? onHeard;
  String _lastFinal = '';

  bool get available => _available;
  bool get on => _on;

  Future<bool> start({required List<String> phrases, required void Function(HeardEvent) onHeard}) async {
    this.phrases = phrases;
    this.onHeard = onHeard;
    if (!_available) {
      try {
        _available = await _stt.initialize(
          onStatus: (s) {
            if ((s == 'done' || s == 'notListening') && _on) _restart();
          },
          onError: (_) {
            if (_on) _restart();
          },
        );
      } catch (_) {
        _available = false;
      }
    }
    if (!_available) return false;
    _on = true;
    await _listen();
    return true;
  }

  Timer? _restartTimer;
  void _restart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 400), () {
      if (_on && !_stt.isListening) _listen();
    });
  }

  Future<void> _listen() async {
    try {
      await _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 30),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (_) {}
  }

  final Set<String> _firedThisUtterance = {};

  void _onResult(SpeechRecognitionResult r) {
    final words = r.recognizedWords;
    if (words.isEmpty) return;
    final phrase = matchPhrase(words, phrases);
    if (phrase != null && _firedThisUtterance.add('p:$phrase')) {
      onHeard?.call(HeardEvent(Heard.safePhrase, words, phrase));
    } else if (isCryForHelp(words) && _firedThisUtterance.add('help')) {
      onHeard?.call(HeardEvent(Heard.cryForHelp, words));
    }
    if (r.finalResult && words != _lastFinal) {
      _lastFinal = words;
      _firedThisUtterance.clear();
      onHeard?.call(HeardEvent(Heard.speech, words));
    }
  }

  Future<void> stop() async {
    _on = false;
    _restartTimer?.cancel();
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
