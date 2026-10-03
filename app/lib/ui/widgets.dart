import 'package:flutter/material.dart';

import '../config.dart';
import '../state/app_state.dart';
import 'theme.dart';

/// On a wide window the app stays a centred phone column.
class PortraitFrame extends StatelessWidget {
  final Widget child;
  const PortraitFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFEDE7F2),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxPhoneWidth),
            child: ClipRect(child: child),
          ),
        ),
      );
}

/// Fits one screen when it can; scrolls when the screen is too short.
class FitOrScroll extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const FitOrScroll({super.key, required this.child, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - padding.vertical),
            child: IntrinsicHeight(child: child),
          ),
        ),
      );
}

/// The 4-px coloured line along the top while a session runs.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = app.statusColor;
    final onCall = app.call != null && !app.call!.ended;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: c == null || onCall ? 0 : 4,
      color: c ?? Colors.transparent,
    );
  }
}

/// Bright gradient rounded-square icon.
class GradientIcon extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final double size;
  const GradientIcon(this.icon, this.colors, {super.key, this.size = 58});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.3),
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          boxShadow: [
            BoxShadow(
                color: colors.last.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      );
}

/// Soft tinted square icon used in lists.
class TintIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const TintIcon(this.icon, this.color, {super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, color: color, size: size * 0.48),
      );
}

class WCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  const WCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color ?? W.card,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: W.shadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

/// Honest footer used on onboarding.
const honestCopy =
    'Winger helps you get help faster. It is not a guarantee of safety. In danger, call 112.';

/// Swipe-to-confirm bar (SOS, start walk).
class SwipeBar extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onDone;
  final bool faded;
  const SwipeBar({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.onDone,
    this.faded = false,
  });

  @override
  State<SwipeBar> createState() => _SwipeBarState();
}

class _SwipeBarState extends State<SwipeBar> {
  double _x = 0;

  @override
  Widget build(BuildContext context) {
    const knob = 60.0;
    return LayoutBuilder(builder: (context, c) {
      final max = c.maxWidth - knob - 8;
      final enabled = widget.onDone != null;
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: widget.faded ? widget.color.withValues(alpha: 0.12) : widget.color,
          borderRadius: BorderRadius.circular(36),
        ),
        child: Stack(alignment: Alignment.centerLeft, children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: knob),
              child: Text(widget.label,
                  style: TextStyle(
                      color: widget.faded
                          ? widget.color.withValues(alpha: 0.5)
                          : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17)),
            ),
          ),
          Positioned(
            left: 4 + _x,
            child: GestureDetector(
              onHorizontalDragUpdate: enabled
                  ? (d) => setState(() => _x = (_x + d.delta.dx).clamp(0, max))
                  : null,
              onHorizontalDragEnd: enabled
                  ? (_) {
                      if (_x > max * 0.8) widget.onDone!();
                      setState(() => _x = 0);
                    }
                  : null,
              child: Container(
                width: knob,
                height: knob,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.faded
                      ? widget.color.withValues(alpha: 0.35)
                      : Colors.white,
                ),
                child: Icon(widget.icon,
                    color: widget.faded ? Colors.white : widget.color, size: 28),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

/// Numeric PIN pad used by the check-in and confirmation sheets.
class PinPad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBack;
  final VoidCallback? onSubmit;
  final String submitLabel;
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBack,
    required this.onSubmit,
    this.submitLabel = "I'm safe",
  });

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback? onTap, {Color? color}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Material(
              color: color ?? W.card,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: SizedBox(height: 64, child: Center(child: child)),
              ),
            ),
          ),
        );
    Widget digit(String d) => key(
        Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
        () => onDigit(d));
    return Column(children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9']
      ])
        Row(children: row.map(digit).toList()),
      Row(children: [
        key(const Icon(Icons.backspace_outlined, color: W.text2), onBack,
            color: W.containerHighest),
        digit('0'),
        key(
            Text(submitLabel,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSubmit == null ? W.text2 : Colors.white)),
            onSubmit,
            color: onSubmit == null ? W.containerHighest : W.plum),
      ]),
    ]);
  }
}

/// Asks for the PIN in a bottom sheet. Returns the entry or null.
Future<String?> askPin(BuildContext context, {String title = 'Enter your PIN'}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PinSheet(title: title),
  );
}

class _PinSheet extends StatefulWidget {
  final String title;
  const _PinSheet({required this.title});
  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _pin = '';
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            PinDots(length: _pin.length),
            const SizedBox(height: 16),
            PinPad(
              submitLabel: 'OK',
              onDigit: (d) => setState(() => _pin = (_pin + d).length > 8 ? _pin : _pin + d),
              onBack: () => setState(
                  () => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
              onSubmit: _pin.length >= 3 ? () => Navigator.pop(context, _pin) : null,
            ),
          ]),
        ),
      );
}

class PinDots extends StatelessWidget {
  final int length;
  const PinDots({super.key, required this.length});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < (length < 4 ? 4 : length); i++)
            Container(
              margin: const EdgeInsets.all(5),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < length ? W.plum : W.text2.withValues(alpha: 0.35),
              ),
            ),
        ],
      );
}

String hhmm(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String mmss(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
