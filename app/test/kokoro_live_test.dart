import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/voice/kokoro_tts.dart';
import 'package:winger/core/voice/voice_cache.dart';

/// Against the real Hugging Face Space. Off by default: it needs the network,
/// and a sleeping Space takes half a minute.
///
///     $env:RAPIDRX_LIVE_KOKORO = '1'; flutter test test/kokoro_live_test.dart
void main() {
  final live = Platform.environment['RAPIDRX_LIVE_KOKORO'] == '1';
  final skip = live ? false : 'set RAPIDRX_LIVE_KOKORO=1 to call the Space';

  // The test binding answers every HTTP request with a 400. This test is the
  // one place that wants the real network.
  setUpAll(() => HttpOverrides.global = null);

  for (final (language, line) in [
    (AppLanguage.en, 'Take one tablet after breakfast, every morning.'),
    (AppLanguage.hi, 'सुबह नाश्ते के बाद एक गोली लीजिए।'),
  ]) {
    test(
      'the Space speaks ${language.code}',
      () async {
        final client = http.Client();
        addTearDown(client.close);
        final tts = KokoroTts(client: client, cache: MemoryVoiceCache());

        final result = await tts.fetch(line, language);

        expect(result.failure, isNull, reason: 'failed: ${result.failure}');
        final bytes = result.bytes!;
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
        expect(bytes.length, greaterThan(20000), reason: 'about a second+');
        expect(await tts.cached(line, language), bytes);
        // ignore: avoid_print
        print(
          'kokoro ${language.code}: ${bytes.length} B '
          'in ${result.elapsed.inMilliseconds} ms',
        );
      },
      skip: skip,
      timeout: const Timeout(Duration(seconds: 90)),
    );
  }
}
