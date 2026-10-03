import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/clock.dart';
import 'package:winger/core/dose_book.dart';
import 'package:winger/core/ladder.dart';
import 'package:winger/core/presets.dart';
import 'package:winger/services/alert_service.dart';
import 'package:winger/services/cloud_service.dart';
import 'package:winger/state/app_state.dart';

Map<String, Preset> loadPresets() => {
      for (final id in ['women', 'prescription', 'adhd'])
        id: Preset.parse(File('assets/presets/$id.json').readAsStringSync(), builtin: true)
    };

AppState newApp(FakeClock clock, {List<String> presets = const ['prescription'], bool women = false}) {
  final app = AppState(
    alerts: AlertService(simulate: true),
    cloud: CloudService(enabled: false),
    clock: clock,
    presets: loadPresets(),
    persist: false,
  );
  app.finishOnboarding(
    name: 'Asha',
    lang: 'en',
    guardians: [
      if (women) const Guardian('Mom', '+91 98000 00001'),
      const Guardian('Rahul', '+91 98000 00002', 'family'),
    ],
    pin: women ? '2580' : null,
    duress: women ? '1379' : null,
    presets: presets,
  );
  return app;
}

List<String> smsTo(AppState app, String name) =>
    app.log.where((e) => e.text.startsWith('SMS to $name')).map((e) => e.text).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dose due shows a check-in; Taken all stops the ladder', () {
    final clock = FakeClock(DateTime(2026, 10, 3, 8, 59));
    final app = newApp(clock)..doses.seedDemo();
    app.tick();
    expect(app.screenCheckIn, isNull);
    clock.set(DateTime(2026, 10, 3, 9, 0));
    app.tick();
    final id = app.screenCheckIn!;
    final o = app.doses.byId(id)!;
    expect(o.medIds, containsAll(['metformin', 'amlodipine']));
    app.doses.takeAll(o);
    app.tick();
    expect(app.screenCheckIn, isNull);
    clock.advance(const Duration(hours: 2));
    app.tick();
    expect(smsTo(app, 'Rahul'), isEmpty);
    expect(app.doses.book.adherence(clock.now()), 1.0);
  });

  test('ignored dose: nudge at +30, family told at +60, from the phone', () async {
    final clock = FakeClock(DateTime(2026, 10, 3, 9, 0));
    final app = newApp(clock)..doses.seedDemo();
    app.tick();
    clock.advance(const Duration(minutes: 30));
    app.tick();
    expect(app.log.any((e) => e.text.startsWith('Reminder again')), isTrue);
    expect(smsTo(app, 'Rahul'), isEmpty);
    clock.advance(const Duration(minutes: 30));
    app.tick();
    await Future<void>.delayed(Duration.zero);
    expect(smsTo(app, 'Rahul').single, contains('has not confirmed the 9:00 AM medicines'));
    final o = app.doses.book.today(clock.now()).first;
    expect(o.status(clock.now()), DoseStatus.missed);
  });

  test('Taken some confirms pill by pill', () {
    final clock = FakeClock(DateTime(2026, 10, 3, 8, 30));
    final app = newApp(clock)..doses.seedDemo();
    clock.set(DateTime(2026, 10, 3, 9, 1));
    app.tick();
    final o = app.doses.byId(app.screenCheckIn!)!;
    app.doses.takeSome(o, {'metformin'});
    expect(o.status(clock.now()), DoseStatus.partial);
    expect(app.screenCheckIn, o.id);
  });

  test('snooze hides the card but the family is still told on time', () async {
    final clock = FakeClock(DateTime(2026, 10, 3, 9, 0));
    final app = newApp(clock)..doses.seedDemo();
    app.tick();
    final o = app.doses.byId(app.screenCheckIn!)!;
    expect(app.doses.snooze(o), isTrue);
    app.tick();
    expect(app.screenCheckIn, isNull);
    clock.advance(const Duration(minutes: 11));
    app.tick();
    expect(app.screenCheckIn, o.id);
    clock.advance(const Duration(minutes: 50));
    app.tick();
    await Future<void>.delayed(Duration.zero);
    expect(smsTo(app, 'Rahul'), hasLength(1));
  });

  test('safety outranks a dose: no delay, family message held until safe', () async {
    final clock = FakeClock(DateTime(2026, 10, 3, 9, 0));
    final app = newApp(clock, presets: ['women', 'prescription'], women: true)..doses.seedDemo();
    app.tick();
    expect(app.screenCheckIn, startsWith('dose-'));

    await app.startQuiet(SessionKind.wingman);
    clock.advance(const Duration(minutes: 59, seconds: 50));
    app.help();
    app.tick();
    // Safety owns the screen the moment it climbs.
    expect(app.showCheckIn, isTrue);
    expect(app.screenCheckIn, 'safety');
    expect(app.session!.ladder.rung, Rung.guardian);

    clock.advance(const Duration(seconds: 15));
    app.tick();
    await Future<void>.delayed(Duration.zero);
    expect(smsTo(app, 'Rahul'), isEmpty, reason: 'held during the safety alert');
    expect(app.doses.heldCount, 1);

    expect(await app.checkInSafe('2580'), isTrue);
    app.tick();
    await Future<void>.delayed(Duration.zero);
    expect(smsTo(app, 'Rahul'), hasLength(1));
    await app.stopSession(reason: 'test');
  });

  test('her safety alerts never reach family contacts', () async {
    final clock = FakeClock(DateTime(2026, 10, 3, 22, 0));
    final app = newApp(clock, presets: ['women', 'prescription'], women: true);
    await app.startQuiet(SessionKind.wingman);
    await app.alertGuardians('test');
    await app.silentAlert('test');
    expect(smsTo(app, '+91 98000 00001'), isNotEmpty);
    expect(app.log.where((e) => e.text.contains('98000 00002')), isEmpty);
    await app.stopSession(reason: 'test');
  });

  test('old set-ups migrate to Women Companion', () {
    final s = Settings.fromJson({'name': 'Asha', 'onboarded': true, 'guardians': []});
    expect(s.presets, ['women']);
    expect(Settings.fromJson({'onboarded': false}).presets, isEmpty);
  });

  test('demo panel: jump to next dose and reset', () async {
    final app = AppState(
      alerts: AlertService(simulate: true),
      cloud: CloudService(enabled: false),
      clock: DemoClock(),
      presets: loadPresets(),
      persist: false,
    );
    app.finishOnboarding(name: 'Asha', lang: 'en', guardians: const [], presets: ['prescription']);
    app.doses.seedDemo();
    expect(app.jumpToNextDose(), isTrue);
    expect(app.screenCheckIn, startsWith('dose-'));
    await app.resetDemo();
    expect(app.settings.onboarded, isFalse);
    expect(app.doses.book.medicines, isEmpty);
  });
}
