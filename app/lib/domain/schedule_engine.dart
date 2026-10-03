import 'scheduled_medicine.dart';
import 'sig.dart';

/// Verified medicines to "what do I take today".
///
/// Pure: given the medicines and a date, the answer is always the same, and
/// no clock is read inside.
abstract final class ScheduleEngine {
  /// Is [m] due at all on [date]?
  static bool isDueOn(ScheduledMedicine m, DateTime date) {
    if (!m.active) return false;
    final day = dayOf(date);
    final start = dayOf(m.startDate);
    if (day.isBefore(start)) return false;
    final elapsed = day.difference(start).inDays;

    // As needed: never on the schedule, never an alarm.
    if (m.sig.sos) return false;
    // Once, on the day it was approved.
    if (m.sig.stat) return elapsed == 0;

    final duration = m.sig.durationDays;
    if (duration != null && elapsed >= duration) return false;
    final every = m.sig.everyNDays;
    if (every != null && every > 1 && elapsed % every != 0) return false;
    return m.sig.slots.isNotEmpty;
  }

  /// The slots [m] occupies on a day it is due.
  static List<DoseSlot> slotsOf(ScheduledMedicine m) {
    if (m.sig.stat && m.sig.slots.isEmpty) return const [DoseSlot.morning];
    return m.sig.slots;
  }

  /// Each slot on [date] with the medicines due in it. Slots with nothing due
  /// are left out: an empty "Afternoon" is noise for someone taking two
  /// tablets a day.
  static Map<DoseSlot, List<ScheduledMedicine>> dueOn(
    Iterable<ScheduledMedicine> medicines,
    DateTime date,
  ) {
    final out = <DoseSlot, List<ScheduledMedicine>>{};
    for (final slot in DoseSlot.values) {
      final due = [
        for (final m in medicines)
          if (isDueOn(m, date) && slotsOf(m).contains(slot)) m,
      ];
      if (due.isNotEmpty) out[slot] = due;
    }
    return out;
  }

  /// Medicines taken only when needed.
  static List<ScheduledMedicine> whenNeeded(
    Iterable<ScheduledMedicine> medicines,
    DateTime date,
  ) => [
    for (final m in medicines)
      if (m.active && m.sig.sos && !_finished(m, date)) m,
  ];

  /// Days left in a course, counting [date]. Null for an open-ended medicine.
  static int? daysLeft(ScheduledMedicine m, DateTime date) {
    final d = m.sig.durationDays;
    if (d == null) return null;
    final elapsed = dayOf(date).difference(dayOf(m.startDate)).inDays;
    return (d - elapsed).clamp(0, d);
  }

  static bool _finished(ScheduledMedicine m, DateTime date) {
    final left = daysLeft(m, date);
    return left != null && left <= 0;
  }

  /// Whether anything at all is due on [date].
  static bool anythingDue(
    Iterable<ScheduledMedicine> medicines,
    DateTime date,
  ) => medicines.any((m) => isDueOn(m, date));
}
