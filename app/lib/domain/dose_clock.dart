import 'scheduled_medicine.dart';
import 'sig.dart';

/// Clock times behind the four slots. They drive reminders only: the patient
/// still sees सुबह / दोपहर / रात, never "08:00".
///
///     08:00 ─────── 08:30 ─────── 09:00 ──────────▶
///     due           nudge         missed
///     (alarm 1)     (alarm 2)     (the caregiver is told;
///                                  the patient is not alarmed again)
///
/// Forty minutes late is late, not missed. Crying wolf is how a family learns
/// to ignore alerts.
abstract final class DoseClock {
  static const nominalHour = {
    DoseSlot.morning: 8,
    DoseSlot.afternoon: 14,
    DoseSlot.evening: 18,
    DoseSlot.night: 21,
  };

  static const remindAgainAfter = Duration(minutes: 30);
  static const missedAfter = Duration(minutes: 60);

  static DateTime dueAt(DateTime date, DoseSlot slot) {
    final d = dayOf(date);
    return DateTime(d.year, d.month, d.day, nominalHour[slot]!);
  }

  static DateTime missedAt(DateTime date, DoseSlot slot) =>
      dueAt(date, slot).add(missedAfter);
}
