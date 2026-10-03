import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/feedback/haptics.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/domain/mention.dart';
import 'package:winger/features/recording/recording_controller.dart';
import 'package:winger/features/recording/recording_sessions.dart';
import 'package:winger/features/visit/capture_tools.dart';
import 'package:winger/features/wizard/wizard_controller.dart';
import 'package:winger/features/wizard/wizard_screen.dart';
import 'package:winger/platform/dictation.dart';
import 'package:winger/platform/gallery_scanner.dart';

import 'support/fake_haptics.dart';
import 'support/golden_harness.dart';
import 'support/recording_fakes.dart';
import 'support/wizard_fakes.dart';

const tap = HapticKind.tap;
const confirm = HapticKind.confirm;
const error = HapticKind.error;

void main() {
  group('RecordingController', () {
    test('idle → recording → recorded(0:42) → deleted', () {
      final haptics = FakeHaptics.install();
      final r = RecordingController();
      expect(r.phase, RecordingPhase.idle);
      r.start();
      expect(r.phase, RecordingPhase.recording);
      r.hear(.6);
      r.tick(const Duration(seconds: 42, milliseconds: 300));
      expect(RecordingController.clock(r.elapsed), '0:42');
      expect(r.stop(), RecordingPhase.recorded);
      expect(r.length, const Duration(seconds: 42, milliseconds: 300));
      r.delete();
      expect(r.phase, RecordingPhase.deleted);
      expect(haptics.calls, [tap, confirm]);
    });

    test('under a second is too short, whatever was heard', () {
      final haptics = FakeHaptics.install();
      final r = RecordingController()..start();
      r.hear(.9);
      r.tick(const Duration(milliseconds: 800));
      expect(r.stop(heard: true), RecordingPhase.tooShort);
      expect(r.heardNothing, isTrue);
      expect(r.length, isNull);
      expect(haptics.calls, [tap, error]);
    });

    test('a measured quiet is silent; no readings at all is not', () {
      FakeHaptics.install();
      final quiet = RecordingController()..start();
      for (final v in [.02, .05, .1]) {
        quiet.hear(v);
      }
      quiet.tick(const Duration(seconds: 3));
      expect(quiet.stop(), RecordingPhase.silent);

      final unmeasured = RecordingController()..start();
      unmeasured.tick(const Duration(seconds: 3));
      expect(
        unmeasured.stop(),
        RecordingPhase.recorded,
        reason: 'silence is only claimed when it was measured',
      );
    });

    test('words that come after the stop overturn "silent"', () {
      final haptics = FakeHaptics.install();
      final r = RecordingController()..start();
      r.tick(const Duration(seconds: 2));
      expect(r.stop(heard: false), RecordingPhase.silent);
      r.heardLate();
      expect(r.phase, RecordingPhase.recorded);
      expect(haptics.calls, [tap, error, confirm]);
    });

    test('only a new second is news; levels feed a fixed-width meter', () {
      final r = RecordingController(meterBars: 4)..start();
      var notified = 0;
      r.addListener(() => notified++);
      r.tick(const Duration(milliseconds: 200));
      r.tick(const Duration(milliseconds: 600));
      expect(notified, 0);
      r.tick(const Duration(milliseconds: 1100));
      expect(notified, 1);
      r.hear(2);
      r.hear(double.nan);
      expect(r.history, [0, 0, 1, 0]);
    });

    test('clock reads like a watch', () {
      expect(RecordingController.clock(Duration.zero), '0:00');
      expect(RecordingController.clock(const Duration(seconds: 65)), '1:05');
      expect(RecordingController.clock(const Duration(minutes: 12)), '12:00');
    });
  });

  group('levels', () {
    test('dBFS maps a quiet room to 0 and a shout to 1', () {
      expect(AudioCapture.levelFromDbfs(-160), 0);
      expect(AudioCapture.levelFromDbfs(-25), .5);
      expect(AudioCapture.levelFromDbfs(0), 1);
      expect(AudioCapture.levelFromDbfs(double.negativeInfinity), 0);
    });

    test('the dictation scale widens to what the phone reports', () {
      final scale = SoundLevelScale();
      expect(scale.normalise(-2), 0);
      expect(scale.normalise(10), 1);
      expect(scale.normalise(4), .5);
      // An iOS-style negative dB widens the floor rather than pinning to 0.
      expect(scale.normalise(-50), 0);
      expect(scale.normalise(-26), closeTo(.4, .001));
    });
  });

  group('DictationSession', () {
    test('delete and record-again undo only this take', () async {
      FakeHaptics.install();
      var text = 'Earlier note';
      final stt = FakeDictation();
      final session = DictationSession(
        dictation: stt,
        read: () => text,
        write: (t) => text = t,
      );
      await session.start(AppLanguage.en);
      stt.say('Telma subah');
      expect(text, 'Earlier note Telma subah');
      session.recorder.tick(const Duration(seconds: 3));
      await session.stop();
      expect(session.recorder.phase, RecordingPhase.recorded);
      session.delete();
      expect(text, 'Earlier note');
      expect(session.recorder.phase, RecordingPhase.deleted);

      stt.say('late final words');
      expect(text, 'Earlier note', reason: 'a deleted take stays deleted');
    });

    test('no words back is "nothing heard"', () async {
      FakeHaptics.install();
      var text = '';
      final stt = FakeDictation();
      final session = DictationSession(
        dictation: stt,
        read: () => text,
        write: (t) => text = t,
      );
      await session.start(AppLanguage.hi);
      stt.loud(10);
      session.recorder.tick(const Duration(seconds: 4));
      await session.stop();
      expect(session.recorder.phase, RecordingPhase.silent);
    });

    test('a device without dictation leaves nothing half-open', () async {
      FakeHaptics.install();
      final session = DictationSession(
        dictation: FakeDictation(works: false),
        read: () => '',
        write: (_) {},
      );
      expect(await session.start(AppLanguage.en), isFalse);
      expect(session.recorder.phase, RecordingPhase.idle);
    });
  });

  group('words step', () {
    late FakeDictation stt;
    late FakeAudio mic;
    late FakeClipPlayer player;
    late FakeHaptics haptics;

    Future<VisitWizardController> open(WidgetTester tester) async {
      haptics = FakeHaptics.install();
      stt = FakeDictation();
      mic = FakeAudio();
      player = FakeClipPlayer();
      final c = await wizard();
      usePhoneSurface(tester, size: const Size(412, 1200));
      await tester.pumpWidget(
        themed(
          WizardScreen(
            controller: c,
            consent: (_) async => true,
            scanner: FakeScanner(const ScanOutcome.unsupported()),
            photos: FakePhotos(const []),
            dictation: stt,
            audio: mic,
            player: player,
          ),
        ),
      );
      await tester.pump();
      return c;
    }

    Finder speakButton() => find.byWidgetPredicate((w) => w is FilledButton);

    testWidgets('speak: idle → listening → recorded 0:42 → deleted', (
      tester,
    ) async {
      final c = await open(tester);
      c.setWords(SourceKind.doctor, 'Before');
      await tester.pump();
      expect(find.text('Listening'), findsNothing);

      await tester.tap(speakButton().first);
      await tester.pump();
      expect(find.text('Listening'), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      expect(haptics.calls, [tap]);

      // The transcript shows within the frame the words arrive in.
      stt.say('Telma 40 subah');
      stt.loud(8);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Before Telma 40 subah'), findsOneWidget);

      await tester.pump(const Duration(seconds: 42));
      expect(find.text('0:42'), findsOneWidget);

      await tester.tap(find.text('Listening… tap to stop'));
      await tester.pump();
      expect(find.text('Recorded 0:42'), findsOneWidget);
      expect(find.text('Listening'), findsNothing);
      expect(find.text('Play'), findsNothing, reason: 'words, not audio');
      expect(haptics.calls, [tap, confirm]);
      expect(stt.stops, 1);

      await tester.tap(find.text('Delete'));
      await tester.pump();
      expect(find.textContaining('Recorded'), findsNothing);
      expect(c.wordsOf(SourceKind.doctor), 'Before');
    });

    testWidgets('speak: a slip of the finger says "nothing heard"', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(speakButton().first);
      await tester.pump();
      stt.say('Tel');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Listening… tap to stop'));
      await tester.pump();
      expect(find.text('Nothing heard, try again'), findsOneWidget);
      expect(find.textContaining('Recorded'), findsNothing);
      expect(haptics.calls, [tap, error]);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.text('Listening'), findsOneWidget);
      expect(find.text('Nothing heard, try again'), findsNothing);
    });

    testWidgets('audio: recorded, played, deleted', (tester) async {
      final c = await open(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Speak'));
      await tester.pump();
      expect(find.text('Recording'), findsOneWidget);
      mic.loud(.7);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('0:05'), findsOneWidget);

      await tester.tap(find.text('Stop and save'));
      await tester.pump();
      expect(find.text('Recorded 0:05'), findsOneWidget);
      expect(c.visit.doctorAudioPath, 'clip.m4a');
      expect(haptics.calls, [tap, confirm]);

      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(player.played, ['clip.m4a']);

      await tester.tap(find.text('Delete'));
      await tester.pump();
      expect(c.visit.doctorAudioPath, isNull);
      expect(find.textContaining('Recorded'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Speak'), findsOneWidget);
    });

    testWidgets('audio: a silent take is not kept', (tester) async {
      final c = await open(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Speak'));
      await tester.pump();
      mic.loud(.03);
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('Stop and save'));
      await tester.pump();
      expect(find.text('Nothing heard, try again'), findsOneWidget);
      expect(c.visit.doctorAudioPath, isNull);
      expect(haptics.calls, [tap, error]);
    });

    testWidgets('caretaker note: the mic says what it heard', (tester) async {
      final c = await open(tester);
      c.setWords(SourceKind.doctor, 'Telma 40 subah khane ke baad');
      await c.next();
      await tester.pump();
      final mic = find.byIcon(Icons.mic_rounded);
      await tester.ensureVisible(mic);
      await tester.tap(mic);
      await tester.pump();
      expect(find.text('Listening'), findsOneWidget);
      stt.say('BP roz naapein');
      await tester.pump(const Duration(seconds: 7));
      expect(find.text('BP roz naapein'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.stop_circle_rounded));
      await tester.pump();
      expect(find.text('Recorded 0:07'), findsOneWidget);
      expect(c.visit.caretakerNote, 'BP roz naapein');
    });
  });
}
