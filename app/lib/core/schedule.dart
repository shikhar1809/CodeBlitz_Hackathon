/// Dose and task schedules: times of day, on some days, until an end date.
/// Anything more complex ("every 8 h after food, tapering") stays a note a
/// human reads; Winger never invents a schedule.
class DayTime implements Comparable<DayTime> {
  final int hour;
  final int minute;
  const DayTime(this.hour, this.minute);

  factory DayTime.parse(String s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
    if (m == null) throw FormatException('bad time "$s"');
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) throw FormatException('bad time "$s"');
    return DayTime(h, min);
  }

  DateTime on(DateTime day) => DateTime(day.year, day.month, day.day, hour, minute);

  @override
  int compareTo(DayTime other) => (hour * 60 + minute).compareTo(other.hour * 60 + other.minute);

  @override
  bool operator ==(Object other) => other is DayTime && other.hour == hour && other.minute == minute;
  @override
  int get hashCode => hour * 60 + minute;

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get label {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
  }
}

class Schedule {
  final List<DayTime> times;

  /// 1 = Monday … 7 = Sunday. Empty = every day.
  final Set<int> days;
  final DateTime start;
  final DateTime? end;

  Schedule({required List<DayTime> times, this.days = const {}, required DateTime start, this.end})
      : times = ([...times]..sort()),
        start = DateTime(start.year, start.month, start.day);

  bool activeOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(start)) return false;
    if (end != null && d.isAfter(DateTime(end!.year, end!.month, end!.day))) return false;
    return days.isEmpty || days.contains(d.weekday);
  }

  /// Due times in [from, to).
  List<DateTime> between(DateTime from, DateTime to) {
    final out = <DateTime>[];
    var day = DateTime(from.year, from.month, from.day);
    while (day.isBefore(to)) {
      if (activeOn(day)) {
        for (final t in times) {
          final at = t.on(day);
          if (!at.isBefore(from) && at.isBefore(to)) out.add(at);
        }
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return out;
  }

  /// Next due time at or after [now], within a year.
  DateTime? next(DateTime now) {
    final l = between(now, now.add(const Duration(days: 366)));
    return l.isEmpty ? null : l.first;
  }

  Map<String, dynamic> toJson() => {
        'times': times.map((t) => '$t').toList(),
        'days': days.toList(),
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
      };

  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
        times: [for (final t in j['times'] as List) DayTime.parse(t as String)],
        days: {for (final d in (j['days'] as List? ?? [])) d as int},
        start: DateTime.parse(j['start'] as String),
        end: j['end'] == null ? null : DateTime.parse(j['end'] as String),
      );
}
