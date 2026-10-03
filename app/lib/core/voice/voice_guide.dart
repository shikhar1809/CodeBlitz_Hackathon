import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../l10n/app_language.dart';
import 'kokoro_tts.dart';
import 'speech_engine.dart';

/// Which engine said the last sentence, and how long the user waited for it.
@immutable
class VoiceStatus {
  const VoiceStatus({
    required this.text,
    required this.result,
    required this.elapsed,
  });

  final String text;
  final SpeakResult result;

  /// From asking to the audio starting.
  final Duration elapsed;

  /// The engine that spoke, or null: the screen's text was all there was.
  String? get spokenBy => result.spokenBy;

  /// One line for the debug overlay, e.g.
  /// `voice: device · 4003 ms (kokoro: timeout)`.
  String describe() {
    final who = spokenBy ?? 'none, text only';
    final why = result.misses.entries
        .map((e) => '${e.key}: ${e.value.name}')
        .join(', ');
    return 'voice: $who · ${elapsed.inMilliseconds} ms'
        '${why.isEmpty ? '' : ' ($why)'}';
  }
}

/// Reads screens aloud — and makes sure only the newest screen is talking.
///
/// Without an owner, a user who moves quickly hears the previous screen talking
/// over the new one. So speaking claims the voice with an owner token; a screen
/// stops the voice on its way out only if it still owns it; and a sentence that
/// finishes loading after its screen has gone is simply dropped.
class VoiceGuide extends ChangeNotifier {
  VoiceGuide({SpeechEngine? engine, this.enabled = false})
    : _engine =
          engine ??
          ChainEngine([KokoroEngine(tts: KokoroTts()), DeviceTtsEngine()]);

  /// Show the one-line voice status on every [VoicePrompt]. Off unless
  /// `main.dart` turns it on in a debug build; tests (and so goldens, which
  /// run in debug mode) never see it unless they ask.
  static bool showDebugStatus = false;

  final SpeechEngine _engine;

  bool enabled;

  Object? _speaker;

  /// Who holds the voice right now.
  Object? get speaker => _speaker;

  /// The last sentence the current owner asked for, and who said it. Null
  /// until something has been spoken.
  final ValueNotifier<VoiceStatus?> status = ValueNotifier(null);

  /// Speak [text] for [owner], replacing whatever was playing.
  ///
  /// Returns what happened, or null when nothing was attempted (voice off,
  /// empty text, or another screen claimed the voice first).
  Future<SpeakResult?> speak(
    Object owner,
    String text,
    AppLanguage language,
  ) async {
    if (!enabled || text.trim().isEmpty) return null;
    final previous = _speaker;
    _speaker = owner;
    if (previous != null) await _engine.stop();
    // Another screen may have claimed the voice while we were stopping.
    if (!identical(_speaker, owner)) return null;
    final watch = Stopwatch()..start();
    final result = await _engine.speak(text, language);
    if (identical(_speaker, owner) && !result.superseded) {
      status.value = VoiceStatus(
        text: text,
        result: result,
        elapsed: watch.elapsed,
      );
    }
    return result;
  }

  /// Stop only if [owner] is the one speaking. A screen leaving must never
  /// silence the screen that replaced it.
  Future<void> stopIfSpeaking(Object owner) async {
    if (!identical(_speaker, owner)) return;
    _speaker = null;
    await _engine.stop();
  }

  Future<void> stopAll() async {
    _speaker = null;
    await _engine.stop();
  }

  @override
  void dispose() {
    status.dispose();
    super.dispose();
  }
}

class VoiceScope extends InheritedWidget {
  const VoiceScope({super.key, required this.guide, required super.child});

  final VoiceGuide guide;

  static VoiceGuide? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoiceScope>()?.guide;

  @override
  bool updateShouldNotify(VoiceScope old) => old.guide != guide;
}

/// The debug voice line: which engine spoke and how long it took. Renders
/// nothing outside a debug build, or until [VoiceGuide.showDebugStatus] is on.
class VoiceStatusLine extends StatelessWidget {
  const VoiceStatusLine({super.key, required this.guide});

  final VoiceGuide guide;

  static bool get visible => kDebugMode && VoiceGuide.showDebugStatus;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return IgnorePointer(
      child: ValueListenableBuilder<VoiceStatus?>(
        valueListenable: guide.status,
        builder: (context, status, _) {
          if (status == null) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: const Color(0xB3000000),
            child: Text(
              status.describe(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 10,
                decoration: TextDecoration.none,
              ),
            ),
          );
        },
      ),
    );
  }
}
