import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';

enum Motif { hills, waves, sun, rings, plain }

class Wallpaper {
  final String name;
  final String category;
  final List<Color> sky;
  final Motif motif;
  final List<Color> layers;
  const Wallpaper(this.name, this.category, this.sky, this.motif, [this.layers = const []]);
}

const wallpapers = [
  Wallpaper('Dawn Ridge', 'Nature', [Color(0xFFFFB27A), Color(0xFFE85D7A)], Motif.hills,
      [Color(0xFF2E2145), Color(0xFF221A33), Color(0xFF15101F)]),
  Wallpaper('Deep Ocean', 'Nature', [Color(0xFF0E4A63), Color(0xFF9DE6D9)], Motif.waves,
      [Color(0x33FFFFFF), Color(0x33FFFFFF), Color(0x33FFFFFF)]),
  Wallpaper('Aurora', 'Abstract', [Color(0xFF13274B), Color(0xFFC9F7D6)], Motif.waves,
      [Color(0x3322C9A0), Color(0x3344D6A8), Color(0x33FFFFFF)]),
  Wallpaper('Midnight', 'Dark', [Color(0xFF07090F), Color(0xFF283A78)], Motif.sun,
      [Color(0xFFCACBCF)]),
  Wallpaper('Peach', 'Minimal', [Color(0xFFFFE1D3), Color(0xFFFFC2B0)], Motif.plain),
  Wallpaper('Sage Valley', 'Nature', [Color(0xFFCFE6D4), Color(0xFF7FAE86)], Motif.hills,
      [Color(0xFF6E9C76), Color(0xFF557E5D), Color(0xFF3F6247)]),
  Wallpaper('Ripple', 'Abstract', [Color(0xFFB8A6FF), Color(0xFFFF9EC4)], Motif.rings,
      [Color(0x40FFFFFF)]),
  Wallpaper('Ink', 'Dark', [Color(0xFF111111), Color(0xFF2A2A2A)], Motif.rings,
      [Color(0x22FFFFFF)]),
  Wallpaper('Desert Sun', 'Nature', [Color(0xFFFFD08A), Color(0xFFF2875B)], Motif.sun,
      [Color(0xFFFFF4D6)]),
  Wallpaper('Fog', 'Minimal', [Color(0xFFEDEFF3), Color(0xFFD4D9E2)], Motif.plain),
  Wallpaper('Lavender Hills', 'Abstract', [Color(0xFFE9D9FF), Color(0xFFB79CF2)], Motif.hills,
      [Color(0xFF9C7FE0), Color(0xFF7E62C4), Color(0xFF5D46A0)]),
  Wallpaper('Night Sea', 'Dark', [Color(0xFF020B1A), Color(0xFF0D2B52)], Motif.waves,
      [Color(0x220E5E9E), Color(0x22126FB5), Color(0x221A86D1)]),
  Wallpaper('Mint', 'Minimal', [Color(0xFFDFF7EC), Color(0xFFB4EBD3)], Motif.plain),
  Wallpaper('Ember', 'Abstract', [Color(0xFF3B0A1E), Color(0xFFFF6B3D)], Motif.rings,
      [Color(0x33FFC37A)]),
];

/// The disguise: a plain wallpaper app. Typing the PIN in the search box
/// opens Winger; long-pressing a wallpaper is a silent SOS.
class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});
  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  static const _bg = Color(0xFFF8F6FA);
  final _search = TextEditingController();
  String _category = 'All';

  void _submit(String text) {
    final app = AppScope.read(context);
    final entry = text.trim();
    if (RegExp(r'^\d+$').hasMatch(entry)) {
      _search.clear();
      app.tryUnlock(entry);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final shown = wallpapers.where((w) {
      if (_category != 'All' && w.category != _category) return false;
      if (q.isNotEmpty && !RegExp(r'^\d+$').hasMatch(q)) {
        return w.name.toLowerCase().contains(q) || w.category.toLowerCase().contains(q);
      }
      return true;
    }).toList();
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text('Wallpapers',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF221A20),
                      letterSpacing: -0.5)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _search,
                onSubmitted: _submit,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search wallpapers',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF6E5A5F)),
                  filled: true,
                  fillColor: const Color(0xFFEDE8F2),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFE2DCE8))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFFE2DCE8))),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  for (final c in const ['All', 'Nature', 'Abstract', 'Dark', 'Minimal'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        showCheckmark: false,
                        selectedColor: const Color(0xFFF7D7E8),
                        backgroundColor: _bg,
                        side: const BorderSide(color: Color(0xFFE2DCE8)),
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.62),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _Tile(shown[i]),
                childCount: shown.length,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Wallpaper w;
  const _Tile(this.w);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _Preview(w), fullscreenDialog: true)),
        // Silent SOS: nothing changes on screen.
        onLongPress: () => AppScope.read(context).silentSos(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: WallpaperPainter(w)),
            Positioned(
              left: 12,
              bottom: 12,
              child: Text(w.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black38)])),
            ),
          ]),
        ),
      );
}

class _Preview extends StatelessWidget {
  final Wallpaper w;
  const _Preview(this.w);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: WallpaperPainter(w)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: Colors.black87),
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Wallpaper set')));
                    },
                    child: const Text('Set wallpaper'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      );
}

/// Draws a wallpaper in code: gradient sky plus a motif.
class WallpaperPainter extends CustomPainter {
  final Wallpaper w;
  WallpaperPainter(this.w);

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: w.sky)
              .createShader(rect));
    switch (w.motif) {
      case Motif.hills:
        for (var i = 0; i < w.layers.length; i++) {
          final top = s.height * (0.5 + i * 0.12);
          final amp = s.height * 0.05;
          final path = Path()..moveTo(0, top);
          for (double x = 0; x <= s.width; x += 4) {
            path.lineTo(x, top + sin(x / s.width * pi * (1.5 + i) + i) * amp);
          }
          path
            ..lineTo(s.width, s.height)
            ..lineTo(0, s.height)
            ..close();
          canvas.drawPath(path, Paint()..color = w.layers[i]);
        }
      case Motif.waves:
        for (var i = 0; i < w.layers.length; i++) {
          final top = s.height * (0.25 + i * 0.17);
          final amp = s.height * 0.035;
          final path = Path()..moveTo(0, top);
          for (double x = 0; x <= s.width; x += 4) {
            path.lineTo(x, top + sin(x / s.width * 2 * pi + i * 1.3) * amp);
          }
          path
            ..lineTo(s.width, s.height)
            ..lineTo(0, s.height)
            ..close();
          canvas.drawPath(path, Paint()..color = w.layers[i]);
        }
      case Motif.sun:
        final c = Offset(s.width * 0.68, s.height * 0.3);
        canvas.drawCircle(c, s.width * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.08));
        canvas.drawCircle(c, s.width * 0.18, Paint()..color = w.layers.first);
      case Motif.rings:
        final c = Offset(s.width * 0.3, s.height * 0.7);
        for (var r = 1; r <= 6; r++) {
          canvas.drawCircle(
              c,
              s.width * 0.18 * r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 10
                ..color = w.layers.first);
        }
      case Motif.plain:
        break;
    }
  }

  @override
  bool shouldRepaint(WallpaperPainter old) => old.w != w;
}
