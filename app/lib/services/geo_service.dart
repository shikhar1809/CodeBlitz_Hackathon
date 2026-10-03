import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/geo.dart';

class Place {
  final String name;
  final LatLon at;
  const Place(this.name, this.at);
}

class RoutePlan {
  final List<LatLon> points;
  final Duration eta;
  final bool estimated;
  const RoutePlan(this.points, this.eta, {this.estimated = false});
}

/// Nominatim search and FOSSGIS OSRM routing; straight line when offline.
class GeoService {
  static const _ua = {'User-Agent': 'Winger/1.0 (hackathon demo)'};

  Future<List<Place>> search(String q, {LatLon? near}) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'json',
        'limit': '5',
        'countrycodes': 'in',
        if (near != null) 'viewbox': '${near.lon - .2},${near.lat + .2},${near.lon + .2},${near.lat - .2}',
      });
      final r = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 8));
      final list = jsonDecode(r.body) as List;
      return [
        for (final p in list)
          Place((p['display_name'] as String).split(',').take(2).join(','),
              LatLon(double.parse(p['lat']), double.parse(p['lon'])))
      ];
    } catch (_) {
      return [];
    }
  }

  Future<RoutePlan> route(LatLon from, LatLon to, {bool walk = true}) async {
    final profile = walk ? 'routed-foot' : 'routed-car';
    try {
      final uri = Uri.parse('https://routing.openstreetmap.de/$profile/route/v1/driving/'
          '${from.lon},${from.lat};${to.lon},${to.lat}?overview=full&geometries=geojson');
      final r = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 10));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final route = (j['routes'] as List).first as Map<String, dynamic>;
      final coords = (route['geometry'] as Map)['coordinates'] as List;
      return RoutePlan(
        [for (final c in coords) LatLon((c[1] as num).toDouble(), (c[0] as num).toDouble())],
        Duration(seconds: (route['duration'] as num).round()),
      );
    } catch (_) {
      final d = haversine(from, to);
      final speed = walk ? 1.3 : 6.0; // m/s
      return RoutePlan([from, to], Duration(seconds: (d * 1.3 / speed).round()), estimated: true);
    }
  }
}
