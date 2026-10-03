import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../config.dart';
import '../core/geo.dart';
import '../services/geo_service.dart';
import '../state/app_state.dart';
import 'session_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Set route: map, "Where to?", Walk / Ride, swipe to start.
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});
  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final _geo = GeoService();
  final _map = MapController();
  final _q = TextEditingController();
  LatLon _here = Demo.here;
  Place? _dest;
  RoutePlan? _plan;
  bool _walk = true;
  bool _busy = false;
  List<Place> _results = [];

  ll.LatLng _ll(LatLon p) => ll.LatLng(p.lat, p.lon);

  @override
  void initState() {
    super.initState();
    AppScope.read(context).location().then((p) {
      if (mounted) setState(() => _here = p);
    });
  }

  Future<void> _choose(Place p) async {
    setState(() {
      _dest = p;
      _results = [];
      _busy = true;
    });
    final plan = await _geo.route(_here, p.at, walk: _walk);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _busy = false;
    });
    _map.fitCamera(CameraFit.coordinates(
        coordinates: plan.points.map(_ll).toList(), padding: const EdgeInsets.fromLTRB(40, 140, 40, 260)));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _busy = true);
    final r = await _geo.search(q, near: _here);
    if (mounted) {
      setState(() {
        _results = r;
        _busy = false;
      });
    }
  }

  Future<void> _start() async {
    final plan = _plan, dest = _dest;
    if (plan == null || dest == null) return;
    final app = AppScope.read(context);
    final nav = Navigator.of(context);
    await app.startJourney(route: plan.points, eta: plan.eta, destination: dest.name);
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const SessionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _ll(_here),
            initialZoom: 15,
            onTap: (_, p) => _choose(Place('Dropped pin', LatLon(p.latitude, p.longitude))),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.afterburners.winger',
            ),
            if (plan != null)
              PolylineLayer(polylines: [
                Polyline(points: plan.points.map(_ll).toList(), color: W.plum, strokeWidth: 6),
              ]),
            MarkerLayer(markers: [
              Marker(
                point: _ll(_here),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F6BEA),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x552F6BEA), blurRadius: 12, spreadRadius: 4)],
                  ),
                ),
              ),
              if (_dest != null)
                Marker(
                    point: _ll(_dest!.at),
                    width: 40,
                    height: 40,
                    child: const Icon(WIcons.location, color: W.sos, size: 36)),
            ]),
            const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(28),
                color: Colors.white,
                child: Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                  Expanded(
                    child: TextField(
                      controller: _q,
                      onSubmitted: _search,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                          hintText: 'Where to?',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false),
                    ),
                  ),
                  IconButton(onPressed: () => _search(_q.text), icon: const Icon(WIcons.search)),
                ]),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ActionChip(
                  avatar: const Icon(WIcons.route, size: 18, color: W.plum),
                  label: const Text('Charbagh (demo)'),
                  onPressed: () => _choose(const Place('Charbagh Station', Demo.charbagh)),
                ),
                const Chip(
                    avatar: Icon(WIcons.location, size: 18), label: Text('or tap the map')),
              ]),
              if (_results.isNotEmpty)
                Material(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  child: Column(children: [
                    for (final r in _results)
                      ListTile(
                          leading: const Icon(WIcons.location), title: Text(r.name), onTap: () => _choose(r)),
                  ]),
                ),
            ]),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            child: WCard(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: W.plum,
                        selectedForegroundColor: Colors.white,
                        minimumSize: const Size(0, 48)),
                    segments: const [
                      ButtonSegment(value: true, icon: Icon(WIcons.walk), label: Text('Walk')),
                      ButtonSegment(value: false, icon: Icon(WIcons.car), label: Text('Ride')),
                    ],
                    selected: {_walk},
                    onSelectionChanged: (v) {
                      setState(() => _walk = v.first);
                      if (_dest != null) _choose(_dest!);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  const TintIcon(WIcons.location, W.leaf, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _busy
                          ? 'Finding the way…'
                          : plan == null
                              ? 'Search or tap the map to set your destination'
                              : '${_dest!.name}\n${(routeLength(plan.points) / 1000).toStringAsFixed(1)} km · '
                                  'about ${plan.eta.inMinutes} min${plan.estimated ? ' (estimate)' : ''}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                SwipeBar(
                  label: _walk ? 'Swipe to start walk' : 'Swipe to start ride',
                  color: W.leaf,
                  icon: WIcons.play,
                  faded: plan == null,
                  onDone: plan == null ? null : _start,
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
