import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'alert_settings_screen.dart';
import 'help_screen.dart';
import 'locker_screen.dart';
import 'route_screen.dart';
import 'session_screen.dart';
import 'theme.dart';
import 'widgets.dart';
import 'wingman_call_screen.dart';

const _tips = [
  (WIcons.shield, 'Feeling unsafe?', 'Tap Active duty. You get a call from a friend who stays with you.'),
  (WIcons.mic, "In danger, can't say so", 'Say your safe phrase on the call. Your guardians are alerted silently.'),
  (WIcons.keypad, 'False alarm', 'On the call, open Keypad, dial your PIN, then #. Everyone is told you are safe.'),
  (WIcons.call, 'End the call', 'Winger goes silent and keeps listening. A scream makes it ask if you are okay.'),
  (WIcons.eye, 'Hide Winger', 'Tap the lock. Winger becomes a wallpaper app until you type your PIN in its search box.'),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static Future<void> startActiveDuty(BuildContext context) async {
    final app = AppScope.read(context);
    final nav = Navigator.of(context);
    if (app.session == null || app.session!.kind == SessionKind.wingman) {
      final call = app.call != null && !app.call!.ended ? app.call! : await app.startWingman();
      nav.push(MaterialPageRoute(builder: (_) => const SessionScreen()));
      nav.push(PageRouteBuilder(
        pageBuilder: (_, _, _) => WingmanCallScreen(call: call),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => const SessionScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.session;
    final dot = app.statusColor ?? W.watching;
    return Stack(children: [
      const _Sky(),
      SafeArea(
        child: FitOrScroll(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(children: [
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  gradient: const LinearGradient(colors: [W.coral, Color(0xFFF2557A)]),
                ),
                child: Center(
                  child: Text(app.settings.name.isEmpty ? 'W' : app.settings.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(app.statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: W.text2, fontSize: 14)),
                    ),
                  ]),
                ]),
              ),
              for (final g in app.settings.guardians.take(2))
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: W.gold,
                    child: Text(g.initial,
                        style: const TextStyle(color: W.text, fontWeight: FontWeight.w700)),
                  ),
                ),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 0,
                child: IconButton(
                  tooltip: 'Hide Winger',
                  onPressed: app.lock,
                  icon: const Icon(WIcons.lock, color: W.text),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            const Expanded(flex: 5, child: _TipsCard()),
            const SizedBox(height: 16),
            Expanded(
              flex: 4,
              child: Row(children: [
                Expanded(
                  child: _Tile(
                    icon: WIcons.route,
                    colors: W.green,
                    title: 'Set route',
                    subtitle: 'Walk or ride, watched',
                    onTap: s != null
                        ? null
                        : () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const RouteScreen())),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _Tile(
                    icon: WIcons.shield,
                    colors: W.orange,
                    title: 'Active duty',
                    subtitle: s == null ? 'A friend calls and stays' : app.statusText,
                    pill: s == null ? 'Start' : 'On',
                    onTap: () => startActiveDuty(context),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Expanded(
              flex: 4,
              child: Row(children: [
                Expanded(
                  child: _Tile(
                    icon: WIcons.locker,
                    colors: W.violet,
                    title: 'Locker',
                    subtitle: app.recordings.isEmpty
                        ? 'Recordings are kept here'
                        : '${app.recordings.length} recording${app.recordings.length == 1 ? '' : 's'}',
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const LockerScreen())),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _Tile(
                    icon: WIcons.bell,
                    colors: W.pink,
                    title: 'Alert settings',
                    subtitle: 'Phrases, code and tools',
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const AlertSettingsScreen())),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _Sky extends StatelessWidget {
  const _Sky();
  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: 460,
        child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.6, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE2C4), Color(0xFFF7D9F4), Color(0xFFDDE4FF)],
              ),
            ),
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              _circle(right: -60, top: -50, size: 220, color: const Color(0xFFFFD27A)),
              _circle(left: -80, top: 190, size: 170, color: const Color(0xFF9BE3B5)),
              _circle(right: 90, top: 330, size: 110, color: const Color(0xFFFFA9C0)),
            ]),
          ),
        ),
      );

  static Widget _circle(
          {double? left, double? right, double? top, required double size, required Color color}) =>
      Positioned(
        left: left,
        right: right,
        top: top,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.55)),
        ),
      );
}

class _TipsCard extends StatefulWidget {
  const _TipsCard();
  @override
  State<_TipsCard> createState() => _TipsCardState();
}

class _TipsCardState extends State<_TipsCard> {
  int _page = 0;

  @override
  Widget build(BuildContext context) => WCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFFF2557A), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            const Expanded(
                child: Text('Help and instructions', style: TextStyle(color: W.text2, fontSize: 14))),
            GestureDetector(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const HelpScreen())),
              child: const Text('See all',
                  style: TextStyle(color: W.marigold, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ]),
          Expanded(
            child: PageView.builder(
              itemCount: _tips.length,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (context, i) {
                final (icon, title, body) = _tips[i];
                return Row(children: [
                  GradientIcon(icon, W.orange, size: 62),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(body,
                              style: const TextStyle(color: W.text2, fontSize: 15, height: 1.4)),
                        ]),
                  ),
                ]);
              },
            ),
          ),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_page + 1) / _tips.length,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFFCE9D6),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFF7A23B)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${_page + 1}/${_tips.length}', style: const TextStyle(color: W.text2)),
          ]),
        ]),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String subtitle;
  final String? pill;
  final VoidCallback? onTap;
  const _Tile({
    required this.icon,
    required this.colors,
    required this.title,
    required this.subtitle,
    this.pill,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: WCard(
          radius: 28,
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GradientIcon(icon, colors),
              const Spacer(),
              if (pill != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: W.orange),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(pill!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ]),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: W.text2, fontSize: 14)),
          ]),
        ),
      );
}
