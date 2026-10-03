import 'package:flutter/widgets.dart';

/// A button that gives under the finger: it shrinks to [pressedScale] while
/// pressed and springs back on release.
///
/// Only the look changes. A [Listener] sees the pointer without joining the
/// gesture arena, so the child's own tap, long-press and semantics are
/// untouched — and at rest the scale is exactly 1, so nothing moves in a
/// screenshot.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = .97,
  });

  final Widget child;

  /// A disabled button does not give.
  final bool enabled;
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled ? (_) => _set(true) : null,
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down && widget.enabled ? widget.pressedScale : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}
