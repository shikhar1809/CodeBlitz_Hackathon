import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/dose_clock.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/doses/dose_log_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const m = DoseSlot.morning;
const n = DoseSlot.night;

void main() {
  late DoseLogStore logs;
  final day = DateTime(2026, 9, 26);
  DateTime at(int h, [int min = 0]) => DateTime(2026, 9, 26, h, min);

  final meds = [
    ScheduledMedicine(
      id: 'telma-40',
      name: 'TELMA 40',
      sig: const Sig(slots: [m]),
      startDate: DateTime(2026, 9, 20),
    ),
    ScheduledMedicine(
      id: 'glycomet-500',
      name: 'GLYCOMET 500',
      sig: const Sig(slots: [m, n]),
      startDate: DateTime(2026, 9, 20),
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    logs = await DoseLogStore.load();
  });

  group('DoseClock', () {
    test('nominal times', () {
      expect(DoseClock.dueAt(day, m), at(8));
      expect(DoseClock.dueAt(day, n), at(21));
      expect(DoseClock.missedAt(day, m), at(9));
    });
  });

  group('status is derived, day to day', () {
    test('before the time: not yet', () {
      expect(logs.statusOf(at(7, 59), day, m), DoseStatus.notYet);
    });

    test('forty minutes late is late, not missed', () {
      expect(logs.statusOf(at(8, 40), day, m), DoseStatus.dueNow);
    });

    test('an hour late is missed', () {
      expect(logs.statusOf(at(9, 1), day, m), DoseStatus.missed);
    });

    test('the bug that hid every missed dose: a timestamped date', () {
      // Both callers pass DateTime.now() as the date. Comparing that against
      // midnight made a same-day slot "pending" forever.
      final now = at(10, 15);
      expect(logs.statusOf(now, now, m), DoseStatus.missed);
    });

    test('yesterday, not taken: missed', () {
      expect(
        logs.statusOf(at(7), day.subtract(const Duration(days: 1)), n),
        DoseStatus.missed,
      );
    });

    test('taken is taken, whenever it is asked', () async {
      await logs.logTaken(
        date: at(8, 10),
        slot: m,
        medicineIds: ['telma-40'],
        at: at(8, 10),
      );
      expect(logs.statusOf(at(23), day, m), DoseStatus.taken);
      expect(logs.statusOf(at(23), at(23), m), DoseStatus.taken);
    });
  });

  group('the calendar', () {
    test('a day with a miss is red, a fully taken day is green', () async {
      final yesterday = day.subtract(const Duration(days: 1));
      expect(logs.markFor(at(12), yesterday, meds), DayMark.missed);

      await logs.logTaken(date: yesterday, slot: m, medicineIds: [], at: at(8));
      await logs.logTaken(
        date: yesterday,
        slot: n,
        medicineIds: [],
        at: at(21),
      );
      expect(logs.markFor(at(12), yesterday, meds), DayMark.taken);
    });

    test('today, morning taken and night to come, is still pending', () async {
      await logs.logTaken(date: day, slot: m, medicineIds: [], at: at(8));
      expect(logs.markFor(at(12), day, meds), DayMark.pending);
    });

    test('before the first medicine: nothing due', () {
      expect(
        logs.markFor(at(12), DateTime(2026, 9, 1), meds),
        DayMark.nothingDue,
      );
    });

    test('missedOn lists only the missed slots', () {
      expect(logs.missedOn(at(12), day, meds), [m]);
      expect(logs.missedOn(at(22, 30), day, meds), [m, n]);
    });
  });

  test('confirming the same slot twice keeps one log', () async {
    await logs.logTaken(date: day, slot: m, medicineIds: ['a'], at: at(8));
    await logs.logTaken(
      date: day,
      slot: m,
      medicineIds: ['a', 'b'],
      at: at(8, 5),
    );
    expect(logs.all(), hasLength(1));
    expect(logs.logFor(day, m)!.taken, ['a', 'b']);
  });

  test('the stored shape matches the documented schema', () async {
    await logs.logTaken(
      date: at(8),
      slot: m,
      medicineIds: ['telma-40'],
      at: at(8, 10),
    );
    final raw = (await SharedPreferences.getInstance()).getString('dose_logs')!;
    expect(raw, contains('"date":"2026-09-26T00:00:00.000"'));
    expect(raw, contains('"status":"taken"'));
    expect(raw, contains('"taken":["telma-40"]'));
  });
}
