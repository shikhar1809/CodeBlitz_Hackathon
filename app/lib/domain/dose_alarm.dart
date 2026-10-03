import 'dose_clock.dart';
import 'schedule_engine.dart';
import 'scheduled_medicine.dart';
import 'sig.dart';

/// What a dose alarm carries through the notification: which slot, on which
/// day. Nothing else — the medicines are looked up again when it opens, so a
/// medicine stopped after the alarm was set is not shown.
///
/// Encoded as `dose|morning|2026-09-26`, with `|demo` on the end for the
/// demo button. Plain text, so a payload read in a bug report explains itself.
class AlarmPayload {
  AlarmPayload({required this.slot, required DateTime date, this.demo = false})
    : date = dayOf(date);

  final DoseSlot slot;

  /// Midnight of the day the slot belongs to.
  final DateTime date;

  /// Fired from the demo button: shown, but never written to the log.
  final bool demo;

  static const _tag = 'dose';

  String encode() => [
    _tag,
    slot.name,
    '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    if (demo) 'demo',
  ].join('|');

  /// Null for anything that is not a dose alarm — another notification, an
  /// old payload, or garbage. An alarm screen for the wrong slot is worse than
  /// none.
  static AlarmPayload? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length < 3 || parts.length > 4 || parts[0] != _tag) return null;
    final slot = DoseSlot.values.asNameMap()[parts[1]];
    final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(parts[2]);
    if (slot == null || ymd == null) return null;
    final y = int.parse(ymd[1]!),
        m = int.parse(ymd[2]!),
        d = int.parse(ymd[3]!);
    final date = DateTime(y, m, d);
    // DateTime quietly rolls 2026-02-31 into March; a payload that does that
    // was not written by us.
    if (date.year != y || date.month != m || date.day != d) return null;
    if (parts.length == 4 && parts[3] != 'demo') return null;
    return AlarmPayload(slot: slot, date: date, demo: parts.length == 4);
  }

  @override
  bool operator ==(Object other) =>
      other is AlarmPayload &&
      other.slot == slot &&
      other.date == date &&
      other.demo == demo;

  @override
  int get hashCode => Object.hash(slot, date, demo);

  @override
  String toString() => 'AlarmPayload(${encode()})';
}

/// The decisions behind the alarm screen. Pure, like the planner.
abstract final class DoseAlarm {
  /// The medicine shown when the schedule has nothing to ring for. Its name
  /// says what it is, in English letters, like every medicine name.
  static final demoMedicine = ScheduledMedicine(
    id: 'demo-medicine',
    name: 'DEMO MEDICINE 500',
    sig: const Sig(slots: [DoseSlot.morning], food: FoodTiming.after),
    startDate: DateTime(2026),
  );

  /// What the alarm for [payload] should show: the medicines due in that
  /// slot on that day, as the schedule sees them now.
  static List<ScheduledMedicine> medicinesFor(
    AlarmPayload payload,
    Iterable<ScheduledMedicine> medicines,
  ) => ScheduleEngine.dueOn(medicines, payload.date)[payload.slot] ?? const [];

  /// Whether a tapped or launching alarm should open the screen at all. A
  /// slot already taken — confirmed on another screen while the notification
  /// sat in the shade — must not ask again.
  static bool shouldOpen({
    required AlarmPayload payload,
    required List<ScheduledMedicine> due,
    required bool alreadyTaken,
  }) => payload.demo || (due.isNotEmpty && !alreadyTaken);

  /// The slot the demo button rings for: today's slot nearest to [now] that
  /// has something due, preferring one not yet taken. With nothing due today,
  /// simply the slot nearest to [now] — [demoMedicines] then shows the demo
  /// medicine in it.
  static AlarmPayload demoTarget({
    required Iterable<ScheduledMedicine> medicines,
    required DateTime now,
    required bool Function(DateTime date, DoseSlot slot) taken,
  }) {
    int distance(DoseSlot s) =>
        DoseClock.dueAt(now, s).difference(now).inMinutes.abs();
    final due = ScheduleEngine.dueOn(medicines, now).keys.toList();
    final open = due.where((s) => !taken(now, s)).toList();
    final pool = open.isNotEmpty
        ? open
        : due.isNotEmpty
        ? due
        : DoseSlot.values.toList();
    pool.sort((a, b) => distance(a).compareTo(distance(b)));
    return AlarmPayload(slot: pool.first, date: now, demo: true);
  }

  /// What a demo alarm shows: the real medicines of that slot, or — when the
  /// schedule has none — the clearly named demo medicine.
  static List<ScheduledMedicine> demoMedicines(
    AlarmPayload payload,
    Iterable<ScheduledMedicine> medicines,
  ) {
    final due = medicinesFor(payload, medicines);
    return due.isNotEmpty ? due : [demoMedicine];
  }
}
