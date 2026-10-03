import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/app_state.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/l10n/l10n.dart';
import 'package:winger/core/theme/app_theme.dart';
import 'package:winger/core/voice/speech_engine.dart';
import 'package:winger/core/voice/voice_guide.dart';
import 'package:winger/core/widgets/pictograms.dart';
import 'package:winger/domain/dose_alarm.dart';
import 'package:winger/domain/medicine_form.dart';
import 'package:winger/domain/reminder_planner.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/doses/alarm_launcher.dart';
import 'package:winger/features/doses/alarm_screen.dart';
import 'package:winger/features/doses/dose_log_store.dart';
import 'package:winger/features/medicines/medicine_store.dart';
import 'package:winger/platform/dose_reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden_harness.dart';

const m = DoseSlot.morning;
final now = DateTime(2026, 9, 26, 8, 2);
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
  sig: const Sig(slots: [m], food: FoodTiming.after, unitsPerDose: .5),
  startDate: start,
);
final pan = ScheduledMedicine(
  id: 'pan-40',
  name: 'PAN 40 CAP',
  sig: const Sig(slots: [m], food: FoodTiming.before, unitsPerDose: 2),
  startDate: start,
);

/// Remembers which slots were cancelled; rings nothing.
class FakeReminders implements DoseReminders {
  final cancelled = <DoseSlot>[];
  final synced = <List<PlannedReminder>>[];

  @override
  Future<void> cancelSlot(DoseSlot slot) async => cancelled.add(slot);

  @override
  Future<ReminderStatus> sync(List<PlannedReminder> plan) async {
    synced.add(plan);
    return ReminderStatus.ready;
  }

  @override
  Future<AlarmPayload?> launchAlarm() async => null;

  @override
  Stream<AlarmPayload> get alarms => const Stream.empty();

  @override
  Future<bool> ringSoon(
    AlarmPayload payload, {
    required String title,
    required String body,
    Duration after = const Duration(seconds: 15),
  }) async => false;
}

class FakeEngine implements SpeechEngine {
  final spoken = <String>[];

  @override
  String get name => 'fake';

  @override
  Future<SpeakResult> speak(String text, AppLanguage language) async {
    spoken.add(text);
    return const SpeakResult.spoke('fake');
  }

  @override
  Future<void> stop() async {}
}

void main() {
  late DoseLogStore logs;
  late FakeReminders reminders;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    logs = await DoseLogStore.load();
    reminders = FakeReminders();
  });

  AlarmScreen alarm(
    List<ScheduledMedicine> meds, {
    bool demo = false,
    MedicinePhoto photoOf = storedPhoto,
    void Function(DoseSlot, DateTime)? onTaken,
    void Function(DoseSlot, DateTime)? onLater,
  }) => AlarmScreen(
    slot: m,
    date: now,
    medicines: meds,
    logs: logs,
    reminders: reminders,
    clock: () => now,
    demo: demo,
    photoOf: photoOf,
    onTaken: onTaken,
    onLater: onLater,
  );

  /// The alarm pushed over a plain page, as the app pushes it; returns what
  /// the route popped with.
  Future<List<bool?>> pushAlarm(WidgetTester tester, AlarmScreen screen) async {
    usePhoneSurface(tester);
    final results = <bool?>[];
    await tester.pumpWidget(
      themed(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await Navigator.of(context)
                    .push(MaterialPageRoute<bool>(builder: (_) => screen)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  group('answers', () {
    testWidgets('Yes logs the slot, cancels its alarms, and closes', (
      tester,
    ) async {
      final taken = <DoseSlot>[];
      final results = await pushAlarm(
        tester,
        alarm([telma], onTaken: (slot, _) => taken.add(slot)),
      );
      await tester.tap(find.text('Yes, taken'));
      await tester.pumpAndSettle();

      expect(logs.logFor(now, m)!.taken, ['telma-40']);
      expect(reminders.cancelled, [m]);
      expect(taken, [m]);
      expect(results, [true]);
      expect(find.text('Saved. Well done.'), findsOneWidget);
    });

    testWidgets('No logs nothing, cancels nothing, and re-syncs', (
      tester,
    ) async {
      final later = <DoseSlot>[];
      final results = await pushAlarm(
        tester,
        alarm([telma], onLater: (slot, _) => later.add(slot)),
      );
      await tester.tap(find.text('No / Later'));
      await tester.pumpAndSettle();

      expect(logs.logFor(now, m), isNull);
      expect(logs.statusOf(now, now, m), DoseStatus.dueNow);
      expect(reminders.cancelled, isEmpty, reason: 'the nudge stays set');
      expect(later, [m]);
      expect(results, [false]);
      expect(find.text('Not saved. The dose is still due.'), findsOneWidget);
    });

    testWidgets('a demo writes nothing, whichever is pressed', (tester) async {
      await pushAlarm(tester, alarm([telma], demo: true));
      expect(find.text('Demo — nothing on this screen is saved'), findsOne);
      await tester.tap(find.text('Yes, taken'));
      await tester.pumpAndSettle();
      expect(logs.logFor(now, m), isNull);
      expect(reminders.cancelled, isEmpty);
    });
  });

  group('what it shows', () {
    testWidgets('every medicine in the slot, and Yes logs them all', (
      tester,
    ) async {
      await pushAlarm(tester, alarm([telma, glycomet, pan]));
      for (final name in ['TELMA 40', 'GLYCOMET 500', 'PAN 40 CAP']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      await tester.tap(find.text('Yes, taken'));
      await tester.pumpAndSettle();
      expect(logs.logFor(now, m)!.taken, [
        'telma-40',
        'glycomet-500',
        'pan-40',
      ]);
    });

    testWidgets('the dose as pictures: form, tablets, food', (tester) async {
      await pushAlarm(tester, alarm([telma, pan]));
      expect(find.byType(FormPictogram), findsNWidgets(2));
      final forms = tester
          .widgetList<FormPictogram>(find.byType(FormPictogram))
          .map((f) => f.form);
      expect(forms, [MedicineForm.tablet, MedicineForm.capsule]);
      expect(find.byType(DoseDots), findsNWidgets(2));
      expect(find.byType(FoodPictogram), findsNWidgets(2));
      expect(find.text('after food'), findsOneWidget);
      expect(find.text('before food'), findsOneWidget);
      expect(find.byIcon(slotIcon(m)), findsOneWidget);
    });

    testWidgets('a photo replaces the form pictogram when there is one', (
      tester,
    ) async {
      await pushAlarm(
        tester,
        alarm(
          [telma, pan],
          photoOf: (med) => med.id == 'telma-40'
              ? const ColoredBox(key: Key('strip'), color: Colors.teal)
              : null,
        ),
      );
      expect(find.byKey(const Key('strip')), findsOneWidget);
      expect(find.byType(FormPictogram), findsOneWidget, reason: 'PAN only');
    });

    testWidgets('read aloud: the slot, each dose, the question', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final engine = FakeEngine();
      final guide = VoiceGuide(engine: engine, enabled: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, inner) => L10n(
            language: AppLanguage.en,
            child: VoiceScope(guide: guide, child: inner!),
          ),
          home: alarm([telma, glycomet]),
        ),
      );
      await tester.pump();
      expect(engine.spoken, [
        'Morning. Time for your medicine. '
            'TELMA 40, one tablet, after food. '
            'GLYCOMET 500, half a tablet, after food. '
            'Did you take it? Press the green button if you have taken it.',
      ]);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('opening from a notification', () {
    Future<(NavigatorState, AppState)> host(WidgetTester tester) async {
      usePhoneSurface(tester);
      final state = await freshState();
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          theme: AppTheme.light(),
          builder: (context, inner) =>
              L10n(language: AppLanguage.en, child: inner!),
          home: const Scaffold(body: Text('home')),
        ),
      );
      // The alarm needs the app's state for the caregiver alert.
      return (key.currentState!, state);
    }

    testWidgets('a due slot opens the alarm with its medicines', (
      tester,
    ) async {
      final (nav, openState) = await host(tester);
      final store = await MedicineStore.load();
      await store.approve(visitId: 'v', approved: [telma, glycomet]);
      final opened = await tester.runAsync(
        () => openDoseAlarm(
          nav,
          AlarmPayload(slot: m, date: now),
          state: openState,
          reminders: reminders,
          clock: () => now,
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(find.text('TELMA 40'), findsOneWidget);
      expect(find.text('GLYCOMET 500'), findsOneWidget);
    });

    testWidgets('a slot already taken does not ask again', (tester) async {
      final (nav, openState) = await host(tester);
      final store = await MedicineStore.load();
      await store.approve(visitId: 'v', approved: [telma]);
      final logs = await DoseLogStore.load();
      await logs.logTaken(date: now, slot: m, medicineIds: const [], at: now);
      final opened = await tester.runAsync(
        () => openDoseAlarm(
          nav,
          AlarmPayload(slot: m, date: now),
          state: openState,
          reminders: reminders,
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, isFalse);
      expect(find.text('Yes, taken'), findsNothing);
    });

    testWidgets('the demo, on an empty schedule, shows the demo medicine', (
      tester,
    ) async {
      final (nav, openState) = await host(tester);
      final opened = await tester.runAsync(
        () => openDoseAlarm(
          nav,
          AlarmPayload(slot: m, date: now, demo: true),
          state: openState,
          reminders: reminders,
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(find.text(DoseAlarm.demoMedicine.name), findsOneWidget);
      expect(find.text('Demo — nothing on this screen is saved'), findsOne);
    });
  });

  group('goldens', () {
    Future<void> shoot(WidgetTester tester, AppLanguage language) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        themed(alarm([telma, glycomet, pan]), language: language),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dose_4_alarm_${language.code}.png'),
      );
    }

    testWidgets('the alarm, in English', (t) => shoot(t, AppLanguage.en));
    testWidgets('the alarm, in Hindi', (t) => shoot(t, AppLanguage.hi));
  });
}
