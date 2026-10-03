import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/help_guide.dart';
import 'package:winger/core/ladder.dart';
import 'package:winger/core/phrase_match.dart';
import 'package:winger/services/alert_service.dart';
import 'package:winger/services/ear.dart';
import 'package:winger/state/app_state.dart';
import 'package:winger/ui/phone_call_view.dart';

import 'dart:io';

AppState newApp() {
  final app = AppState(alerts: AlertService(simulate: true), persist: false);
  app.finishOnboarding(
    name: 'Asha',
    lang: 'en',
    guardians: const [Guardian('Mom', '+91 98000 00001')],
    pin: '2580',
    duress: '1379',
    homeMode: false,
  );
  app.lock();
  return app;
}

bool sms(AppState app, String text) =>
    app.log.any((e) => e.text.startsWith('SMS to') && e.text.contains(text));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Disguise', () {
    test('only the real PIN opens Winger', () {
      final app = newApp();
      expect(app.tryUnlock('1111'), isFalse);
      expect(app.tryUnlock('1379'), isFalse);
      expect(app.locked, isTrue);
      expect(app.tryUnlock('2580'), isTrue);
      expect(app.locked, isFalse);
    });
  });

  group('Wingman', () {
    test('safe phrase alerts silently and the call carries on', () async {
      final app = newApp();
      final call = await app.startWingman();
      app.onHeard(const HeardEvent(Heard.safePhrase, 'did you feed the cat', 'Did you feed the cat'));
      await Future<void>.delayed(Duration.zero);
      expect(sms(app, 'SILENT ALERT'), isTrue);
      expect(app.session!.ladder.rung, Rung.idle);
      expect(call.ended, isFalse);
      await app.stopSession(reason: 'test');
    });

    test('ending the call leaves Winger listening quietly', () async {
      final app = newApp();
      final call = await app.startWingman();
      await call.end();
      expect(app.session!.listenOnly, isTrue);
      expect(app.statusText, 'Listening quietly.');
      await app.stopSession(reason: 'test');
    });

    test('a scream asks, a second one alerts guardians', () async {
      final app = newApp();
      await app.startWingman();
      await app.call!.end();
      app.hearSound('Screaming', 0.9);
      expect(app.session!.ladder.rung, Rung.ask);
      expect(app.showCheckIn, isTrue);
      app.hearSound('Screaming', 0.9);
      await Future<void>.delayed(Duration.zero);
      expect(app.session!.ladder.rung, Rung.guardian);
      expect(sms(app, 'ALERT'), isTrue);
      await app.stopSession(reason: 'test');
    });

    test('keypad PIN then # stops everything and tells guardians she is safe', () async {
      final app = newApp();
      final call = await app.startWingman();
      app.help();
      await Future<void>.delayed(Duration.zero);
      for (final k in ['2', '5', '8', '0', '#']) {
        await call.press(k);
      }
      expect(app.session, isNull);
      expect(sms(app, 'is safe'), isTrue);
    });

    test('duress PIN looks like a cancel but keeps alerting', () async {
      final app = newApp();
      await app.startWingman();
      app.help();
      expect(await app.checkInSafe('1379'), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(app.showCheckIn, isFalse);
      expect(app.statusText, 'Alert cancelled.');
      expect(app.session!.ladder.isAlerting, isTrue);
      expect(sms(app, 'Duress PIN'), isTrue);
      await app.stopSession(reason: 'test');
    });

    test('wrong PIN changes nothing', () async {
      final app = newApp();
      await app.startWingman();
      expect(await app.answerPin('0000'), isFalse);
      expect(app.session, isNotNull);
      await app.stopSession(reason: 'test');
    });
  });

  group('Help chat', () {
    final guides = HelpGuide.parse(File('assets/config/guides.json').readAsStringSync());
    test('blackmail gets numbered steps and 1930 / 112 / 181', () {
      final g = guides.match('Someone is blackmailing me')!;
      expect(g.id, 'blackmail');
      expect(g.steps.length, inInclusiveRange(4, 8));
      expect(g.helplines.map((h) => h.number), containsAll(['1930', '112', '181']));
    });
    test('every guide has 4 to 8 steps and a helpline', () {
      expect(guides.guides.length, 12);
      for (final g in guides.guides) {
        expect(g.steps.length, inInclusiveRange(4, 8), reason: g.id);
        expect(g.helplines, isNotEmpty);
      }
    });
    test('right-now messages are urgent', () {
      expect(HelpGuide.isUrgent('a man is following me right now'), isTrue);
      expect(HelpGuide.isUrgent('my boss said something last year'), isFalse);
    });
  });

  group('Phrases', () {
    test('safe phrase is heard inside a sentence', () {
      expect(matchPhrase('oh and did you feed the cat today', ['Did you feed the cat']),
          'Did you feed the cat');
      expect(matchPhrase('did you eat', ['Did you feed the cat']), isNull);
    });
    test('rules for new phrases', () {
      expect(phraseProblem('hi there', []), isNotNull);
      expect(phraseProblem('save me some dinner', []), isNull);
      expect(phraseProblem('help me now please', []), isNotNull);
    });
  });

  testWidgets('call keypad opens and sends keys', (tester) async {
    final keys = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PhoneCallView(
          name: 'Riya',
          status: '00:01',
          onEnd: () {},
          onMute: () {},
          onMuteHeld: () {},
          onSpeaker: () {},
          onKey: keys.add,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.dialpad));
    await tester.pump();
    expect(find.text('WXYZ'), findsOneWidget);
    await tester.tap(find.text('#'));
    expect(keys, ['#']);
  });
}
