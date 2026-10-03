import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_language.dart';
import 'speech_result.dart';
import 'voice_cache.dart';

/// The outcome of asking the Space for one sentence. Exactly one of [bytes]
/// and [failure] is set.
class KokoroFetch {
  const KokoroFetch.ok(Uint8List this.bytes, this.elapsed) : failure = null;
  const KokoroFetch.failed(SpeechMiss this.failure, this.elapsed)
    : bytes = null;

  final Uint8List? bytes;
  final SpeechMiss? failure;

  /// From the first request to the last byte of audio.
  final Duration elapsed;
}

/// Kokoro text-to-speech, through a public Hugging Face Space.
///
/// Device TTS was robotic, had no usable Hindi voice on most phones, and the
/// recorded clips could not keep up with the screens. Kokoro sounds like a
/// person in both languages.
///
/// Every sentence is cached on the device, so after one warm walkthrough the
/// voice works with no network at all. One failure marks the Space unreachable
/// for the rest of the session — a voice that stalls thirty seconds on every
/// screen is worse than the fallback.
///
/// This class never waits on the user's behalf: it has one generous [timeout]
/// for a whole fetch. The short "speak now or step aside" deadline belongs to
/// `KokoroEngine`, which lets a slow fetch finish here and warm the cache.
class KokoroTts {
  KokoroTts({
    http.Client? client,
    VoiceCache? cache,
    this.baseUrl = defaultBaseUrl,
    this.voice = femaleVoice,
    this.timeout = const Duration(seconds: 40),
  }) : _injected = client,
       _cache = cache ?? VoiceCache();

  static const defaultBaseUrl = 'https://leonelhs-kokoro-tts-hindi.hf.space';
  static const femaleVoice = 'hf_alpha';
  static const maleVoice = 'hm_omega';

  final String baseUrl;
  final String voice;

  /// A sleeping Space takes about thirty seconds to answer its first request.
  final Duration timeout;

  final VoiceCache _cache;

  // Never construct an external resource in a constructor: it breaks
  // flutter_test at load time. Build it the first time it is needed.
  final http.Client? _injected;
  http.Client? _lazy;
  http.Client get _http => _injected ?? (_lazy ??= http.Client());

  bool _unreachable = false;

  /// True once the Space has failed this session.
  bool get unreachable => _unreachable;

  VoiceCache get cache => _cache;

  // One request per sentence at a time: a prompt repeats every ten seconds,
  // and a slow Space must not be asked for the same sentence twice.
  final _inFlight = <String, Future<KokoroFetch>>{};

  static String cacheKey(String text, AppLanguage language, double speed) =>
      sha1
          .convert(utf8.encode('${language.code}|$speed|${text.trim()}'))
          .toString();

  /// The cached WAV for [text], without touching the network.
  Future<Uint8List?> cached(
    String text,
    AppLanguage language, {
    double speed = 1.0,
  }) async {
    try {
      return await _cache.read(cacheKey(text, language, speed));
    } catch (_) {
      return null; // A cache that cannot be read is a cache miss.
    }
  }

  /// WAV bytes for [text], from the cache or the Space. Null when neither can
  /// provide them.
  Future<Uint8List?> synthesize(
    String text,
    AppLanguage language, {
    double speed = 1.0,
  }) async {
    final hit = await cached(text, language, speed: speed);
    if (hit != null) return hit;
    return (await fetch(text, language, speed: speed)).bytes;
  }

  /// Ask the Space for [text] and cache the result. Never throws. A second
  /// call for a sentence already being fetched joins the first.
  Future<KokoroFetch> fetch(
    String text,
    AppLanguage language, {
    double speed = 1.0,
  }) {
    if (_unreachable) {
      return Future.value(
        const KokoroFetch.failed(SpeechMiss.unreachable, Duration.zero),
      );
    }
    final key = cacheKey(text, language, speed);
    return _inFlight[key] ??=
        _fetchAndCache(
          key,
          text,
          speed,
          // A block body, not `=> remove(key)`: remove returns this very future,
          // and whenComplete would wait on it — a deadlock.
        ).whenComplete(() {
          _inFlight.remove(key);
        });
  }

  /// Warm the cache for a set of sentences, one after another.
  Future<void> warm(Iterable<String> sentences, AppLanguage language) async {
    for (final s in sentences) {
      if (_unreachable) return;
      await synthesize(s, language);
    }
  }

  Future<KokoroFetch> _fetchAndCache(
    String key,
    String text,
    double speed,
  ) async {
    final watch = Stopwatch()..start();
    SpeechMiss failure;
    try {
      final bytes = await _fetch(text, speed).timeout(timeout);
      try {
        await _cache.write(key, bytes);
      } catch (_) {
        // Still worth playing; it just will not be there next time.
      }
      return KokoroFetch.ok(bytes, watch.elapsed);
    } on _SpaceError catch (e) {
      failure = e.miss;
    } on TimeoutException {
      failure = SpeechMiss.timeout;
    } on http.ClientException {
      failure = SpeechMiss.offline;
    } on FormatException {
      failure = SpeechMiss.malformedResponse;
    } catch (_) {
      failure = SpeechMiss.error;
    }
    _unreachable = true;
    return KokoroFetch.failed(failure, watch.elapsed);
  }

  Future<Uint8List> _fetch(String text, double speed) async {
    final start = await _http.post(
      Uri.parse('$baseUrl/gradio_api/call/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'data': [text, voice, speed],
      }),
    );
    if (start.statusCode != 200) {
      throw const _SpaceError(SpeechMiss.httpError);
    }
    final decoded = jsonDecode(start.body);
    final eventId = decoded is Map ? decoded['event_id'] : null;
    if (eventId is! String) {
      throw const _SpaceError(SpeechMiss.malformedResponse);
    }

    final stream = await _http.get(
      Uri.parse('$baseUrl/gradio_api/call/predict/$eventId'),
    );
    if (stream.statusCode != 200) {
      throw const _SpaceError(SpeechMiss.httpError);
    }
    final url = audioUrlFromSse(stream.body, baseUrl: baseUrl);
    if (url == null) throw const _SpaceError(SpeechMiss.malformedResponse);

    final audio = await _http.get(Uri.parse(url));
    if (audio.statusCode != 200 || audio.bodyBytes.isEmpty) {
      throw const _SpaceError(SpeechMiss.httpError);
    }
    return audio.bodyBytes;
  }

  /// Pull the audio URL out of a Gradio server-sent-events body.
  ///
  /// The body is a series of `event:` / `data:` pairs. The one that matters is
  /// `event: complete`, whose data is a JSON list whose first item is the file
  /// — either an object with a `url`, or a bare path. Anything else, including
  /// data that is not JSON, yields null.
  static String? audioUrlFromSse(String body, {String? baseUrl}) {
    String? event;
    for (final raw in const LineSplitter().convert(body)) {
      final line = raw.trim();
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:') && event == 'complete') {
        final Object? data;
        try {
          data = jsonDecode(line.substring(5).trim());
        } on FormatException {
          return null;
        }
        if (data is! List || data.isEmpty) return null;
        final first = data.first;
        if (first is Map && first['url'] is String) return first['url'];
        if (first is Map && first['path'] is String) {
          return '${baseUrl ?? defaultBaseUrl}/gradio_api/file=${first['path']}';
        }
        if (first is String) return first;
        return null;
      }
    }
    return null;
  }
}

class _SpaceError implements Exception {
  const _SpaceError(this.miss);
  final SpeechMiss miss;
}
