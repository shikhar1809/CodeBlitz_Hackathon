import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/dose_clock.dart';
import '../../domain/schedule_engine.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';

enum DoseStatus { taken, missed, dueNow, notYet }

/// How one day looks on the month calendar.
enum DayMark { taken, missed, pending, nothingDue }

/// One confirmed slot: "सब ले ली", pressed.
class DoseLog {
  const DoseLog({
    required this.date,
    required this.slot,
    required this.confirmedAt,
    required this.taken,
  });

  /// Midnight of the day the slot belongs to.
  final DateTime date;
  final DoseSlot slot;
  final DateTime confirmedAt;

  /// The medicine ids ticked.
  final List<String> taken;

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'slot': slot.name,
    'status': 'taken',
    'confirmedAt': confirmedAt.toIso8601String(),
    'taken': taken,
  };

  factory DoseLog.fromJson(Map<String, Object?> j) => DoseLog(
    date: DateTime.parse(j['date']! as String),
    slot: DoseSlot.values.byName(j['slot']! as String),
    confirmedAt: DateTime.parse(j['confirmedAt']! as String),
    taken: [for (final t in j['taken'] as List? ?? const []) t as String],
  );
}

/// What was taken, and — derived, never written — what was missed.
///
/// Nothing is running at 09:01 to record a miss, so a miss is computed
/// whenever a status is asked for. Every comparison is day to day: comparing a
/// timestamped date against midnight once made every same-day slot "pending",
/// and missed doses never appeared on the schedule at all.
class DoseLogStore {
  DoseLogStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'dose_logs';

  /// Enough for the calendar and a little more.
  static const keepDays = 120;

  static Future<DoseLogStore> load() async =>
      DoseLogStore(await SharedPreferences.getInstance());

  List<DoseLog> all() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          DoseLog.fromJson((j as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      return [];
    }
  }

  DoseLog? logFor(DateTime date, DoseSlot slot) {
    final day = dayOf(date);
    for (final l in all()) {
      if (l.slot == slot && dayOf(l.date) == day) return l;
    }
    return null;
  }

  Future<void> logTaken({
    required DateTime date,
    required DoseSlot slot,
    required List<String> medicineIds,
    required DateTime at,
  }) async {
    final day = dayOf(date);
    final cutoff = dayOf(at).subtract(const Duration(days: keepDays));
    final logs = [
      for (final l in all())
        if (!(l.slot == slot && dayOf(l.date) == day) &&
            !l.date.isBefore(cutoff))
          l,
      DoseLog(date: day, slot: slot, confirmedAt: at, taken: medicineIds),
    ];
    await _prefs.setString(
      _key,
      jsonEncode([for (final l in logs) l.toJson()]),
    );
  }

  DoseStatus statusOf(DateTime now, DateTime date, DoseSlot slot) {
    if (logFor(date, slot) != null) return DoseStatus.taken;
    final today = dayOf(now), day = dayOf(date);
    if (day.isBefore(today)) return DoseStatus.missed;
    if (day.isAfter(today)) return DoseStatus.notYet;
    if (now.isBefore(DoseClock.dueAt(day, slot))) return DoseStatus.notYet;
    if (now.isBefore(DoseClock.missedAt(day, slot))) return DoseStatus.dueNow;
    return DoseStatus.missed;
  }

  /// Slots on [date] that are missed as of [now].
  List<DoseSlot> missedOn(
    DateTime now,
    DateTime date,
    Iterable<ScheduledMedicine> medicines,
  ) => [
    for (final slot in ScheduleEngine.dueOn(medicines, date).keys)
      if (statusOf(now, date, slot) == DoseStatus.missed) slot,
  ];

  DayMark markFor(
    DateTime now,
    DateTime date,
    Iterable<ScheduledMedicine> medicines,
  ) {
    final slots = ScheduleEngine.dueOn(medicines, date).keys.toList();
    if (slots.isEmpty) return DayMark.nothingDue;
    final statuses = [for (final s in slots) statusOf(now, date, s)];
    if (statuses.contains(DoseStatus.missed)) return DayMark.missed;
    if (statuses.every((s) => s == DoseStatus.taken)) return DayMark.taken;
    return DayMark.pending;
  }
}
