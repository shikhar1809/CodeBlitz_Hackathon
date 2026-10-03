import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/l10n/l10n.dart';
import 'package:winger/core/voice/kokoro_tts.dart';
import 'package:winger/core/voice/speech_engine.dart';
import 'package:winger/core/voice/voice_cache.dart';
import 'package:winger/core/voice/voice_guide.dart';
import 'package:winger/core/voice/voice_prompt.dart';

final wav = Uint8List.fromList(utf8.encode('RIFF....WAVE'));

enum Fault { none, http5xx, malformedSse, badEventId, offline }

/// A Gradio Space. [gate], when set, holds the first request until it is
/// completed — a Space that is slow to answer.
class FakeSpace {
  FakeSpace({this.fault = Fault.none});

  Fault fault;
  Completer<void>? gate;
  final log = <String>[];

  late final http.Client client = MockClient((req) async {
    log.add('${req.method} ${req.url.path}');
    if (gate != null) await gate!.future;
    switch (fault) {
      case Fault.offline:
        throw http.ClientException('Failed host lookup', req.url);
      case Fault.http5xx:
        return http.Response('asleep', 503);
      case Fault.badEventId:
        if (req.method == 'POST') return http.Response('<html>', 200);
      case Fault.malformedSse:
      case Fault.none:
    }
    if (req.method == 'POST') {
      return http.Response(jsonEncode({'event_id': 'abc'}), 200);
    }
    if (req.url.path.endsWith('/predict/abc')) {
      if (fault == Fault.malformedSse) {
        return http.Response('event: complete\ndata: {not json\n', 200);
      }
      return http.Response(
        'event: complete\ndata: [{"url": "https://space/file=x.wav"}]\n',
        200,
      );
    }
    if (req.url.toString() == 'https://space/file=x.wav') {
      return http.Response.bytes(wav, 200);
    }
    return http.Response('?', 404);
  });
}

class FakeSink implements AudioSink {
  final played = <Uint8List>[];
  bool fail = false;
  int stops = 0;

  @override
  Future<void> playBytes(Uint8List bytes) async {
    if (fail) throw Exception('MEDIA_ERROR_UNKNOWN');
    played.add(bytes);
  }

  @override
  Future<void> playFile(String path) async => throw UnimplementedError();

  @override
  Future<void> stop() async => stops++;
}

class FakeDevice implements SpeechEngine {
  final spoken = <String>[];
  bool hasVoice = true;

  @override
  String get name => 'device';

  @override
  Future<SpeakResult> speak(String text, AppLanguage language) async {
    if (!hasVoice) return SpeakResult.missed(name, SpeechMiss.noVoice);
    spoken.add(text);
    return SpeakResult.spoke(name);
  }

  @override
  Future<void> stop() async {}
}

void main() {
  late FakeSpace space;
  late MemoryVoiceCache cache;
  late FakeSink sink;
  late FakeDevice device;
  late KokoroEngine kokoro;
  late ChainEngine chain;

  void build({Duration deadline = const Duration(milliseconds: 80)}) {
    kokoro = KokoroEngine(
      tts: KokoroTts(client: space.client, cache: cache),
      sink: sink,
      liveDeadline: deadline,
    );
    chain = ChainEngine([kokoro, device]);
  }

  setUp(() {
    space = FakeSpace();
    cache = MemoryVoiceCache();
    sink = FakeSink();
    device = FakeDevice();
    build();
  });

  Future<void> cacheLine(String text, AppLanguage language) =>
      cache.write(KokoroTts.cacheKey(text, language, 1.0), wav);

  group('KokoroTts classifies what went wrong', () {
    for (final (fault, miss) in [
      (Fault.http5xx, SpeechMiss.httpError),
      (Fault.malformedSse, SpeechMiss.malformedResponse),
      (Fault.badEventId, SpeechMiss.malformedResponse),
      (Fault.offline, SpeechMiss.offline),
    ]) {
      test('${fault.name} is ${miss.name}, and marks the Space', () async {
        space.fault = fault;
        final tts = KokoroTts(client: space.client, cache: cache);
        final result = await tts.fetch('Namaste', AppLanguage.hi);
        expect(result.failure, miss);
        expect(result.bytes, isNull);
        expect(tts.unreachable, isTrue);
        expect(
          await cache.read(KokoroTts.cacheKey('Namaste', AppLanguage.hi, 1)),
          isNull,
        );
      });
    }

    test('the whole-fetch timeout is a timeout', () async {
      space.gate = Completer();
      final tts = KokoroTts(
        client: space.client,
        cache: cache,
        timeout: const Duration(milliseconds: 20),
      );
      expect(
        (await tts.fetch('x', AppLanguage.en)).failure,
        SpeechMiss.timeout,
      );
      space.gate!.complete();
    });

    test('the same sentence twice at once is one request', () async {
      space.gate = Completer();
      final tts = KokoroTts(client: space.client, cache: cache);
      final a = tts.fetch('Namaste', AppLanguage.hi);
      final b = tts.fetch('Namaste', AppLanguage.hi);
      space.gate!.complete();
      await Future.wait([a, b]);
      expect(space.log.where((l) => l.startsWith('POST')), hasLength(1));
    });

    test('SSE data that is not JSON yields no url, not an exception', () {
      expect(KokoroTts.audioUrlFromSse('event: complete\ndata: {oops'), isNull);
    });
  });

  group('each failure falls through to the device voice', () {
    for (final fault in [
      Fault.http5xx,
      Fault.malformedSse,
      Fault.badEventId,
      Fault.offline,
    ]) {
      test(fault.name, () async {
        space.fault = fault;
        final r = await chain.speak('Take it now', AppLanguage.en);
        expect(r.spokenBy, 'device');
        expect(r.misses.keys, ['kokoro']);
        expect(device.spoken, ['Take it now']);
        expect(sink.played, isEmpty);
      });
    }

    test('playback error', () async {
      sink.fail = true;
      final r = await chain.speak('Take it now', AppLanguage.en);
      expect(r.spokenBy, 'device');
      expect(r.misses, {'kokoro': SpeechMiss.playbackError});
    });

    test('a cached line that will not play still gets said', () async {
      await cacheLine('Take it now', AppLanguage.en);
      sink.fail = true;
      final r = await chain.speak('Take it now', AppLanguage.en);
      expect(r.spokenBy, 'device');
      expect(space.log, isEmpty);
    });

    test('after one failure the Space is not asked again', () async {
      space.fault = Fault.http5xx;
      await chain.speak('one', AppLanguage.en);
      final r = await chain.speak('two', AppLanguage.en);
      expect(r.misses, {'kokoro': SpeechMiss.unreachable});
      expect(space.log, hasLength(1));
      expect(device.spoken, ['one', 'two']);
    });

    test('no engine at all leaves the text on screen, and says so', () async {
      space.fault = Fault.offline;
      device.hasVoice = false;
      final r = await chain.speak('Take it now', AppLanguage.en);
      expect(r.spoke, isFalse);
      expect(r.spokenBy, isNull);
      expect(r.misses, {
        'kokoro': SpeechMiss.offline,
        'device': SpeechMiss.noVoice,
      });
    });
  });

  group('the cache', () {
    test('a cache hit plays with no network at all', () async {
      await cacheLine('नमस्ते', AppLanguage.hi);
      space.fault = Fault.offline;
      final r = await chain.speak('नमस्ते', AppLanguage.hi);
      expect(r.spokenBy, 'kokoro');
      expect(space.log, isEmpty);
      expect(sink.played, [wav]);
      expect(device.spoken, isEmpty);
    });

    test('a live fetch inside the deadline plays, and is cached', () async {
      final r = await chain.speak('Namaste', AppLanguage.hi);
      expect(r.spokenBy, 'kokoro');
      expect(sink.played, [wav]);
      expect(await kokoro.tts.cached('Namaste', AppLanguage.hi), wav);
    });
  });

  group('the live deadline', () {
    test('a slow Space: the device speaks at the deadline, Kokoro warms the '
        'cache without playing, and plays from it next time', () async {
      space.gate = Completer();
      final watch = Stopwatch()..start();
      final r = await chain.speak('Namaste', AppLanguage.hi);
      watch.stop();

      expect(r.spokenBy, 'device');
      expect(r.misses, {'kokoro': SpeechMiss.timeout});
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(kokoro.slow, isTrue);

      // The Space answers late.
      space.gate!.complete();
      await kokoro.backgroundDone;
      expect(sink.played, isEmpty, reason: 'never played late');
      expect(await kokoro.tts.cached('Namaste', AppLanguage.hi), wav);

      final requests = space.log.length;
      final again = await chain.speak('Namaste', AppLanguage.hi);
      expect(again.spokenBy, 'kokoro');
      expect(sink.played, [wav]);
      expect(space.log, hasLength(requests), reason: 'from the cache');
      expect(device.spoken, ['Namaste']);
    });

    test('once slow, the next uncached line does not wait at all', () async {
      space.gate = Completer();
      await chain.speak('one', AppLanguage.en);
      expect(kokoro.slow, isTrue);

      final watch = Stopwatch()..start();
      final r = await chain.speak('two', AppLanguage.en);
      expect(r.misses, {'kokoro': SpeechMiss.slow});
      expect(r.spokenBy, 'device');
      expect(watch.elapsedMilliseconds, lessThan(80));

      space.gate!.complete();
      await kokoro.backgroundDone;
      expect(await kokoro.tts.cached('two', AppLanguage.en), wav);
      expect(sink.played, isEmpty);
    });

    test(
      'a fast answer after a slow one makes waiting worth it again',
      () async {
        space.gate = Completer();
        await chain.speak('one', AppLanguage.en);
        space.gate!.complete();
        await kokoro.backgroundDone;
        space.gate = null;

        // Uncached and slow-flagged: skipped, but its fetch is fast.
        await chain.speak('two', AppLanguage.en);
        await kokoro.backgroundDone;
        expect(kokoro.slow, isFalse);
        final r = await chain.speak('three', AppLanguage.en);
        expect(r.spokenBy, 'kokoro');
      },
    );
  });

  group('ownership (ADR-15)', () {
    test(
      'a sentence stopped while loading is dropped by every engine',
      () async {
        space.gate = Completer();
        build(deadline: const Duration(seconds: 30));
        final pending = chain.speak('old screen', AppLanguage.en);
        await pumpEventQueue();
        expect(space.log, isNotEmpty, reason: 'the request is in flight');
        await chain.stop();
        space.gate!.complete();
        final r = await pending;

        expect(r.spoke, isFalse);
        expect(r.superseded, isTrue);
        expect(sink.played, isEmpty);
        expect(device.spoken, isEmpty, reason: 'no fallback for a gone screen');
        expect(
          await kokoro.tts.cached('old screen', AppLanguage.en),
          wav,
          reason: 'still worth caching',
        );
      },
    );

    test('a slow old screen never talks over the new one', () async {
      space.gate = Completer();
      build(deadline: const Duration(seconds: 30));
      final guide = VoiceGuide(engine: chain, enabled: true);
      final oldScreen = Object(), newScreen = Object();

      final pendingOld = guide.speak(oldScreen, 'old', AppLanguage.en);
      await cacheLine('new', AppLanguage.en);
      final newResult = await guide.speak(newScreen, 'new', AppLanguage.en);
      space.gate!.complete();
      final oldResult = await pendingOld;

      expect(newResult!.spokenBy, 'kokoro');
      expect(oldResult!.superseded, isTrue);
      expect(sink.played, hasLength(1));
      expect(device.spoken, isEmpty);
      expect(guide.status.value!.text, 'new');
      expect(guide.speaker, same(newScreen));
    });
  });

  group('VoiceGuide status', () {
    test('reports the engine that spoke and how long it took', () async {
      space.fault = Fault.http5xx;
      final guide = VoiceGuide(engine: chain, enabled: true);
      await guide.speak(Object(), 'Take it now', AppLanguage.en);
      final s = guide.status.value!;
      expect(s.spokenBy, 'device');
      expect(s.elapsed, isNot(Duration.zero));
      expect(s.describe(), startsWith('voice: device · '));
      expect(s.describe(), endsWith('(kokoro: httpError)'));
    });

    test('reports text-only when nothing could speak', () async {
      space.fault = Fault.offline;
      device.hasVoice = false;
      final guide = VoiceGuide(engine: chain, enabled: true);
      await guide.speak(Object(), 'Take it now', AppLanguage.en);
      expect(guide.status.value!.spokenBy, isNull);
      expect(guide.status.value!.describe(), contains('none, text only'));
    });
  });

  group('debug voice line', () {
    tearDown(() => VoiceGuide.showDebugStatus = false);

    Widget host(VoiceGuide guide) => MaterialApp(
      builder: (context, inner) => L10n(
        language: AppLanguage.en,
        child: VoiceScope(guide: guide, child: inner!),
      ),
      home: const VoicePrompt(text: 'Hello', child: Text('screen')),
    );

    testWidgets('is off unless asked for', (tester) async {
      final guide = VoiceGuide(engine: device, enabled: true);
      await tester.pumpWidget(host(guide));
      await tester.pump();
      expect(guide.status.value, isNotNull);
      expect(find.textContaining('voice:'), findsNothing);
      expect(find.byType(VoiceStatusLine), findsNothing);
    });

    testWidgets('shows who spoke when switched on', (tester) async {
      VoiceGuide.showDebugStatus = true;
      final guide = VoiceGuide(engine: device, enabled: true);
      await tester.pumpWidget(host(guide));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('voice: device · '), findsOneWidget);
      expect(find.text('screen'), findsOneWidget);
    });
  });
}
