import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/l10n/l10n.dart';
import 'package:winger/features/wizard/wizard_screen.dart';
import 'package:winger/platform/gallery_scanner.dart';

import 'support/fake_haptics.dart';
import 'support/golden_harness.dart';
import 'support/recording_fakes.dart';
import 'support/wizard_fakes.dart';

/// "Did it record?" in each of its answers, on the real words step, driven
/// by taps — the same path a finger takes.
void main() {
  late FakeDictation stt;
  late FakeAudio mic;

  Future<void> open(
    WidgetTester tester,
    AppLanguage language, {
    double height = 892,
  }) async {
    FakeHaptics.install();
    stt = FakeDictation();
    mic = FakeAudio();
    usePhoneSurface(tester, size: Size(412, height));
    await tester.pumpWidget(
      themed(
        WizardScreen(
          controller: await wizard(),
          consent: (_) async => true,
          scanner: FakeScanner(const ScanOutcome.unsupported()),
          photos: FakePhotos(const []),
          dictation: stt,
          audio: mic,
          player: FakeClipPlayer(),
        ),
        language: language,
      ),
    );
    await tester.pump();
  }

  Finder speak() => find.byWidgetPredicate((w) => w is FilledButton).first;

  /// A voice rising and falling, as the meter would see it.
  Future<void> talk(WidgetTester tester, Duration total) async {
    const levels = [1.0, 6, 9, 4, 8, 10, 3, 7, 5, 9, 2, 6];
    final step = total ~/ levels.length;
    for (final dB in levels) {
      stt.loud(dB.toDouble());
      await tester.pump(step);
    }
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }

  for (final language in AppLanguage.values) {
    final code = language.code;

    testWidgets('recording · $code', (tester) async {
      await open(tester, language);
      await tester.tap(speak());
      await tester.pump();
      stt.say('Telma 40 subah khane ke baad');
      await talk(tester, const Duration(seconds: 7));
      await shoot(tester, 'recording_1_live_$code');
    });

    testWidgets('recorded · $code', (tester) async {
      await open(tester, language, height: 1100);
      await tester.tap(speak());
      await tester.pump();
      stt.say('Telma 40 subah khane ke baad. Glycomet 500 subah aur raat.');
      await talk(tester, const Duration(seconds: 42));
      await tester.tap(speak());
      await tester.pump();

      final s = L10n.of(tester.element(speak()));
      await tester.tap(find.widgetWithText(TextButton, s.speak));
      await tester.pump();
      mic.loud(.7);
      await tester.pump(const Duration(seconds: 12));
      await tester.tap(find.widgetWithText(TextButton, s.stopRecording));
      await tester.pump();
      await shoot(tester, 'recording_2_recorded_$code');
    });

    testWidgets('too short · $code', (tester) async {
      await open(tester, language);
      await tester.tap(speak());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(speak());
      await tester.pump();
      await shoot(tester, 'recording_3_too_short_$code');
    });
  }
}
