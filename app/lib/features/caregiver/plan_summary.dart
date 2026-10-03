import '../../core/l10n/app_strings.dart';
import '../../core/plain_language.dart';
import '../../domain/schedule_engine.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../doses/dose_log_store.dart';

/// The plan, the day, and a one-line alert — as plain text.
///
/// Text arrives on any phone, reads without an app, forwards to a doctor, and
/// pastes into an SMS for a caregiver with no smartphone at all. Medicine
/// names stay in English letters in the Hindi message too: the person reading
/// it may be the one holding the strip, and the strip says TELMA.
abstract final class PlanSummary {
  static String plan({
    required String name,
    required Iterable<ScheduledMedicine> medicines,
    required DateTime today,
    required AppStrings s,
  }) {
    final lines = [
      for (final m in medicines)
        if (m.active && !_finished(m, today)) '• ${sentence(m, today, s)}',
    ];
    return [s.planHeader(name), '', ...lines, '', s.messageFooter].join('\n');
  }

  static String status({
    required String name,
    required Iterable<ScheduledMedicine> medicines,
    required DoseLogStore logs,
    required DateTime now,
    required AppStrings s,
  }) {
    final due = ScheduleEngine.dueOn(medicines, now);
    final lines = [
      for (final e in due.entries)
        '${PlainLanguage.slot(e.key, s)}: '
            '${_status(logs.statusOf(now, now, e.key), s)} — '
            '${e.value.map((m) => m.name).join(', ')}',
    ];
    return [s.statusHeader(name), date(now), '', ...lines].join('\n');
  }

  /// "Ramesh: Morning medicines were missed." Names the day when it is not
  /// today, because missed doses are found when the app opens, not at the
  /// minute they happen — the message must not imply "right now".
  static String alert({
    required String name,
    required DoseSlot slot,
    required bool taken,
    required DateTime date,
    required DateTime now,
    required AppStrings s,
  }) {
    final slotName = PlainLanguage.slot(slot, s);
    if (taken) return s.slotTaken(name, slotName);
    if (dayOf(date) != dayOf(now)) {
      return s.slotMissedOn(name, slotName, date_(date));
    }
    return s.slotMissed(name, slotName);
  }

  /// "Take TELMA 40 in the morning, after food. The doctor said this is for
  /// "BP"."
  static String sentence(ScheduledMedicine m, DateTime today, AppStrings s) {
    final sig = m.sig;
    if (sig.sos) return _withPurpose(s.takeWhenNeeded(m.name), m, s);
    if (sig.stat) return _withPurpose(s.takeOnceNow(m.name), m, s);
    if (sig.slots.isEmpty) return _withPurpose(s.takeWhenUnknown(m.name), m, s);

    final parts = <String>[_slots(sig.slots, s)];
    if (sig.food == FoodTiming.after) parts.add(s.afterFood);
    if (sig.food == FoodTiming.before) parts.add(s.beforeFood);
    if (sig.everyNDays != null && sig.everyNDays! > 1) {
      parts.add(s.everyNDays(sig.everyNDays!));
    }
    final left = ScheduleEngine.daysLeft(m, today);
    if (left != null) parts.add(s.forMoreDays(left));
    final core = '${s.take(m.name)} ${parts.join(', ')}.';
    return _withPurpose(core, m, s);
  }

  static String _withPurpose(String line, ScheduledMedicine m, AppStrings s) =>
      m.purpose == null ? line : '$line ${s.doctorSaidFor(m.purpose!)}';

  static String _slots(List<DoseSlot> slots, AppStrings s) {
    final words = [
      for (final slot in slots)
        switch (slot) {
          DoseSlot.morning => s.inTheMorning,
          DoseSlot.afternoon => s.inTheAfternoon,
          DoseSlot.evening => s.inTheEvening,
          DoseSlot.night => s.atNight,
        },
    ];
    if (words.length == 1) return words.single;
    return '${words.sublist(0, words.length - 1).join(', ')} ${s.and} '
        '${words.last}';
  }

  static String _status(DoseStatus st, AppStrings s) => switch (st) {
    DoseStatus.taken => s.statusTaken,
    DoseStatus.missed => s.statusMissed,
    DoseStatus.dueNow => s.statusDueNow,
    DoseStatus.notYet => s.statusNotYet,
  };

  static bool _finished(ScheduledMedicine m, DateTime today) {
    final left = ScheduleEngine.daysLeft(m, today);
    return left != null && left <= 0;
  }

  static String date(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  static String date_(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
