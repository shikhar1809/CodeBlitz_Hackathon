import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/l10n/app_strings.dart';
import 'package:winger/domain/dose_alarm.dart';
import 'package:winger/domain/medicine_form.dart';
import 'package:winger/domain/reminder_planner.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';

const en = AppStrings(AppLanguage.en);
const m = DoseSlot.morning;
const n = DoseSlot.night;
final start = DateTime(2026, 9, 26);
DateTime at(int day, int h, [int min = 0]) => DateTime(2026, 9, day, h, min);

ScheduledMedicine med(String name, Sig sig) => ScheduledMedicine(
  id: name.toLowerCase(),
  name: name,
  sig: sig,
  startDate: start,
);

void main() {
  group('payload', () {
    test('round-trips slot and day, and drops the time', () {
      final p = AlarmPayload(slot: n, date: at(26, 21, 30));
      expect(p.encode(), 'dose|night|2026-09-26');
      expect(AlarmPayload.decode(p.encode()), p);
      expect(AlarmPayload.decode(p.encode())!.date, DateTime(2026, 9, 26));
    });

    test('the demo flag survives the trip', () {
      final p = AlarmPayload(slot: m, date: start, demo: true);
      expect(p.encode(), 'dose|morning|2026-09-26|demo');
      expect(AlarmPayload.decode(p.encode())!.demo, isTrue);
    });

    test('anything that is not ours is null, never a guess', () {
      for (final raw in [
        null,
        '',
        'dose',
        'dose|lunch|2026-09-26',
        'dose|morning|26-09-2026',
        'dose|morning|2026-02-31',
        'dose|morning|2026-09-26|extra',
        'dose|morning|2026-09-26|demo|x',
        'visit|morning|2026-09-26',
      ]) {
        expect(AlarmPayload.decode(raw), isNull, reason: '$raw');
      }
    });
  });

  group('planned reminders carry their slot', () {
    test('both alarms of a slot point at the same slot and day', () {
      final p = ReminderPlanner.plan(
        medicines: [
          med('TELMA 40', const Sig(slots: [m, n])),
        ],
        taken: (_, _) => false,
        now: at(26, 6),
        strings: en,
      );
      expect(p.map((r) => r.payload), [
        'dose|morning|2026-09-26',
        'dose|morning|2026-09-26',
        'dose|night|2026-09-26',
        'dose|night|2026-09-26',
      ]);
      // Ids unchanged by the payload: still derived from the slot.
      expect(p.map((r) => r.id), [0, 1, 6, 7]);
    });

    test('"later" leaves the nudge in the plan: nothing was logged', () {
      // At 08:05 the patient pressed "No / Later". The re-sync still holds
      // the +30 nudge, and nothing after it.
      final p = ReminderPlanner.plan(
        medicines: [
          med('TELMA 40', const Sig(slots: [m])),
        ],
        taken: (_, _) => false,
        now: at(26, 8, 5),
        strings: en,
      );
      expect(p, hasLength(1));
      expect(p.single.nudge, isTrue);
      expect(p.single.at, at(26, 8, 30));
      expect(p.single.id, ReminderPlanner.idFor(m, nudge: true));
    });
  });

  group('opening an alarm', () {
    final telma = med('TELMA 40', const Sig(slots: [m]));
    final glycomet = med('GLYCOMET 500', const Sig(slots: [m, n]));
    final meftal = med('MEFTAL', const Sig(sos: true));

    test('shows every medicine due in that slot, as the schedule has it', () {
      final due = DoseAlarm.medicinesFor(AlarmPayload(slot: m, date: start), [
        telma,
        glycomet,
        meftal,
      ]);
      expect(due.map((x) => x.name), ['TELMA 40', 'GLYCOMET 500']);
    });

    test('a slot already taken, or now empty, does not open', () {
      final p = AlarmPayload(slot: m, date: start);
      expect(
        DoseAlarm.shouldOpen(payload: p, due: [telma], alreadyTaken: false),
        isTrue,
      );
      expect(
        DoseAlarm.shouldOpen(payload: p, due: [telma], alreadyTaken: true),
        isFalse,
      );
      expect(
        DoseAlarm.shouldOpen(payload: p, due: const [], alreadyTaken: false),
        isFalse,
      );
    });

    test('the demo rings the nearest open slot today', () {
      final target = DoseAlarm.demoTarget(
        medicines: [telma, glycomet],
        now: at(26, 19),
        taken: (_, _) => false,
      );
      expect(target, AlarmPayload(slot: n, date: start, demo: true));

      final takenNight = DoseAlarm.demoTarget(
        medicines: [telma, glycomet],
        now: at(26, 19),
        taken: (_, s) => s == n,
      );
      expect(takenNight.slot, m);
    });

    test('with nothing due today, the demo shows the demo medicine', () {
      final target = DoseAlarm.demoTarget(
        medicines: [meftal],
        now: at(26, 13),
        taken: (_, _) => false,
      );
      expect(target.slot, DoseSlot.afternoon, reason: 'nearest to 13:00');
      expect(target.demo, isTrue);
      final shown = DoseAlarm.demoMedicines(target, [meftal]);
      expect(shown.single.name, contains('DEMO'));
      expect(
        DoseAlarm.demoMedicines(AlarmPayload(slot: m, date: start), [telma]),
        [telma],
        reason: 'a real medicine when there is one',
      );
    });
  });

  test('the form pictogram reads the printed name, tablet by default', () {
    expect(formOf('TELMA 40'), MedicineForm.tablet);
    expect(formOf('AZITHRAL 500 TAB'), MedicineForm.tablet);
    expect(formOf('PAN 40 CAP'), MedicineForm.capsule);
    expect(formOf('Calpol syp'), MedicineForm.syrup);
    expect(formOf('MOXIFLOX EYE DROPS'), MedicineForm.drops);
    expect(formOf('INJ. B12'), MedicineForm.injection);
    expect(formOf('BETNOVATE-N CREAM'), MedicineForm.cream);
    // A word inside a name is not a form: CAPTOPRIL is a tablet.
    expect(formOf('CAPTOPRIL 25'), MedicineForm.tablet);
  });

  test('a medicine photo path survives the store', () {
    final withPhoto = ScheduledMedicine(
      id: 'x',
      name: 'X',
      sig: const Sig(slots: [m]),
      startDate: start,
      imagePath: '/strips/x.jpg',
    );
    final back = ScheduledMedicine.fromJson(withPhoto.toJson());
    expect(back.imagePath, '/strips/x.jpg');
    expect(back.copyWith(active: false).imagePath, '/strips/x.jpg');
    expect(med('Y', const Sig()).toJson().containsKey('imagePath'), isFalse);
  });
}
