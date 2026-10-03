import 'ladder.dart';
import 'presets.dart';
import 'schedule.dart';

/// A medicine a human entered or approved. Winger never invents a dose.
class Medicine {
  final String id;
  final String name;
  final String strength;
  final String note;
  final Schedule schedule;
  const Medicine(
      {required this.id, required this.name, this.strength = '', this.note = '', required this.schedule});

  String get label => strength.isEmpty ? name : '$name $strength';

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'strength': strength, 'note': note, 'schedule': schedule.toJson()};
  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'] as String,
        name: j['name'] as String,
        strength: j['strength'] as String? ?? '',
        note: j['note'] as String? ?? '',
        schedule: Schedule.fromJson(j['schedule'] as Map<String, dynamic>),
      );
}

enum DoseStatus { upcoming, due, taken, partial, missed }

/// One dose time: every medicine due at that moment, with its own ladder.
class Occurrence {
  final String id;
  final DateTime due;
  final List<String> medIds;
  final StepLadder ladder;
  final Set<String> taken = {};
  DateTime? snoozedUntil;
  bool contacted = false;
  int snoozes = 0;

  Occurrence(this.id, this.due, this.medIds, List<LadderStep> steps) : ladder = StepLadder(steps);

  bool get allTaken => medIds.every(taken.contains);

  DoseStatus status(DateTime now) {
    if (allTaken) return DoseStatus.taken;
    if (now.isBefore(due)) return DoseStatus.upcoming;
    if (contacted) return taken.isEmpty ? DoseStatus.missed : DoseStatus.partial;
    return taken.isEmpty ? DoseStatus.due : DoseStatus.partial;
  }

  /// Wants her attention now (a card on screen / a notification).
  bool needsAnswer(DateTime now) =>
      !allTaken && !now.isBefore(due) && (snoozedUntil == null || !now.isBefore(snoozedUntil!));
}

enum DoseEventKind { reminded, nudged, taken, partial, snoozed, contacted, held }

/// Append-only adherence log: nothing is edited, so syncing can never conflict.
class DoseEvent {
  final DateTime at;
  final String occurrenceId;
  final DoseEventKind kind;
  final String detail;
  const DoseEvent(this.at, this.occurrenceId, this.kind, [this.detail = '']);

  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'o': occurrenceId, 'k': kind.name, 'd': detail};
  factory DoseEvent.fromJson(Map<String, dynamic> j) => DoseEvent(
      DateTime.parse(j['at'] as String), j['o'] as String, DoseEventKind.values.byName(j['k'] as String),
      j['d'] as String? ?? '');
}

typedef StepHandler = void Function(Occurrence o, LadderStep step);

/// Medicines, today's dose occurrences and the adherence log.
class DoseBook {
  final List<LadderStep> steps;
  final List<Medicine> medicines;
  final List<DoseEvent> log;
  final Map<String, Occurrence> _occ = {};
  StepHandler? onStep;

  static const snoozeFor = Duration(minutes: 10);
  static const maxSnoozes = 2;

  DoseBook(this.steps, {List<Medicine>? medicines, List<DoseEvent>? log})
      : medicines = medicines ?? [],
        log = log ?? [];

  Medicine? med(String id) => medicines.where((m) => m.id == id).firstOrNull;

  static String occurrenceId(DateTime due) => 'dose-${due.toIso8601String()}';

  /// Today's occurrences, in time order (creates any that are missing).
  List<Occurrence> today(DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    _ensure(start, start.add(const Duration(days: 1)));
    return _occ.values.where((o) => !o.due.isBefore(start) && o.due.isBefore(start.add(const Duration(days: 1)))).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
  }

  /// The next dose time after [now], if any.
  DateTime? nextDue(DateTime now) {
    DateTime? best;
    for (final m in medicines) {
      final n = m.schedule.next(now.add(const Duration(seconds: 1)));
      if (n != null && (best == null || n.isBefore(best))) best = n;
    }
    return best;
  }

  void _ensure(DateTime from, DateTime to) {
    final byTime = <DateTime, List<String>>{};
    for (final m in medicines) {
      for (final t in m.schedule.between(from, to)) {
        (byTime[t] ??= []).add(m.id);
      }
    }
    for (final e in byTime.entries) {
      final id = occurrenceId(e.key);
      final existing = _occ[id];
      if (existing == null) {
        final o = Occurrence(id, e.key, e.value, steps);
        // Rebuild from the log quietly (no actions fire for the past).
        for (final ev in log.where((x) => x.occurrenceId == id)) {
          if (ev.kind == DoseEventKind.taken) o.taken.addAll(ev.detail.split(',').where((s) => s.isNotEmpty));
          if (ev.kind == DoseEventKind.partial) o.taken.addAll(ev.detail.split(',').where((s) => s.isNotEmpty));
          if (ev.kind == DoseEventKind.contacted) o.contacted = true;
        }
        _occ[id] = o;
      } else {
        for (final m in e.value) {
          if (!existing.medIds.contains(m)) existing.medIds.add(m);
        }
      }
    }
  }

  /// Advances every due ladder. Steps that were already logged (after a
  /// restart) are replayed silently.
  void tick(DateTime now) {
    for (final o in today(now)) {
      if (o.allTaken || now.isBefore(o.due)) continue;
      final quietUpTo = _loggedSteps(o.id);
      o.ladder.onStep = (from, to) {
        if (to < 0) return;
        final step = steps[to];
        if (to < quietUpTo) return;
        if (step.has('message_contacts')) o.contacted = true;
        onStep?.call(o, step);
      };
      if (!o.ladder.started) o.ladder.raise(now, to: 0, at: o.due);
      o.ladder.tick(now);
    }
  }

  int _loggedSteps(String id) {
    var n = 0;
    for (final e in log.where((e) => e.occurrenceId == id)) {
      final i = switch (e.kind) {
        DoseEventKind.reminded => 1,
        DoseEventKind.nudged => 2,
        DoseEventKind.contacted || DoseEventKind.held => 3,
        _ => 0,
      };
      if (i > n) n = i;
    }
    return n;
  }

  void record(DoseEvent e) => log.add(e);

  /// Taken: all of them, or just [ids].
  void markTaken(Occurrence o, DateTime now, {Iterable<String>? ids}) {
    final got = (ids ?? o.medIds).where(o.medIds.contains).toSet();
    if (got.isEmpty) return;
    o.taken.addAll(got);
    record(DoseEvent(now, o.id, o.allTaken ? DoseEventKind.taken : DoseEventKind.partial, got.join(',')));
  }

  /// Snooze hides the card for 10 min. The ladder keeps its clock, so the
  /// family is still told on time: snoozing never cancels escalation.
  bool snooze(Occurrence o, DateTime now) {
    if (o.snoozes >= maxSnoozes) return false;
    o.snoozes++;
    o.snoozedUntil = now.add(snoozeFor);
    record(DoseEvent(now, o.id, DoseEventKind.snoozed));
    return true;
  }

  /// Share of today's past doses fully taken (null when none are due yet).
  double? adherence(DateTime now) {
    final past = today(now).where((o) => !now.isBefore(o.due)).toList();
    if (past.isEmpty) return null;
    return past.where((o) => o.allTaken).length / past.length;
  }
}
