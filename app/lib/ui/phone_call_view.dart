import 'package:flutter/material.dart';

/// Looks like the phone's own dialler (Google Phone style). Material icons on
/// purpose: nothing here may look like Winger.
class PhoneCallView extends StatefulWidget {
  final String name;
  final String status; // "Calling…" or the timer
  final bool muted;
  final bool speaker;
  final String keypadEntry;
  final VoidCallback onEnd;
  final VoidCallback onMute;
  final VoidCallback onMuteHeld;
  final VoidCallback onSpeaker;
  final void Function(String key)? onKey;

  const PhoneCallView({
    super.key,
    required this.name,
    required this.status,
    required this.onEnd,
    required this.onMute,
    required this.onMuteHeld,
    required this.onSpeaker,
    this.onKey,
    this.muted = false,
    this.speaker = false,
    this.keypadEntry = '',
  });

  @override
  State<PhoneCallView> createState() => _PhoneCallViewState();
}

class _PhoneCallViewState extends State<PhoneCallView> {
  bool _keypad = false;

  static const _fg = Colors.white;
  static const _btn = Color(0xFF2F3740);

  Widget _control(IconData icon, String label, {VoidCallback? onTap, VoidCallback? onLong, bool on = false}) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onLongPress: onLong,
          child: Material(
            color: on ? const Color(0xFFD3E3FD) : _btn,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                  width: 64, height: 64, child: Icon(icon, color: on ? Colors.black87 : _fg)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Color(0xFFD5D9DE), fontSize: 14)),
      ]);

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isEmpty ? '?' : widget.name[0].toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF232B33), Color(0xFF12161B)],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: 40),
          Text(widget.name, style: const TextStyle(color: _fg, fontSize: 36)),
          const SizedBox(height: 8),
          Text(widget.status, style: const TextStyle(color: Color(0xFFD5D9DE), fontSize: 17)),
          const Text('Mobile', style: TextStyle(color: Color(0xFF9AA2AB), fontSize: 15)),
          Expanded(
            child: Center(
              child: _keypad
                  ? FittedBox(fit: BoxFit.scaleDown, child: _dialPad())
                  : CircleAvatar(
                      radius: 90,
                      backgroundColor: const Color(0xFF5D7B98),
                      child: Text(initial, style: const TextStyle(color: _fg, fontSize: 64)),
                    ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF1F252B),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _control(Icons.dialpad, 'Keypad',
                  on: _keypad, onTap: () => setState(() => _keypad = !_keypad)),
              _control(widget.muted ? Icons.mic_off : Icons.mic_off_outlined, 'Mute',
                  on: widget.muted, onTap: widget.onMute, onLong: widget.onMuteHeld),
              _control(Icons.volume_up, 'Speaker', on: widget.speaker, onTap: widget.onSpeaker),
              _control(Icons.more_vert, 'More', onTap: () {}),
            ]),
          ),
          const SizedBox(height: 28),
          Material(
            color: const Color(0xFFDC3626),
            borderRadius: BorderRadius.circular(40),
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: widget.onEnd,
              child: const SizedBox(
                width: 170,
                height: 80,
                child: Icon(Icons.call_end, color: _fg, size: 34),
              ),
            ),
          ),
          const SizedBox(height: 36),
        ]),
      ),
    );
  }

  Widget _dialPad() {
    Widget key(String k, [String sub = '']) => InkWell(
          customBorder: const CircleBorder(),
          onTap: () => widget.onKey?.call(k),
          child: SizedBox(
            width: 84,
            height: 64,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(k, style: const TextStyle(color: _fg, fontSize: 30)),
              if (sub.isNotEmpty)
                Text(sub, style: const TextStyle(color: Color(0xFF9AA2AB), fontSize: 10)),
            ]),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.keypadEntry, style: const TextStyle(color: _fg, fontSize: 28, letterSpacing: 4)),
      const SizedBox(height: 8),
      for (final row in const [
        [('1', ''), ('2', 'ABC'), ('3', 'DEF')],
        [('4', 'GHI'), ('5', 'JKL'), ('6', 'MNO')],
        [('7', 'PQRS'), ('8', 'TUV'), ('9', 'WXYZ')],
        [('*', ''), ('0', '+'), ('#', '')],
      ])
        Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final (k, s) in row) key(k, s)]),
    ]);
  }
}
