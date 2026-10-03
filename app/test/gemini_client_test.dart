import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winger/ai/gemini_client.dart';
import 'package:winger/domain/mention.dart';
import 'package:winger/domain/merge_engine.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/wizard/online_read_card.dart';
import 'package:winger/features/wizard/steps/processing_step.dart';

import 'support/golden_harness.dart';
import 'support/wizard_fakes.dart';

String reply(Object json, {bool fenced = false}) {
  final text = fenced ? '```json\n${jsonEncode(json)}\n```' : jsonEncode(json);
  return jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': text},
          ],
        },
      },
    ],
  });
}

const telmaRead = {
  'medicines': [
    {
      'name': 'Telma 40',
      'strength': '40 mg',
      'instruction': '1-0-1 p/c',
      'raw': 'Tab Telma 40 1-0-1 p/c',
      'uncertain': false,
    },
    {
      'name': 'Shelcal',
      'strength': '',
      'instruction': '',
      'raw': 'Tab Shelcal ?',
      'uncertain': true,
    },
  ],
  'notes': ['Review after 10 days'],
};

void main() {
  final image = Uint8List.fromList([1, 2, 3]);

  test('the request: temperature 0, JSON out, the image inline', () async {
    late Map<String, Object?> sent;
    late Uri url;
    final client = GeminiClient(
      apiKey: 'test-key',
      client: MockClient((req) async {
        url = req.url;
        sent = jsonDecode(req.body) as Map<String, Object?>;
        return http.Response(reply(telmaRead), 200);
      }),
    );
    await client.readPrescription(image);

    expect(url.path, contains('gemini-3.8-flash:generateContent'));
    expect(url.queryParameters['key'], 'test-key');
    final config = sent['generationConfig'] as Map;
    expect(config['temperature'], 0);
    expect(config['responseMimeType'], 'application/json');
    final parts = ((sent['contents'] as List).first as Map)['parts'] as List;
    expect((parts.first as Map)['text'], GeminiClient.prompt);
    expect(
      ((parts.last as Map)['inline_data'] as Map)['data'],
      base64Encode(image),
    );
  });

  test('fences are stripped, notes kept apart', () {
    final r = GeminiClient.parseResponse(reply(telmaRead, fenced: true));
    expect(r.medicines.map((m) => m.name), ['Telma 40', 'Shelcal']);
    expect(r.notes, ['Review after 10 days']);
  });

  test('rows become mentions with no extra trust', () {
    final ms = GeminiClient.parseResponse(reply(telmaRead)).toMentions();
    final telma = ms.first;
    expect(telma.source, SourceKind.prescription);
    expect(telma.readOnline, isTrue);
    expect(telma.name, 'TELMA 40');
    expect(telma.sig.slots, [DoseSlot.morning, DoseSlot.night]);
    expect(ms.last.uncertain, isTrue, reason: 'a flag, not a guess');
  });

  test('an unsure online row can never be green on its own', () {
    final ms = GeminiClient.parseResponse(reply(telmaRead)).toMentions();
    final rows = MergeEngine.merge(ms);
    expect(rows.every((r) => r.verdict != Verdict.green), isTrue);
  });

  test('four calls per visit, then no more', () async {
    var calls = 0;
    final client = GeminiClient(
      apiKey: 'k',
      client: MockClient((_) async {
        calls++;
        return http.Response(reply(telmaRead), 200);
      }),
    );
    for (var i = 0; i < 4; i++) {
      await client.readPrescription(image);
    }
    expect(
      () => client.readPrescription(image),
      throwsA(
        isA<GeminiException>().having(
          (e) => e.failure,
          'failure',
          GeminiFailure.overBudget,
        ),
      ),
    );
    expect(calls, 4);
  });

  test('no key: nothing is sent', () async {
    var calls = 0;
    final client = GeminiClient(
      apiKey: '',
      client: MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    expect(client.configured, isFalse);
    await expectLater(
      client.readPrescription(image),
      throwsA(isA<GeminiException>()),
    );
    expect(calls, 0);
  });

  test('a slow answer times out rather than hanging the step', () async {
    final client = GeminiClient(
      apiKey: 'k',
      timeout: const Duration(milliseconds: 20),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response(reply(telmaRead), 200);
      }),
    );
    await expectLater(
      client.readPrescription(image),
      throwsA(
        isA<GeminiException>().having(
          (e) => e.failure,
          'failure',
          GeminiFailure.timedOut,
        ),
      ),
    );
  });

  test('a refusal or garbage is an error, never an empty list', () {
    expect(
      () => GeminiClient.parseResponse('{"error": "quota"}'),
      throwsA(isA<GeminiException>()),
    );
  });

  group('the card', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required bool online,
      String key = 'k',
    }) async {
      final c = await wizard(ocr: {'rx.jpg': 'Rx\nTab Pan 40 OD a/c'});
      await c.skip();
      await c.addPhotos([XFile('rx.jpg')]);
      await c.next();
      await c.skip();
      usePhoneSurface(tester);
      await tester.pumpWidget(
        themed(
          Scaffold(
            body: ProcessingStep(
              controller: c,
              online: OnlineReadCard(
                controller: c,
                client: GeminiClient(
                  apiKey: key,
                  client: MockClient(
                    (_) async => http.Response(reply(telmaRead), 200),
                  ),
                ),
                reachable: () async => online,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offline, the card is absent', (tester) async {
      await pumpCard(tester, online: false);
      expect(find.text('Read the handwriting online'), findsNothing);
    });

    testWidgets('without a key, the card is absent', (tester) async {
      await pumpCard(tester, online: true, key: '');
      expect(find.text('Read the handwriting online'), findsNothing);
    });

    testWidgets('online, it says what leaves the phone before anything does', (
      tester,
    ) async {
      await pumpCard(tester, online: true);
      expect(find.text('Read the handwriting online'), findsOneWidget);
      expect(
        find.textContaining('Nothing else leaves the phone'),
        findsOneWidget,
      );
    });
  });
}
