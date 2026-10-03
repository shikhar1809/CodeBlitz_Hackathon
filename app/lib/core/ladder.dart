/// Escalation ladder: idle -> nudge -> ask -> guardian -> 112 countdown -> 112.
///
/// Pure Dart. The app calls [Ladder.tick] once a second; each rung has a time
/// window after which it climbs to the next one unless she answers.
enum Rung { idle, nudge, ask, guardian, countdown112, called112 }

class LadderWindows {
  final Duration nudge;
  final Duration ask;
  final Duration guardian;
  final Duration countdown112;
  const LadderWindows({
    this.nudge = const Duration(seconds: 10),
    this.ask = const Duration(seconds: 30),
    this.guardian = const Duration(seconds: 60),
    this.countdown112 = const Duration(seconds: 15),
  });

  Duration? of(Rung r) => switch (r) {
        Rung.nudge => nudge,
        Rung.ask => ask,
        Rung.guardian => guardian,
        Rung.countdown112 => countdown112,
        _ => null,
      };
}

typedef RungListener = void Function(Rung from, Rung to);

class Ladder {
  final LadderWindows windows;
  RungListener? onClimb;
  Rung _rung = Rung.idle;
  DateTime? _since;

  Ladder({this.windows = const LadderWindows(), this.onClimb});

  Rung get rung => _rung;
  bool get isAlerting => _rung.index >= Rung.guardian.index;

  /// Seconds left in the current rung, or null when it does not time out.
  int? remaining(DateTime now) {
    final w = windows.of(_rung);
    if (w == null || _since == null) return null;
    final left = w - now.difference(_since!);
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  void _go(Rung to, DateTime now) {
    if (to == _rung) return;
    final from = _rung;
    _rung = to;
    _since = now;
    onClimb?.call(from, to);
  }

  /// Something looks off: climb to [to] (never moves down).
  void raise(DateTime now, {Rung to = Rung.nudge}) {
    if (to.index > _rung.index) _go(to, now);
  }

  /// "Help me": straight to guardians.
  void help(DateTime now) => raise(now, to: Rung.guardian);

  /// SOS: skip everything, call 112.
  void sos(DateTime now) => raise(now, to: Rung.called112);

  /// She answered with her PIN.
  void safe(DateTime now) => _go(Rung.idle, now);

  void tick(DateTime now) {
    final w = windows.of(_rung);
    if (w == null || _since == null) return;
    if (now.difference(_since!) >= w) {
      _go(Rung.values[_rung.index + 1], now);
    }
  }
}
