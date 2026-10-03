import 'presets.dart';

/// A ladder of steps from a preset. Not started = idle (index -1).
///
/// Each step's `after` is an offset from the start of the watch. Jumping to a
/// step (for "Help me") restarts the timing from there, so the gap to each
/// following step is always `next.after - current.after`.
class StepLadder {
  final List<LadderStep> steps;
  void Function(int from, int to)? onStep;
  int _i = -1;
  DateTime? _since;

  StepLadder(this.steps, {this.onStep});

  int get index => _i;
  bool get started => _i >= 0;
  bool get finished => _i == steps.length - 1;
  LadderStep? get current => _i < 0 ? null : steps[_i];

  /// Time from entering the current step to the next one, or null at the end.
  Duration? get gap => _i < 0 || finished ? null : steps[_i + 1].after - steps[_i].after;

  /// When the next step fires, or null.
  DateTime? nextAt() => gap == null || _since == null ? null : _since!.add(gap!);

  int? remaining(DateTime now) {
    final at = nextAt();
    if (at == null) return null;
    final left = at.difference(now);
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  void _go(int to, DateTime at) {
    if (to == _i) return;
    final from = _i;
    _i = to;
    _since = at;
    onStep?.call(from, to);
  }

  /// Climb to step [to] (never moves down). [at] defaults to [now]; a
  /// scheduled watch starts at its due time even if noticed late.
  void raise(DateTime now, {int to = 0, DateTime? at}) {
    if (to > _i && to < steps.length) _go(to, at ?? now);
  }

  void jumpTo(String id, DateTime now) {
    final to = steps.indexWhere((s) => s.id == id);
    if (to >= 0) raise(now, to: to);
  }

  /// Answered: back to idle.
  void reset(DateTime now) => _go(-1, now);

  /// Climbs as many steps as are due (catches up after the app slept).
  void tick(DateTime now) {
    while (true) {
      final at = nextAt();
      if (at == null || now.isBefore(at)) return;
      _go(_i + 1, at);
    }
  }
}

/// Women Companion rungs: idle -> nudge -> ask -> guardian -> 112 countdown -> 112.
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

  /// The same rungs as preset steps (offsets from the nudge).
  List<LadderStep> toSteps() {
    var t = Duration.zero;
    LadderStep step(String id, List<String> acts, Duration window) {
      final s = LadderStep(id, t, [for (final a in acts) ActionSpec.parse(a)]);
      t += window;
      return s;
    }

    return [
      step('nudge', ['vibrate'], nudge),
      step('ask', ['checkin', 'speak'], ask),
      step('guardian', ['message_contacts:guardian', 'call_contact:guardian'], guardian),
      step('countdown112', ['notify'], countdown112),
      step('called112', ['emergency'], Duration.zero),
    ];
  }
}

typedef RungListener = void Function(Rung from, Rung to);

/// The Women Companion ladder, run by [StepLadder].
class Ladder {
  final LadderWindows windows;
  final StepLadder _steps;
  RungListener? onClimb;

  Ladder({this.windows = const LadderWindows(), this.onClimb})
      : _steps = StepLadder(windows.toSteps()) {
    _steps.onStep = (from, to) => onClimb?.call(Rung.values[from + 1], Rung.values[to + 1]);
  }

  Rung get rung => Rung.values[_steps.index + 1];
  bool get isAlerting => rung.index >= Rung.guardian.index;

  int? remaining(DateTime now) => _steps.remaining(now);

  /// Something looks off: climb to [to] (never moves down).
  void raise(DateTime now, {Rung to = Rung.nudge}) => _steps.raise(now, to: to.index - 1);

  /// "Help me": straight to guardians.
  void help(DateTime now) => raise(now, to: Rung.guardian);

  /// SOS: skip everything, call 112.
  void sos(DateTime now) => raise(now, to: Rung.called112);

  /// She answered with her PIN.
  void safe(DateTime now) => _steps.reset(now);

  void tick(DateTime now) => _steps.tick(now);
}
