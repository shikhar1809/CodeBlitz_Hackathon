import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../config.dart';
import '../core/evidence_chain.dart';
import '../core/ladder.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';
import 'wingman_call_screen.dart';

/// The live screen while a session runs.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.session;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Session ended. You are safe.')),
      );
    }
    final now = DateTime.now();
    final next = s.nextCheckIn.difference(now);
    final verified = EvidenceChain.verify(s.recording.chain.chunks);
    final title = s.kind == SessionKind.journey ? 'Journey' : 'Wingman';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          const TintIcon(WIcons.shield, W.leaf, size: 40),
          const SizedBox(width: 12),
          Text(title),
        ]),
        actions: [
          if (app.cloud.trackUrl != null)
            IconButton(
              tooltip: 'Copy guardian live link',
              icon: const Icon(Icons.link),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: app.cloud.trackUrl!));
                app.showBanner('Live link copied');
              },
            ),
          IconButton(
            tooltip: 'Call Wingman',
            icon: const Icon(WIcons.call),
            onPressed: () async {
              final nav = Navigator.of(context);
              final call = app.call != null && !app.call!.ended ? app.call! : await app.callWingman();
              nav.push(MaterialPageRoute(builder: (_) => WingmanCallScreen(call: call)));
            },
          ),
          IconButton(
            tooltip: 'Add a photo',
            icon: const Icon(WIcons.camera),
            onPressed: () async {
              await app.addPhoto(List.generate(64, (i) => i)); // demo photo bytes
              if (context.mounted) app.showBanner('Photo sealed in the Blackbox');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(children: [
            _StatusCard(app: app, s: s),
            const SizedBox(height: 12),
            if (s.kind == SessionKind.journey && s.route.isNotEmpty)
              SizedBox(height: 200, child: _JourneyMap(s: s))
            else ...[
              Row(children: [
                Expanded(
                    child: _Stat(WIcons.timer, W.leaf,
                        s.kind == SessionKind.journey ? '—' : '${next.isNegative ? 0 : next.inSeconds}s',
                        'Next check-in')),
                const SizedBox(width: 12),
                Expanded(
                    child: _Stat(WIcons.location, W.indigo, '${s.location ?? '…'}', 'Location shared')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _Stat(WIcons.record, W.sos, '${s.recording.chain.chunks.length} chunks',
                        verified ? 'Encrypted · verified' : 'Chain broken!')),
                const SizedBox(width: 12),
                Expanded(
                    child: _Stat(WIcons.people, W.magenta,
                        s.guardiansAlerted == 0 ? '${app.settings.guardians.length} ready' : '${s.guardiansAlerted} alerted',
                        'Guardian')),
              ]),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: WCard(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Live log', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    if (isDemo)
                      TextButton(
                        onPressed: () => app.hearSound('Screaming', 0.9),
                        child: const Text('Demo: scream'),
                      ),
                  ]),
                  Expanded(
                    child: ListView(children: [
                      for (final e in app.log.take(40))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(
                                width: 74,
                                child: Text(hhmm(e.at),
                                    style: const TextStyle(color: W.text2, fontSize: 13))),
                            Expanded(
                              child: Text(e.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            SwipeBar(
              label: 'Swipe for SOS · 112',
              color: W.sos,
              icon: WIcons.danger,
              onDone: app.sos,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: W.sos, side: const BorderSide(color: W.sos)),
                  onPressed: app.help,
                  icon: const Icon(WIcons.people),
                  label: const Text('Alert guardians'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final pin = await askPin(context, title: "I'm safe: enter your PIN");
                    if (pin == null) return;
                    final ok = await app.answerPin(pin);
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    } else {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Wrong PIN')));
                    }
                  },
                  icon: const Icon(WIcons.tick),
                  label: const Text("I'm safe"),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final AppState app;
  final Session s;
  const _StatusCard({required this.app, required this.s});

  @override
  Widget build(BuildContext context) {
    final color = app.statusColor ?? W.watching;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(WIcons.shield, color: color == W.watching ? W.leaf : color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(app.statusText,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ),
        ]),
        const SizedBox(height: 12),
        LadderRow(rung: s.duress ? Rung.idle : s.ladder.rung, remaining: s.ladder.remaining(DateTime.now())),
      ]),
    );
  }
}

/// Nudge · Ask · Guardian · 112, with the current rung lit.
class LadderRow extends StatelessWidget {
  final Rung rung;
  final int? remaining;
  const LadderRow({super.key, required this.rung, this.remaining});

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Rung.nudge, WIcons.shake, 'Nudge'),
      (Rung.ask, WIcons.message, 'Ask'),
      (Rung.guardian, WIcons.people, 'Guardian'),
      (Rung.countdown112, WIcons.warning, '112'),
    ];
    return Row(children: [
      for (final (r, icon, label) in steps)
        Expanded(
          child: Builder(builder: (context) {
            final current = rung == r || (r == Rung.countdown112 && rung == Rung.called112);
            final past = rung.index > r.index && !current;
            final bg = current
                ? (r.index >= Rung.guardian.index ? W.sos : const Color(0xFFF7B347))
                : past
                    ? const Color(0xFFFCE9D6)
                    : Colors.black.withValues(alpha: 0.06);
            final fg = current ? Colors.white : past ? const Color(0xFFF7A23B) : W.text2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 50,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    current && remaining != null ? '$label ${remaining}s' : label,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                        color: fg, fontWeight: FontWeight.w600, fontSize: label.length > 5 ? 12 : 14),
                  ),
                ),
              ]),
            );
          }),
        ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _Stat(this.icon, this.color, this.value, this.label);

  @override
  Widget build(BuildContext context) => WCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TintIcon(icon, color, size: 44),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          Text(label, style: const TextStyle(color: W.text2, fontSize: 13)),
        ]),
      );
}

class _JourneyMap extends StatelessWidget {
  final Session s;
  const _JourneyMap({required this.s});

  @override
  Widget build(BuildContext context) {
    final pts = [for (final p in s.route) ll.LatLng(p.lat, p.lon)];
    final me = s.location == null ? pts.first : ll.LatLng(s.location!.lat, s.location!.lon);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(30)),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.afterburners.winger',
          ),
          PolylineLayer(polylines: [Polyline(points: pts, color: W.plum, strokeWidth: 5)]),
          MarkerLayer(markers: [
            Marker(
              point: me,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2F6BEA),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
