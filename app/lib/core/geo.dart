import 'dart:math';

class LatLon {
  final double lat;
  final double lon;
  const LatLon(this.lat, this.lon);
  @override
  String toString() => '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}';
}

const _earthR = 6371000.0;
double _rad(double d) => d * pi / 180;

/// Great-circle distance in metres.
double haversine(LatLon a, LatLon b) {
  final dLat = _rad(b.lat - a.lat), dLon = _rad(b.lon - a.lon);
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(a.lat)) * cos(_rad(b.lat)) * sin(dLon / 2) * sin(dLon / 2);
  return 2 * _earthR * asin(sqrt(h));
}

/// Distance in metres from [p] to segment [a]-[b] (local flat projection).
double distanceToSegment(LatLon p, LatLon a, LatLon b) {
  final k = cos(_rad(p.lat)) * _earthR;
  double x(LatLon q) => _rad(q.lon) * k;
  double y(LatLon q) => _rad(q.lat) * _earthR;
  final ax = x(a), ay = y(a), bx = x(b), by = y(b), px = x(p), py = y(p);
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}

/// Distance in metres from [p] to the nearest point of a polyline.
double distanceToRoute(LatLon p, List<LatLon> route) {
  if (route.isEmpty) return double.infinity;
  if (route.length == 1) return haversine(p, route.first);
  var best = double.infinity;
  for (var i = 0; i < route.length - 1; i++) {
    best = min(best, distanceToSegment(p, route[i], route[i + 1]));
  }
  return best;
}

double routeLength(List<LatLon> route) {
  var d = 0.0;
  for (var i = 0; i < route.length - 1; i++) {
    d += haversine(route[i], route[i + 1]);
  }
  return d;
}
