import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/app_language.dart';
import 'kokoro_tts.dart';
import 'speech_result.dart';

export 'speech_result.dart';

/// Something that can say a sentence out loud, and be stopped.
abstract class SpeechEngine {
  /// Short and stable: shown in the debug voice line and kept in results.
  String get name;

  /// Start saying [text]. A result that did not speak lets the next engine in
  /// the chain try.
  Future<SpeakResult> speak(String text, AppLanguage language);

  Future<void> stop();
}

/// Where Kokoro's WAV goes. A seam, so tests never build a real player.
abstract class AudioSink {
  Future<void> playFile(String path);
  Future<void> playBytes(Uint8List bytes);
  Future<void> stop();
}

/// `audioplayers`, built the first time it is needed.
class AudioPlayersSink implements AudioSink {
  AudioPlayer? _lazy;
  AudioPlayer get _player => _lazy ??= AudioPlayer();

  @override
  Future<void> playFile(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  @override
  Future<void> playBytes(Uint8List bytes) async {
    await _player.stop();
    await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
  }

  @override
  Future<void> stop() async {
    if (_lazy == null) return;
    await _lazy!.stop();
  }
}

/// Kokoro audio: from the cache at once, or live within [liveDeadline].
///
/// Measured against the real Space, a warm sentence takes five to seven
/// seconds end to end, and an uncached DNS lookup alone can take eleven (see
/// docs/GOTCHAS.md). Silence that long reads as a broken app, so a live fetch
/// gets [liveDeadline] and then steps aside for the next engine. The fetch is
/// not abandoned: it finishes in [KokoroTts], lands in the cache, and the
/// next time the sentence is due it plays from there. A late result is never
/// played — by then another voice has already said it.
///
/// Once a deadline has been missed, later uncached sentences do not wait at
/// all (they still fetch, to warm the cache) until a fetch comes back inside
/// the deadline again.
class KokoroEngine implements SpeechEngine {
  KokoroEngine({
    KokoroTts? tts,
    AudioSink? sink,
    this.liveDeadline = const Duration(seconds: 4),
  }) : _tts = tts ?? KokoroTts(),
       _sink = sink ?? AudioPlayersSink();

  final KokoroTts _tts;
  final AudioSink _sink;

  /// How long a user may wait in silence for a sentence that is not cached.
  final Duration liveDeadline;

  KokoroTts get tts => _tts;

  @override
  String get name => 'kokoro';

  bool _slow = false;

  /// True while live fetches are known to miss [liveDeadline].
  bool get slow => _slow;

  // Bumped by stop(): a sentence that started under an older generation has
  // been replaced (ADR-15) and must not start playing.
  int _generation = 0;

  final _background = <Future<void>>{};

  /// Fetches still running after their sentence was handed on. Tests await
  /// this; the app never needs to.
  Future<void> get backgroundDone => Future.wait(_background.toList());

  @override
  Future<SpeakResult> speak(String text, AppLanguage language) async {
    final generation = _generation;
    final hit = await _tts.cached(text, language);
    if (generation != _generation) return _missed(SpeechMiss.superseded);
    if (hit != null) return _play(text, language, hit);
    if (_tts.unreachable) return _missed(SpeechMiss.unreachable);

    final fetch = _tts.fetch(text, language);
    if (_slow) {
      _finishInBackground(fetch);
      return _missed(SpeechMiss.slow);
    }
    final result = await _within(fetch, liveDeadline);
    if (result == null) {
      _slow = true;
      _finishInBackground(fetch);
      return _missed(SpeechMiss.timeout);
    }
    _learn(result);
    if (generation != _generation) return _missed(SpeechMiss.superseded);
    final bytes = result.bytes;
    if (bytes == null) return _missed(result.failure ?? SpeechMiss.error);
    return _play(text, language, bytes);
  }

  Future<SpeakResult> _play(
    String text,
    AppLanguage language,
    Uint8List bytes,
  ) async {
    try {
      final path = await _tts.cache.pathFor(
        KokoroTts.cacheKey(text, language, 1.0),
      );
      if (path != null) {
        await _sink.playFile(path);
      } else {
        await _sink.playBytes(bytes);
      }
      return SpeakResult.spoke(name);
    } catch (_) {
      return _missed(SpeechMiss.playbackError);
    }
  }

  SpeakResult _missed(SpeechMiss why) => SpeakResult.missed(name, why);

  /// The fetch's result if it arrives within [deadline], else null. The
  /// timer is cancelled as soon as the fetch lands, so nothing is left
  /// pending.
  static Future<KokoroFetch?> _within(
    Future<KokoroFetch> fetch,
    Duration deadline,
  ) {
    final done = Completer<KokoroFetch?>();
    final timer = Timer(deadline, () {
      if (!done.isCompleted) done.complete(null);
    });
    fetch.then((r) {
      timer.cancel();
      if (!done.isCompleted) done.complete(r);
    });
    return done.future;
  }

  void _finishInBackground(Future<KokoroFetch> fetch) {
    late final Future<void> tracked;
    tracked = fetch
        .then(_learn)
        .whenComplete(() => _background.remove(tracked));
    _background.add(tracked);
  }

  /// A fetch that came back inside the deadline means waiting is worth it
  /// again.
  void _learn(KokoroFetch result) {
    if (result.bytes != null && result.elapsed <= liveDeadline) _slow = false;
  }

  @override
  Future<void> stop() async {
    _generation++;
    try {
      await _sink.stop();
    } catch (_) {}
  }
}

/// The phone's own TTS. A fallback: robotic, and often without a Hindi voice.
class DeviceTtsEngine implements SpeechEngine {
  FlutterTts? _lazy;
  FlutterTts get _tts => _lazy ??= FlutterTts();

  final _supported = <AppLanguage, bool>{};

  @override
  String get name => 'device';

  @override
  Future<SpeakResult> speak(String text, AppLanguage language) async {
    try {
      if (!await _supports(language)) {
        return SpeakResult.missed(name, SpeechMiss.noVoice);
      }
      await _tts.setLanguage(language.locale);
      await _tts.setSpeechRate(.45);
      await _tts.speak(text);
      return SpeakResult.spoke(name);
    } catch (_) {
      return SpeakResult.missed(name, SpeechMiss.error);
    }
  }

  /// `getLanguages` returns empty on the first call on the web, which once made
  /// the app announce "no voice" on a browser that had one. Consult the voices
  /// too, and when both are empty, try anyway.
  Future<bool> _supports(AppLanguage language) async {
    final known = _supported[language];
    if (known != null) return known;
    try {
      final languages = (await _tts.getLanguages as List?) ?? const [];
      final voices = (await _tts.getVoices as List?) ?? const [];
      if (languages.isEmpty && voices.isEmpty) return true; // optimistic
      final code = language.code;
      bool matches(Object? v) =>
          v.toString().toLowerCase().replaceAll('_', '-').startsWith(code);
      final ok =
          languages.any(matches) ||
          voices.any((v) => v is Map && matches(v['locale']));
      return _supported[language] = ok;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> stop() async {
    if (_lazy == null) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Cached Kokoro, live Kokoro, the device, then the screen's text alone.
/// Silence beats a wrong accent reading the wrong screen — but silence is the
/// last resort, not a wait.
class ChainEngine implements SpeechEngine {
  ChainEngine(this.engines);

  final List<SpeechEngine> engines;

  @override
  String get name => engines.map((e) => e.name).join('>');

  int _generation = 0;

  @override
  Future<SpeakResult> speak(String text, AppLanguage language) async {
    final generation = _generation;
    final misses = <String, SpeechMiss>{};
    for (final e in engines) {
      if (generation != _generation) {
        misses[e.name] = SpeechMiss.superseded;
        break;
      }
      final SpeakResult r;
      try {
        r = await e.speak(text, language);
      } catch (_) {
        misses[e.name] = SpeechMiss.error;
        continue;
      }
      if (r.spoke) return SpeakResult.spoke(r.spokenBy!, misses);
      misses.addAll(r.misses);
      // The sentence belongs to a screen that has gone: nobody says it.
      if (r.superseded) break;
    }
    return SpeakResult.silent(misses);
  }

  @override
  Future<void> stop() async {
    _generation++;
    for (final e in engines) {
      await e.stop();
    }
  }
}
