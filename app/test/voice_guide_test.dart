import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/l10n/l10n.dart';
import 'package:winger/core/voice/speech_engine.dart';
import 'package:winger/core/voice/voice_guide.dart';
import 'package:winger/core/voice/voice_prompt.dart';

/// Records what it was asked to say. `stop` can be made slow, to reproduce the
/// race where a new screen claims the voice while the old one is stopping.
class FakeEngine implements SpeechEngine {
  final spoken = <String>[];
  int stops = 0;
  Completer<void>? stopGate;

  @override
  String get name => 'fake';

  @override
  Future<SpeakResult> speak(String text, AppLanguage language) async {
    spoken.add(text);
    return SpeakResult.spoke(name);
  }

  @override
  Future<void> stop() async {
    stops++;
    if (stopGate != null) await stopGate!.future;
  }
}

void main() {
  late FakeEngine engine;
  late VoiceGuide guide;

  setUp(() {
    engine = FakeEngine();
    guide = VoiceGuide(engine: engine, enabled: true);
  });

  group('ownership', () {
    test(
      'a screen leaving does not silence the screen that replaced it',
      () async {
        final oldScreen = Object(), newScreen = Object();
        await guide.speak(oldScreen, 'old', AppLanguage.en);
        await guide.speak(newScreen, 'new', AppLanguage.en);
        final stopsBefore = engine.stops;

        await guide.stopIfSpeaking(oldScreen);

        expect(
          engine.stops,
          stopsBefore,
          reason: 'old screen no longer owns it',
        );
        expect(guide.speaker, same(newScreen));
      },
    );

    test('the owner leaving stops the voice', () async {
      final screen = Object();
      await guide.speak(screen, 'hello', AppLanguage.en);
      await guide.stopIfSpeaking(screen);
      expect(guide.speaker, isNull);
      expect(engine.stops, 1);
    });

    test('a sentence claimed over while stopping is dropped', () async {
      final a = Object(), b = Object();
      await guide.speak(a, 'first', AppLanguage.en);
      engine.stopGate = Completer<void>();

      final pendingB = guide.speak(b, 'second', AppLanguage.en);
      // While b waits for the stop, a third screen takes over.
      final c = Object();
      final pendingC = guide.speak(c, 'third', AppLanguage.en);
      engine.stopGate!.complete();
      await Future.wait([pendingB, pendingC]);

      expect(engine.spoken, isNot(contains('second')));
      expect(engine.spoken.last, 'third');
    });

    test('nothing is spoken while voice help is off', () async {
      guide.enabled = false;
      await guide.speak(Object(), 'hello', AppLanguage.en);
      expect(engine.spoken, isEmpty);
    });
  });

  group('VoicePrompt', () {
    Widget host(Widget child) => MaterialApp(
      builder: (context, inner) => L10n(
        language: AppLanguage.hi,
        child: VoiceScope(guide: guide, child: inner!),
      ),
      home: child,
    );

    testWidgets('speaks on arrival and repeats every ten seconds', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const VoicePrompt(text: 'नमस्ते', child: SizedBox())),
      );
      await tester.pump();
      expect(engine.spoken, ['नमस्ते']);

      await tester.pump(const Duration(seconds: 10));
      expect(engine.spoken, hasLength(2));

      await tester.pumpWidget(host(const SizedBox()));
      await tester.pump(const Duration(seconds: 30));
      expect(engine.spoken, hasLength(2), reason: 'stops repeating once gone');
    });

    testWidgets('replacing the screen hands the voice over', (tester) async {
      await tester.pumpWidget(
        host(
          const VoicePrompt(key: ValueKey(1), text: 'one', child: SizedBox()),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        host(
          const VoicePrompt(key: ValueKey(2), text: 'two', child: SizedBox()),
        ),
      );
      await tester.pump();
      expect(engine.spoken.last, 'two');
      expect(guide.speaker, isNotNull);

      await tester.pumpWidget(host(const SizedBox()));
      expect(guide.speaker, isNull);
    });
  });
}
