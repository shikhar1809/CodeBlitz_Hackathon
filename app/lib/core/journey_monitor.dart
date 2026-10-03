import 'geo.dart';

enum JourneyTrouble { offRoute, stopped, late }

/// Watches a journey: stays quiet unless she leaves the corridor, stops too
/// long, or runs well past the ETA.
class JourneyMonitor {
  final List<LatLon> route;
  final Duration eta;
  final double corridorMetres;
  final Duration maxStop;
  final double lateFactor;
  final DateTime startedAt;

  LatLon? _last;
  DateTime? _stillSince;
  final Set<JourneyTrouble> _raised = {};

  JourneyMonitor({
    required this.route,
    required this.eta,
    required this.startedAt,
    this.corridorMetres = 150,
    this.maxStop = const Duration(minutes: 4),
    this.lateFactor = 1.5,
  });

  bool arrived(LatLon p) => route.isNotEmpty && haversine(p, route.last) < 60;

  /// Feed a position; returns new troubles (each reported once until cleared).
  List<JourneyTrouble> update(LatLon p, DateTime now) {
    final out = <JourneyTrouble>[];
    void flag(JourneyTrouble t, bool on) {
      if (on && _raised.add(t)) out.add(t);
      if (!on) _raised.remove(t);
    }

    flag(JourneyTrouble.offRoute, distanceToRoute(p, route) > corridorMetres);

    if (_last != null && haversine(_last!, p) < 15) {
      _stillSince ??= now;
    } else {
      _stillSince = null;
    }
    _last = p;
    flag(JourneyTrouble.stopped,
        _stillSince != null && now.difference(_stillSince!) >= maxStop);

    final allowed =
        Duration(milliseconds: (eta.inMilliseconds * lateFactor).round());
    flag(JourneyTrouble.late,
        now.difference(startedAt) > allowed && !arrived(p));
    return out;
  }
}
