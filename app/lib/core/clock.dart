/// Injectable time. The demo clock can skip ahead; tests use a fake one, so
/// "+60 min" is tested in milliseconds.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

/// Real time plus an offset the demo panel can push forward.
class DemoClock implements Clock {
  Duration offset = Duration.zero;
  @override
  DateTime now() => DateTime.now().add(offset);
  void skip(Duration d) => offset += d;

  /// Moves the clock so that [t] is now (only ever forwards).
  void jumpTo(DateTime t) {
    final gap = t.difference(now());
    if (!gap.isNegative) offset += gap;
  }

  void reset() => offset = Duration.zero;
}

class FakeClock implements Clock {
  DateTime _t;
  FakeClock(this._t);
  @override
  DateTime now() => _t;
  void advance(Duration d) => _t = _t.add(d);
  void set(DateTime t) => _t = t;
}
