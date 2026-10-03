import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/schedule_engine.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';

const m = DoseSlot.morning;
const a = DoseSlot.afternoon;
const n = DoseSlot.night;

ScheduledMedicine med(
  String name,
  Sig sig, {
  DateTime? start,
  bool active = true,
}) => ScheduledMedicine(
  id: name.toLowerCase(),
  name: name,
  sig: sig,
  startDate: start ?? DateTime(2026, 9, 26),
  active: active,
);

void main() {
  final day1 = DateTime(2026, 9, 26);
  DateTime day(int k) => day1.add(Duration(days: k - 1));

  test('a daily medicine is due every day from its start', () {
    final telma = med('TELMA 40', const Sig(slots: [m, n]));
    expect(ScheduleEngine.isDueOn(telma, day(1)), isTrue);
    expect(ScheduleEngine.isDueOn(telma, day(200)), isTrue);
    expect(
      ScheduleEngine.isDueOn(telma, day1.subtract(const Duration(days: 1))),
      isFalse,
    );
  });

  test('a time of day on the date does not matter, only the day', () {
    final telma = med('TELMA 40', const Sig(slots: [m]));
    expect(
      ScheduleEngine.isDueOn(telma, DateTime(2026, 9, 26, 23, 59)),
      isTrue,
    );
  });

  test('a course stops on its own', () {
    final antibiotic = med(
      'AUGMENTIN 625',
      const Sig(slots: [m, n], durationDays: 5),
    );
    expect(ScheduleEngine.isDueOn(antibiotic, day(5)), isTrue);
    expect(ScheduleEngine.isDueOn(antibiotic, day(6)), isFalse);
    expect(ScheduleEngine.daysLeft(antibiotic, day(3)), 3);
    expect(ScheduleEngine.daysLeft(antibiotic, day(9)), 0);
  });

  test('alternate days', () {
    final d = med('VIT D', const Sig(slots: [m], everyNDays: 2));
    expect(
      [for (var k = 1; k <= 5; k++) ScheduleEngine.isDueOn(d, day(k))],
      [true, false, true, false, true],
    );
  });

  test('SOS is never on the schedule, and is listed as when needed', () {
    final dolo = med('DOLO 650', const Sig(sos: true));
    expect(ScheduleEngine.isDueOn(dolo, day(1)), isFalse);
    expect(ScheduleEngine.whenNeeded([dolo], day(1)), [dolo]);
    expect(ScheduleEngine.dueOn([dolo], day(1)), isEmpty);
  });

  test('STAT is due once, on the day it was approved', () {
    final stat = med('INJ X', const Sig(stat: true));
    expect(ScheduleEngine.isDueOn(stat, day(1)), isTrue);
    expect(ScheduleEngine.isDueOn(stat, day(2)), isFalse);
    expect(ScheduleEngine.dueOn([stat], day(1)).keys, [m]);
  });

  test('a stopped medicine is not due', () {
    final old = med('OLD', const Sig(slots: [m]), active: false);
    expect(ScheduleEngine.isDueOn(old, day(1)), isFalse);
  });

  test('a medicine with no timing is never quietly given one', () {
    final unknown = med('UNKNOWN', const Sig());
    expect(ScheduleEngine.isDueOn(unknown, day(1)), isFalse);
  });

  test('empty slots are left out of the day', () {
    final meds = [
      med('TELMA 40', const Sig(slots: [m])),
      med('GLYCOMET 500', const Sig(slots: [m, n])),
    ];
    final today = ScheduleEngine.dueOn(meds, day(1));
    expect(today.keys, [m, n]);
    expect(today[m]!.map((x) => x.name), ['TELMA 40', 'GLYCOMET 500']);
    expect(today[n]!.map((x) => x.name), ['GLYCOMET 500']);
    expect(today.containsKey(a), isFalse);
  });

  test('a scheduled medicine round-trips through JSON', () {
    final x = ScheduledMedicine(
      id: 'telma-40',
      name: 'TELMA 40',
      strength: '40',
      sig: const Sig(slots: [m, n], food: FoodTiming.after),
      startDate: day1,
      purpose: 'BP',
    );
    final back = ScheduledMedicine.fromJson(x.toJson());
    expect(back.name, 'TELMA 40');
    expect(back.sig, x.sig);
    expect(back.purpose, 'BP');
    expect(back.startDate, day1);
  });
}
