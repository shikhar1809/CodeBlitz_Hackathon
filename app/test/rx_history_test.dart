import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winger/domain/rx_history.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/medicines/medicine_store.dart';

final jan = DateTime(2026, 1, 10, 11);
final apr = DateTime(2026, 4, 12, 18);
final today = DateTime(2026, 7, 1, 9);

PrescriptionRecord visit(
  String id,
  DateTime at,
  List<RecordedMedicine> meds, {
  String? doctor,
}) => PrescriptionRecord(
  id: id,
  addedAt: at,
  medicineNames: [for (final m in meds) m.name],
  medicines: meds,
  doctor: doctor,
);

RecordedMedicine med(String name, {String? strength, int? days}) =>
    RecordedMedicine(
      name: name,
      strength: strength,
      sig: Sig(slots: const [DoseSlot.morning], durationDays: days),
    );

ScheduledMedicine scheduled(String name) => ScheduledMedicine(
  id: name.toLowerCase(),
  name: name,
  sig: const Sig(slots: [DoseSlot.morning]),
  startDate: jan,
);

void main() {
  RxHistory history({List<ScheduledMedicine>? active}) => RxHistory.fromRecords(
    [
      visit('v1', jan, [
        med('TELMA 40', strength: '40'),
        med('GLYCOMET 500', strength: '500'),
        med('AZITHRAL 500', strength: '500', days: 3),
      ], doctor: 'Dr Mehra'),
      visit('v2', apr, [
        med('TELMA 40', strength: '40'),
        med('GLYCOMET 500', strength: '500'),
        med('THYRONORM 50', strength: '50', days: 90),
      ], doctor: 'Dr Rao'),
    ],
    active: active,
    clock: () => today,
  );

  group('priors', () {
    test('how often and how recently', () {
      final p = history().priorFor('TELMA 40')!;
      expect(p.visits, 2);
      expect(p.firstSeen, jan);
      expect(p.lastSeen, apr);
      expect(p.daysSinceLast, 80);
      expect(p.lastDoctor, 'Dr Rao');
      expect(p.lastSig!.slots, [DoseSlot.morning]);
    });
    test('found with OCR noise and without the strength', () {
      expect(history().priorFor('TELNA')!.name, 'TELMA 40');
      expect(history().priorFor('Telma 80')!.visits, 2);
    });
    test('never prescribed: no prior', () {
      expect(history().priorFor('ROSUVAS 10'), isNull);
      expect(RxHistory.empty.priorFor('TELMA'), isNull);
      expect(RxHistory.empty.isEmpty, isTrue);
    });
    test('a variant is a different medicine', () {
      expect(history().priorFor('GLYCOMET GP 1'), isNull);
    });
    test('every medicine once, and the last visit', () {
      expect(history().all.map((p) => p.name), [
        'TELMA 40',
        'GLYCOMET 500',
        'AZITHRAL 500',
        'THYRONORM 50',
      ]);
      expect(history().lastVisit, apr);
    });
  });

  group('strength', () {
    test('lastStrength is the most recent one recorded', () {
      final h = RxHistory.fromRecords([
        visit('a', jan, [med('TELMA 40', strength: '40')]),
        visit('b', apr, [med('TELMA 80', strength: '80')]),
      ], clock: () => today);
      expect(h.lastStrength('TELMA'), '80');
      expect(h.strengthChanged('TELMA 40', '40'), isTrue);
      expect(h.strengthChanged('TELMA 80', '80'), isFalse);
      expect(h.strengthChanged('TELMA 80.0', null), isFalse);
      expect(h.strengthChanged('TELMA', null), isFalse);
      expect(h.strengthChanged('ROSUVAS 10', '10'), isFalse);
    });
    test('old records with names only still give a strength', () {
      final h = RxHistory.fromRecords([
        PrescriptionRecord(
          id: 'old',
          addedAt: jan,
          medicineNames: const ['TELMA 40', 'ECOSPRIN'],
        ),
      ], clock: () => today);
      expect(h.lastStrength('TELMA'), '40');
      expect(h.lastStrength('ECOSPRIN'), isNull);
      expect(h.priorFor('ECOSPRIN')!.lastSig, isNull);
    });
  });

  group('chronic and missing', () {
    test('two visits two weeks apart, or a long course, is chronic', () {
      final h = history();
      expect(h.priorFor('TELMA')!.chronic, isTrue);
      expect(h.priorFor('THYRONORM')!.chronic, isTrue);
      expect(h.priorFor('AZITHRAL')!.chronic, isFalse);
    });
    test('two visits the same week are not enough', () {
      final h = RxHistory.fromRecords([
        visit('a', jan, [med('PAN 40')]),
        visit('b', jan.add(const Duration(days: 5)), [med('PAN 40')]),
      ], clock: () => today);
      expect(h.priorFor('PAN')!.chronic, isFalse);
    });
    test('chronic medicines on the last visit that today does not name', () {
      final missing = history().missingNow(['TELMA 40', 'NEWBRAND 5']);
      expect(missing.map((p) => p.name), ['GLYCOMET 500', 'THYRONORM 50']);
    });
    test('missingSince an older visit looks at that visit', () {
      final missing = history().missingSince(jan, current: ['TELMA 40']);
      // On the January visit, only TELMA and GLYCOMET; AZITHRAL was a course.
      expect(missing.map((p) => p.name), ['GLYCOMET 500']);
    });
    test('a medicine already stopped on the schedule is not missing', () {
      final h = history(active: [scheduled('TELMA 40')]);
      expect(h.missingNow(['TELMA 40']), isEmpty);
      final h2 = history(active: [scheduled('THYRONORM 50')]);
      expect(h2.missingNow(['TELMA 40']).map((p) => p.name), [
        'THYRONORM 50',
      ]);
    });
    test('OCR noise on today’s name still counts as present', () {
      expect(
        history().missingNow(['TELNA 40', 'GLYCOMFT 500', 'THYRONORM 50']),
        isEmpty,
      );
    });
    test('no history: nothing missing', () {
      expect(RxHistory.empty.missingNow(['TELMA']), isEmpty);
    });
  });

  group('MedicineStore', () {
    test('approve records strength, instruction and doctor', () async {
      SharedPreferences.setMockInitialValues({});
      final store = MedicineStore(await SharedPreferences.getInstance());
      await store.approve(
        visitId: 'v1',
        at: jan,
        doctor: 'Dr Mehra',
        approved: [
          ScheduledMedicine(
            id: 'telma-40',
            name: 'TELMA 40',
            strength: '40',
            sig: const Sig(slots: [DoseSlot.morning], durationDays: 30),
            startDate: jan,
          ),
        ],
      );
      final r = store.records().single;
      expect(r.doctor, 'Dr Mehra');
      expect(r.medicines.single.strength, '40');
      expect(r.medicines.single.sig!.durationDays, 30);
      final again = PrescriptionRecord.fromJson(r.toJson());
      expect(again.medicines.single.name, 'TELMA 40');
      expect(again.withOnlineReading('{}').medicines, hasLength(1));

      final h = store.history(clock: () => today);
      expect(h.priorFor('TELMA')!.lastDoctor, 'Dr Mehra');
      expect(h.priorFor('TELMA')!.chronic, isTrue);
      expect(h.active!.single.name, 'TELMA 40');
    });
  });
}
