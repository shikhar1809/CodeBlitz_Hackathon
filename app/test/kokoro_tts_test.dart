import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/voice/kokoro_tts.dart';
import 'package:winger/core/voice/voice_cache.dart';

void main() {
  final wav = Uint8List.fromList(utf8.encode('RIFF....WAVE'));

  MockClient space({List<String>? log, bool fail = false}) => MockClient((
    req,
  ) async {
    log?.add('${req.method} ${req.url.path}');
    if (fail) return http.Response('asleep', 503);
    if (req.method == 'POST') {
      final body = jsonDecode(req.body) as Map;
      expect(body['data'][1], KokoroTts.femaleVoice);
      return http.Response(jsonEncode({'event_id': 'abc'}), 200);
    }
    if (req.url.path.endsWith('/predict/abc')) {
      return http.Response(
        'event: generating\ndata: null\n\n'
        'event: complete\n'
        'data: [{"path": "/tmp/x.wav", "url": "https://space/file=x.wav"}]\n',
        200,
      );
    }
    if (req.url.toString() == 'https://space/file=x.wav') {
      return http.Response.bytes(wav, 200);
    }
    return http.Response('?', 404);
  });

  test(
    'fetches through the Gradio call API, then serves from the cache',
    () async {
      final log = <String>[];
      final tts = KokoroTts(
        client: space(log: log),
        cache: MemoryVoiceCache(),
      );

      final first = await tts.synthesize('Namaste', AppLanguage.hi);
      expect(first, wav);
      expect(log, hasLength(3));

      final second = await tts.synthesize('Namaste', AppLanguage.hi);
      expect(second, wav);
      expect(log, hasLength(3), reason: 'second call is offline, from cache');
    },
  );

  test('one failure marks the Space unreachable for the session', () async {
    final log = <String>[];
    final tts = KokoroTts(
      client: space(log: log, fail: true),
      cache: MemoryVoiceCache(),
    );
    expect(await tts.synthesize('one', AppLanguage.en), isNull);
    expect(tts.unreachable, isTrue);
    expect(await tts.synthesize('two', AppLanguage.en), isNull);
    expect(log, hasLength(1), reason: 'no second thirty-second wait');
  });

  test('a cached sentence still plays after the Space has failed', () async {
    final cache = MemoryVoiceCache();
    await cache.write(KokoroTts.cacheKey('hi', AppLanguage.en, 1.0), wav);
    final tts = KokoroTts(client: space(fail: true), cache: cache);
    await tts.synthesize('other', AppLanguage.en);
    expect(await tts.synthesize('hi', AppLanguage.en), wav);
  });

  test('cache keys separate language and speed, and ignore stray spaces', () {
    final a = KokoroTts.cacheKey('Take it', AppLanguage.en, 1.0);
    expect(KokoroTts.cacheKey(' Take it ', AppLanguage.en, 1.0), a);
    expect(KokoroTts.cacheKey('Take it', AppLanguage.hi, 1.0), isNot(a));
    expect(KokoroTts.cacheKey('Take it', AppLanguage.en, 0.9), isNot(a));
  });

  group('audioUrlFromSse', () {
    test('reads a url object', () {
      expect(
        KokoroTts.audioUrlFromSse(
          'event: complete\ndata: [{"url": "https://a/b.wav"}]',
        ),
        'https://a/b.wav',
      );
    });
    test('builds a url from a bare path', () {
      expect(
        KokoroTts.audioUrlFromSse(
          'event: complete\ndata: [{"path": "/t/b.wav"}]',
          baseUrl: 'https://s',
        ),
        'https://s/gradio_api/file=/t/b.wav',
      );
    });
    test('an error event yields nothing', () {
      expect(KokoroTts.audioUrlFromSse('event: error\ndata: null'), isNull);
    });
  });
}
