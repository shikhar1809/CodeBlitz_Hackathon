import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/feedback/haptics.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/doses/dose_log_store.dart';
import 'package:winger/features/doses/dose_screen.dart';
import 'package:winger/features/doses/schedule_screen.dart';
import 'package:winger/features/medicines/medicine_store.dart';
import 'package:winger/features/patient/prescriptions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_haptics.dart';
import 'support/golden_harness.dart';

const m = DoseSlot.morning;
const n = DoseSlot.night;

final now = DateTime(2026, 9, 26, 10, 30);
final start = DateTime(2026, 9, 26);

final telma = ScheduledMedicine(
  id: 'telma-40',
  name: 'TELMA 40',
  sig: const Sig(slots: [m], food: FoodTiming.after),
  startDate: start,
);
final glycomet = ScheduledMedicine(
  id: 'glycomet-500',
  name: 'GLYCOMET 500',
  sig: const Sig(slots: [m, n], food: FoodTiming.after, durationDays: 30),
  startDate: start,
);
final pan = ScheduledMedicine(
  id: 'pan-40',
  name: 'PAN 40',
  sig: const Sig(slots: [m], food: FoodTiming.before),
  startDate: start,
);
final meftal = ScheduledMedicine(
  id: 'meftal',
  name: 'MEFTAL',
  sig: const Sig(sos: true),
  startDate: start,
);

void main() {
  late MedicineStore store;
  late DoseLogStore logs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await MedicineStore.load();
    logs = await DoseLogStore.load();
    await store.approve(
      visitId: 'v1',
      approved: [glycomet, meftal, telma],
      at: now,
      evidence: const ['doctor', 'bill'],
    );
  });

  Future<void> shoot(
    WidgetTester tester,
    Widget screen,
    String name, {
    AppLanguage language = AppLanguage.en,
    double height = 892,
  }) async {
    usePhoneSurface(tester, size: Size(412, height));
    await tester.pumpWidget(themed(screen, language: language));
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('taking a dose, in Hindi', (t) async {
    await shoot(
      t,
      DoseScreen(
        slot: m,
        date: now,
        medicines: [telma, glycomet, pan],
        logs: logs,
        clock: () => now,
      ),
      'dose_1_take_hi',
      language: AppLanguage.hi,
      height: 1000,
    );
  });

  testWidgets('the schedule and the month, in English', (t) async {
    await logs.logTaken(date: now, slot: m, medicineIds: const [], at: now);
    await shoot(
      t,
      ScheduleScreen(
        store: store,
        logs: logs,
        clock: () => now,
        reminderBanner: 'Reminders only work in the Android app.',
        onShare: () {},
      ),
      'dose_2_schedule_en',
      height: 1300,
    );
  });

  testWidgets('the schedule and the month, in Hindi', (t) async {
    await logs.logTaken(date: now, slot: m, medicineIds: const [], at: now);
    await shoot(
      t,
      ScheduleScreen(store: store, logs: logs, clock: () => now),
      'dose_3_schedule_hi',
      language: AppLanguage.hi,
      height: 1300,
    );
  });

  testWidgets('my prescriptions, filled', (t) async {
    await shoot(
      t,
      PrescriptionsScreen(records: store.records()),
      'patient_7_prescriptions_filled_en',
    );
  });

  group('the two gates', () {
    testWidgets('"All taken" stays locked until every row is ticked', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        themed(
          DoseScreen(
            slot: m,
            date: now,
            medicines: [telma, glycomet],
            logs: logs,
            clock: () => now,
          ),
        ),
      );
      FilledButton button() => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('All taken'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(button().onPressed, isNull);
      await tester.tap(find.text('TELMA 40'));
      await tester.pump();
      expect(button().onPressed, isNull, reason: 'one of two is not all');
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.text('GLYCOMET 500'));
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });

    testWidgets('confirming logs, closes, and only then alerts', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final haptics = FakeHaptics.install();
      final order = <String>[];
      await tester.pumpWidget(
        themed(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => DoseScreen(
                        slot: m,
                        date: now,
                        medicines: [telma],
                        logs: logs,
                        clock: () => now,
                        onConfirmed: (slot, date) {
                          order.add('alert:${logs.logFor(date, slot) != null}');
                        },
                      ),
                    ),
                  );
                  order.add('closed');
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TELMA 40'));
      await tester.pump();
      await tester.tap(find.text('All taken'));
      await tester.pumpAndSettle();

      expect(logs.logFor(now, m)!.taken, ['telma-40']);
      expect(order.first, 'alert:true', reason: 'the log is written first');
      expect(find.text('All taken'), findsNothing, reason: 'the screen closed');
      expect(haptics.calls, [HapticKind.confirm], reason: 'one buzz, on save');
    });

    testWidgets('a slot already taken cannot be opened again', (tester) async {
      await logs.logTaken(date: now, slot: m, medicineIds: const [], at: now);
      usePhoneSurface(tester);
      await tester.pumpWidget(
        themed(ScheduleScreen(store: store, logs: logs, clock: () => now)),
      );
      await tester.tap(find.text('Morning'));
      await tester.pumpAndSettle();
      expect(find.text('All taken'), findsNothing);
    });

    testWidgets('opening the schedule looks for missed doses', (tester) async {
      usePhoneSurface(tester);
      List<ScheduledMedicine>? seen;
      await tester.pumpWidget(
        themed(
          ScheduleScreen(
            store: store,
            logs: logs,
            clock: () => now,
            onOpened: (meds, at) async => seen = meds,
          ),
        ),
      );
      expect(seen, hasLength(3));
      // The morning card at 10:30, and the calendar legend.
      expect(find.text('Missed'), findsNWidgets(2));
      expect(find.text('Not yet'), findsOneWidget, reason: 'night');
    });
  });
}
