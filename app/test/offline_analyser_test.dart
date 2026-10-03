import 'package:flutter_test/flutter_test.dart';
import 'package:winger/domain/mention.dart';
import 'package:winger/domain/merge_engine.dart';
import 'package:winger/domain/offline_analyser.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/medicines/medicine_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OfflineAnalyser', () {
    test('runs all four sources on the device', () {
      final r = OfflineAnalyser.analyse(const [
        SourceText(SourceKind.doctor, 'Telma forty, subah ek, khane ke baad'),
        SourceText(SourceKind.prescription, 'Tab Telma 40 1-0-0 p/c'),
        SourceText(SourceKind.bill, 'TELMA 40 TAB  30 NOS'),
        SourceText(SourceKind.chemist, ''),
      ]);
      expect(r.sourcesRead, {
        SourceKind.doctor,
        SourceKind.prescription,
        SourceKind.bill,
      });
      expect(r.rows.single.verdict, Verdict.green);
      expect(r.count(Verdict.green), 1);
    });

    test('a spoken word nothing else backs up is not a medicine', () {
      final r = OfflineAnalyser.analyse(const [
        SourceText(SourceKind.doctor, 'Namaste. Telma chalu rakhiye.'),
        SourceText(SourceKind.bill, 'TELMA 40 TAB'),
      ]);
      expect(r.rows.map((x) => x.name), ['TELMA 40']);
      expect(r.dropped.map((m) => m.name), ['NAMASTE']);
    });

    test('an online reading lands in the same merge, with no extra trust', () {
      final r = OfflineAnalyser.analyse(
        const [SourceText(SourceKind.bill, 'TELMA 40 TAB')],
        extra: const [
          Mention(
            source: SourceKind.prescription,
            name: 'TELMA 40',
            raw: 'Telma 40 1-0-1',
            sig: Sig(slots: [DoseSlot.morning, DoseSlot.night]),
            readOnline: true,
            uncertain: true,
          ),
        ],
      );
      expect(r.rows.single.verdict, Verdict.amber);
      expect(r.rows.single.reasons, contains(AmberReason.uncertain));
    });

    test('nothing in, nothing out — and no invented rows', () {
      final r = OfflineAnalyser.analyse(const []);
      expect(r.rows, isEmpty);
      expect(r.sourcesRead, isEmpty);
    });
  });

  group('MedicineStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    ScheduledMedicine med(String id, List<DoseSlot> slots) => ScheduledMedicine(
      id: id,
      name: id.toUpperCase(),
      sig: Sig(slots: slots),
      startDate: DateTime(2026, 9, 26),
    );

    test('approving adds the medicines and one record', () async {
      final store = await MedicineStore.load();
      await store.approve(
        visitId: 'v1',
        approved: [
          med('telma-40', [DoseSlot.morning]),
          med('glycomet-500', [DoseSlot.morning, DoseSlot.night]),
        ],
      );
      expect(store.medicines(), hasLength(2));
      expect(store.records().single.medicineNames, [
        'TELMA-40',
        'GLYCOMET-500',
      ]);
    });

    test('a newer prescription replaces the same medicine', () async {
      final store = await MedicineStore.load();
      await store.approve(
        visitId: 'v1',
        approved: [
          med('telma-40', [DoseSlot.morning]),
        ],
      );
      await store.approve(
        visitId: 'v2',
        approved: [
          med('telma-40', [DoseSlot.night]),
        ],
      );
      expect(store.medicines().single.sig.slots, [DoseSlot.night]);
      expect(store.records(), hasLength(2));
    });

    test('stopping keeps the medicine but takes it off the schedule', () async {
      final store = await MedicineStore.load();
      await store.approve(
        visitId: 'v1',
        approved: [
          med('telma-40', [DoseSlot.morning]),
        ],
      );
      await store.stop('telma-40');
      expect(store.medicines(), hasLength(1));
      expect(store.active(), isEmpty);
    });

    test('stored JSON matches the documented schema', () async {
      final store = await MedicineStore.load();
      await store.approve(
        visitId: 'v1',
        approved: [
          med('telma-40', [DoseSlot.morning]),
        ],
      );
      final raw = (await SharedPreferences.getInstance()).getString(
        'scheduled_medicines',
      )!;
      expect(raw, contains('"slots":["morning"]'));
      expect(raw, contains('"active":true'));
      expect(raw, isNot(contains('"sos"')), reason: 'omitted when false');
    });
  });
}
