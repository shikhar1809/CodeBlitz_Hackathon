import '../core/l10n/app_strings.dart';
import '../core/plain_language.dart';
import 'dose_alarm.dart';
import 'dose_clock.dart';
import 'schedule_engine.dart';
import 'scheduled_medicine.dart';
import 'sig.dart';

/// One alarm to hand to the phone.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.slot,
    required this.nudge,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final DoseSlot slot;

  /// The second of the two: thirty minutes after the first.
  final bool nudge;
  final DateTime at;
  final String title;
  final String body;

  /// Which slot on which day: what the alarm screen opens for when the
  /// notification is tapped, or wakes the phone.
  String get payload => AlarmPayload(slot: slot, date: at).encode();
}

/// Which alarms should exist right now. Pure, and plugin-free, so all of it is
/// tested on a laptop; only handing the result to the OS is platform code.
///
/// Two notifications per due slot, then silence. A third alarm is how a family
/// learns to swipe the app away. By +60 the slot counts as missed, and it is
/// the caregiver who is told: the escalation moves to a different person
/// rather than getting louder.
abstract final class ReminderPlanner {
  /// Derived from the slot, never random, so a re-sync replaces an alarm
  /// instead of adding a second one.
  static int idFor(DoseSlot slot, {required bool nudge}) =>
      slot.index * 2 + (nudge ? 1 : 0);

  static List<PlannedReminder> plan({
    required Iterable<ScheduledMedicine> medicines,
    required bool Function(DateTime date, DoseSlot slot) taken,
    required DateTime now,
    required AppStrings strings,
  }) {
    final out = <PlannedReminder>[];
    for (final slot in DoseSlot.values) {
      // The next occurrence of this slot that still needs a reminder: today's
      // if its first alarm is still ahead and it is not taken, else
      // tomorrow's. Never for SOS, a finished course, a stopped medicine, or
      // a slot already taken — ScheduleEngine already leaves those out.
      for (final day in [now, now.add(const Duration(days: 1))]) {
        final due = ScheduleEngine.dueOn(medicines, day)[slot];
        if (due == null || due.isEmpty) continue;
        if (taken(day, slot)) continue;
        final first = DoseClock.dueAt(day, slot);
        final second = first.add(DoseClock.remindAgainAfter);
        if (!second.isAfter(now)) continue; // this one is past; try tomorrow

        final names = due.map((m) => m.name).join(', ');
        final slotName = PlainLanguage.slot(slot, strings);
        if (first.isAfter(now)) {
          out.add(
            PlannedReminder(
              id: idFor(slot, nudge: false),
              slot: slot,
              nudge: false,
              at: first,
              title: '$slotName · ${strings.medicineSchedule}',
              body: names,
            ),
          );
        }
        out.add(
          PlannedReminder(
            id: idFor(slot, nudge: true),
            slot: slot,
            nudge: true,
            at: second,
            title: '$slotName · ${strings.statusNotYet}',
            body: '${strings.tickAsYouGo} $names',
          ),
        );
        break;
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
