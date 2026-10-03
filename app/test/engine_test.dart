import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/arbiter.dart';
import 'package:winger/core/clock.dart';
import 'package:winger/core/dose_book.dart';
import 'package:winger/core/ladder.dart';
import 'package:winger/core/presets.dart';
import 'package:winger/core/schedule.dart';

Preset builtin(String id) =>
    Preset.parse(File('assets/presets/$id.json').readAsStringSync(), builtin: true);

void main() {
  final t0 = DateTime(2026, 10, 3, 8, 0);

  group('Presets', () {
    test('built-in presets load', () {
      for (final id in ['women', 'prescription', 'adhd']) {
        expect(builtin(id).id, id);
      }
      expect(builtin('women').hasEmergency, isTrue);
      expect(builtin('prescription').hasEmergency, isFalse);
      expect(builtin('adhd').comingSoon, isTrue);
    });

    test('women.json matches the ladder the app runs', () {
      final file = builtin('women').ladder;
      final code = const LadderWindows().toSteps();
      expect(file.map((s) => s.id), code.map((s) => s.id));
      expect(file.map((s) => s.after), code.map((s) => s.after));
    });

    test('every bad preset fixture is rejected', () {
      final files = Directory('test/fixtures/bad_presets').listSync().whereType<File>().toList();
      expect(files.length, greaterThanOrEqualTo(15));
      for (final f in files) {
        expect(() => Preset.parse(f.readAsStringSync()), throwsA(isA<PresetError>()), reason: f.path);
      }
    });

    test('a community preset cannot dial 112 even if it says built-in things', () {
      final src = File('assets/presets/women.json').readAsStringSync();
      expect(() => Preset.parse(src), throwsA(isA<PresetError>()));
    });

    test('durations parse', () {
      expect(parseDuration('90s'), const Duration(seconds: 90));
      expect(parseDuration('2h'), const Duration(hours: 2));
      expect(() => parseDuration('-1m'), throwsA(isA<PresetError>()));
    });
  });

  group('StepLadder', () {
    final steps = builtin('prescription').ladder;

    test('fires each step at its offset and catches up after sleep', () {
      final fired = <String>[];
      final l = StepLadder(steps, onStep: (_, to) => fired.add(steps[to].id));
      l.raise(t0, to: 0, at: t0);
      l.tick(t0.add(const Duration(minutes: 29)));
      expect(fired, ['remind']);
      l.tick(t0.add(const Duration(minutes: 95)));
      expect(fired, ['remind', 'nudge', 'contact']);
      expect(l.finished, isTrue);
    });

    test('jumping restarts timing from the new step', () {
      final l = StepLadder(steps)..raise(t0, to: 0);
      l.jumpTo('nudge', t0.add(const Duration(minutes: 5)));
      expect(l.remaining(t0.add(const Duration(minutes: 5))), 30 * 60);
    });

    test('reset goes back to idle', () {
      final l = StepLadder(steps)..raise(t0, to: 1);
      l.reset(t0);
      expect(l.started, isFalse);
    });
  });

  group('Arbiter', () {
    test('safety outranks dose outranks task, oldest first', () {
      final a = Arbiter()
        ..add(CheckInRequest('task', Priority.routine, t0))
        ..add(CheckInRequest('dose2', Priority.health, t0.add(const Duration(minutes: 1))))
        ..add(CheckInRequest('dose1', Priority.health, t0));
      expect(a.current!.id, 'dose1');
      a.add(CheckInRequest('safety', Priority.safety, t0.add(const Duration(minutes: 5))));
      expect(a.current!.id, 'safety');
      expect(a.queued.map((q) => q.id), containsAll(['dose1', 'dose2', 'task']));
      expect(a.holds(Priority.health), isTrue);
      a.remove('safety');
      expect(a.holds(Priority.health), isFalse);
      expect(a.current!.id, 'dose1');
    });

    test('adding the same check-in twice keeps one', () {
      final a = Arbiter()
        ..add(CheckInRequest('x', Priority.health, t0))
        ..add(CheckInRequest('x', Priority.health, t0));
      expect(a.queued, isEmpty);
    });
  });

  group('Schedule', () {
    test('times, days and end date', () {
      final s = Schedule(
        times: [DayTime.parse('21:00'), DayTime.parse('09:00')],
        days: {DateTime.saturday},
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 10),
      );
      final got = s.between(DateTime(2026, 10, 1), DateTime(2026, 10, 20));
      // Saturdays 3 and 10 October, two times each.
      expect(got, [
        DateTime(2026, 10, 3, 9),
        DateTime(2026, 10, 3, 21),
        DateTime(2026, 10, 10, 9),
        DateTime(2026, 10, 10, 21),
      ]);
      expect(Schedule.fromJson(s.toJson()).between(DateTime(2026, 10, 1), DateTime(2026, 10, 20)), got);
    });

    test('bad times are refused', () {
      expect(() => DayTime.parse('25:00'), throwsFormatException);
      expect(() => DayTime.parse('9am'), throwsFormatException);
    });
  });

  group('DoseBook', () {
    DoseBook book() => DoseBook(builtin('prescription').ladder, medicines: [
          Medicine(
              id: 'met',
              name: 'Metformin',
              strength: '500 mg',
              schedule: Schedule(times: [const DayTime(9, 0), const DayTime(21, 0)], start: t0)),
          Medicine(
              id: 'aml', name: 'Amlodipine', strength: '5 mg', schedule: Schedule(times: [const DayTime(9, 0)], start: t0)),
        ]);

    test('groups medicines due at the same time', () {
      final b = book();
      final today = b.today(t0);
      expect(today.length, 2);
      expect(today.first.medIds, ['met', 'aml']);
      expect(b.nextDue(t0), DateTime(2026, 10, 3, 9));
    });

    test('ignored dose: remind, nudge at +30, family at +60', () {
      final clock = FakeClock(DateTime(2026, 10, 3, 9));
      final b = book();
      final fired = <String>[];
      b.onStep = (o, s) => fired.add(s.id);
      b.tick(clock.now());
      expect(fired, ['remind']);
      clock.advance(const Duration(minutes: 30));
      b.tick(clock.now());
      expect(fired, ['remind', 'nudge']);
      clock.advance(const Duration(minutes: 30));
      b.tick(clock.now());
      expect(fired, ['remind', 'nudge', 'contact']);
      expect(b.today(clock.now()).first.status(clock.now()), DoseStatus.missed);
    });

    test('taken stops the ladder; snooze never delays the family', () {
      final clock = FakeClock(DateTime(2026, 10, 3, 9));
      final b = book();
      final fired = <String>[];
      b.onStep = (o, s) => fired.add(s.id);
      b.tick(clock.now());
      final o = b.today(clock.now()).first;
      expect(b.snooze(o, clock.now()), isTrue);
      expect(o.needsAnswer(clock.now()), isFalse);
      clock.advance(const Duration(minutes: 60));
      b.tick(clock.now());
      expect(fired.last, 'contact');

      final b2 = book();
      final f2 = <String>[];
      b2.onStep = (o, s) => f2.add(s.id);
      final c2 = FakeClock(DateTime(2026, 10, 3, 9));
      b2.tick(c2.now());
      b2.markTaken(b2.today(c2.now()).first, c2.now());
      c2.advance(const Duration(hours: 2));
      b2.tick(c2.now());
      expect(f2, ['remind']);
      expect(b2.adherence(c2.now()), 1.0);
    });

    test('per-pill confirm: some taken is partial', () {
      final now = DateTime(2026, 10, 3, 9, 5);
      final b = book()..tick(now);
      final o = b.today(now).first;
      b.markTaken(o, now, ids: ['met']);
      expect(o.status(now), DoseStatus.partial);
      b.markTaken(o, now, ids: ['aml']);
      expect(o.status(now), DoseStatus.taken);
      expect(b.log.map((e) => e.kind), [DoseEventKind.partial, DoseEventKind.taken]);
    });

    test('a restart rebuilds from the log without re-sending', () {
      final now = DateTime(2026, 10, 3, 10, 30);
      final b = book();
      b.record(DoseEvent(DateTime(2026, 10, 3, 9), DoseBook.occurrenceId(DateTime(2026, 10, 3, 9)),
          DoseEventKind.reminded));
      b.record(DoseEvent(DateTime(2026, 10, 3, 10), DoseBook.occurrenceId(DateTime(2026, 10, 3, 9)),
          DoseEventKind.contacted));
      final fired = <String>[];
      b.onStep = (o, s) => fired.add(s.id);
      b.tick(now);
      expect(fired, isEmpty);
    });
  });

  group('Clock', () {
    test('demo clock skips forwards only', () {
      final c = DemoClock();
      final before = c.now();
      c.skip(const Duration(minutes: 30));
      expect(c.now().difference(before).inMinutes, greaterThanOrEqualTo(29));
      c.jumpTo(before);
      expect(c.now().isAfter(before), isTrue);
      c.reset();
      expect(c.offset, Duration.zero);
    });
  });
}
