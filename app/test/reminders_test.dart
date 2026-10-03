import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/core/l10n/app_strings.dart';
import 'package:winger/domain/dose_alarm.dart';
import 'package:winger/domain/reminder_planner.dart';
import 'package:winger/domain/scheduled_medicine.dart';
import 'package:winger/domain/sig.dart';
import 'package:winger/features/doses/reminder_sync.dart';
import 'package:winger/platform/dose_alarm_notification.dart';
import 'package:winger/platform/dose_reminders.dart';

const en = AppStrings(AppLanguage.en);
const m = DoseSlot.morning;
const n = DoseSlot.night;
final start = DateTime(2026, 9, 26);
DateTime at(int day, int h, [int min = 0]) => DateTime(2026, 9, day, h, min);

ScheduledMedicine med(String name, Sig sig, {bool active = true}) =>
    ScheduledMedicine(
      id: name.toLowerCase(),
      name: name,
      sig: sig,
      startDate: start,
      active: active,
    );

void main() {
  List<PlannedReminder> plan(
    List<ScheduledMedicine> meds,
    DateTime now, {
    Set<String> taken = const {},
  }) => ReminderPlanner.plan(
    medicines: meds,
    taken: (d, s) => taken.contains('${d.day}/${s.name}'),
    now: now,
    strings: en,
  );

  test('two per slot: at the time, and thirty minutes later', () {
    final p = plan([
      med('TELMA 40', const Sig(slots: [m])),
    ], at(26, 6));
    expect(p.map((r) => r.at), [at(26, 8), at(26, 8, 30)]);
    expect(p.map((r) => r.nudge), [false, true]);
    expect(p.first.body, 'TELMA 40');
  });

  test('ids come from the slot, so a re-sync replaces, never duplicates', () {
    final a = plan([
      med('A', const Sig(slots: [m, n])),
    ], at(26, 6));
    final b = plan([
      med('A', const Sig(slots: [m, n])),
    ], at(26, 6));
    expect(a.map((r) => r.id), b.map((r) => r.id));
    expect(a.map((r) => r.id).toSet(), hasLength(4));
    expect(ReminderPlanner.idFor(n, nudge: true), 7);
  });

  test('a taken slot never rings; the next one is tomorrow\'s', () {
    final p = plan(
      [
        med('A', const Sig(slots: [m])),
      ],
      at(26, 7),
      taken: {'26/morning'},
    );
    expect(p.map((r) => r.at), [at(27, 8), at(27, 8, 30)]);
  });

  test('between the two alarms, only the nudge is left', () {
    final p = plan([
      med('A', const Sig(slots: [m])),
    ], at(26, 8, 10));
    expect(p.first.at, at(26, 8, 30));
    expect(p.first.nudge, isTrue);
  });

  test('never for an SOS, a stopped medicine, or a finished course', () {
    expect(plan([med('DOLO', const Sig(sos: true))], at(26, 6)), isEmpty);
    expect(
      plan([
        med('OLD', const Sig(slots: [m]), active: false),
      ], at(26, 6)),
      isEmpty,
    );
    expect(
      plan([
        med('X', const Sig(slots: [m], durationDays: 3)),
      ], at(29, 10)),
      isEmpty,
    );
  });

  test('alternate days: tomorrow\'s alarm is skipped when not due', () {
    final p = plan([
      med('VIT D', const Sig(slots: [m], everyNDays: 2)),
    ], at(26, 10));
    // Due 26, 28, 30… after the 26th's alarms are past, nothing on the 27th.
    expect(p, isEmpty);
  });

  test('where reminders cannot run, the schedule says so', () {
    expect(reminderBanner(ReminderStatus.ready, en), isNull);
    expect(
      reminderBanner(ReminderStatus.unsupported, en),
      'Reminders only work in the Android app.',
    );
    expect(reminderBanner(ReminderStatus.denied, en), contains('turned off'));
  });

  test('the test runner has no alarm service, and says so', () async {
    expect(await DoseReminders().sync(const []), ReminderStatus.unsupported);
  });

  test('the test runner hands back no alarms, and cannot ring', () async {
    final r = DoseReminders();
    expect(identical(r, DoseReminders()), isTrue, reason: 'one per app');
    expect(await r.launchAlarm(), isNull);
    expect(await r.alarms.isEmpty, isTrue);
    expect(
      await r.ringSoon(
        AlarmPayload(slot: m, date: start),
        title: 't',
        body: 'b',
      ),
      isFalse,
    );
  });

  group('the alarm notification', () {
    final android = DoseAlarmNotification.details().android!;

    test('wakes the screen, as an alarm', () {
      expect(android.fullScreenIntent, isTrue);
      expect(android.category, AndroidNotificationCategory.alarm);
      expect(android.importance, Importance.max);
      expect(android.priority, Priority.max);
    });

    test('rings on the alarm stream, and vibrates', () {
      expect(android.playSound, isTrue);
      expect(android.audioAttributesUsage, AudioAttributesUsage.alarm);
      expect(android.enableVibration, isTrue);
      expect(android.vibrationPattern, isNotEmpty);
    });

    test('on its own channel, not the quiet old one', () {
      expect(android.channelId, DoseAlarmNotification.channelId);
      expect(
        DoseAlarmNotification.channelId,
        isNot(DoseAlarmNotification.oldChannelId),
      );
    });
  });
}
