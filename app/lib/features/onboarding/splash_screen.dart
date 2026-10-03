import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/rx_logo.dart';

/// Three seconds: the mark, the name, and the tagline — first in English, then
/// in Hindi, because the user has not told us their language yet.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onDone,
    this.duration = const Duration(seconds: 3),
    this.language,
  });

  final VoidCallback onDone;
  final Duration duration;

  /// Pin the tagline to one language. Used by the goldens.
  final AppLanguage? language;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _swap;
  Timer? _done;
  AppLanguage _showing = AppLanguage.en;

  @override
  void initState() {
    super.initState();
    _showing = widget.language ?? AppLanguage.en;
    if (widget.language == null) {
      _swap = Timer(widget.duration ~/ 2, () {
        if (mounted) setState(() => _showing = AppLanguage.hi);
      });
    }
    _done = Timer(widget.duration, widget.onDone);
  }

  @override
  void dispose() {
    _swap?.cancel();
    _done?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final strings = AppStrings(_showing);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RxLogo(size: 124),
            const SizedBox(height: 32),
            Text(
              strings.appName,
              style: text.displayLarge?.copyWith(fontSize: 40),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                strings.tagline,
                key: ValueKey(_showing),
                style: text.titleMedium?.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 52),
            const LoadingBar(),
          ],
        ),
      ),
    );
  }
}

/// A short amber bar with a sliding segment. Calm, not a spinner.
class LoadingBar extends StatefulWidget {
  const LoadingBar({super.key, this.width = 120});

  final double width;

  @override
  State<LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<LoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    value: .9,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const segment = .52;
    return SizedBox(
      width: widget.width,
      height: 5,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _BarPainter(progress: _c.value, segment: segment),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.progress, required this.segment});

  final double progress;
  final double segment;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.amberSoft);
    final travel = size.width * (1 + segment);
    final start = progress * travel - size.width * segment;
    final left = start.clamp(0.0, size.width);
    final right = (start + size.width * segment).clamp(0.0, size.width);
    if (right > left) {
      canvas.drawRect(
        Rect.fromLTRB(left, 0, right, size.height),
        Paint()..color = AppColors.amber,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.progress != progress;
}
