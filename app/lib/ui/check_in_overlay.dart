import 'package:flutter/material.dart';

import '../core/ladder.dart';
import '../state/app_state.dart';
import 'session_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Full-screen "Are you okay?" above everything. The duress PIN looks
/// identical to the real one.
class CheckInOverlay extends StatefulWidget {
  const CheckInOverlay({super.key});
  @override
  State<CheckInOverlay> createState() => _CheckInOverlayState();
}

class _CheckInOverlayState extends State<CheckInOverlay> {
  String _pin = '';
  bool _wrong = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.session!;
    final r = s.ladder.rung;
    final title = switch (r) {
      Rung.guardian => 'Alerting your guardians',
      Rung.countdown112 => 'Calling 112 in ${s.ladder.remaining(DateTime.now())}s',
      _ => 'Are you okay?',
    };
    return Material(
      color: W.page,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(children: [
            TintIcon(WIcons.bell, W.marigold, size: 80),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
            const SizedBox(height: 6),
            Text(r == Rung.ask ? 'Time for your check-in.' : 'Enter your PIN if you are safe.',
                style: const TextStyle(color: W.text2, fontSize: 17)),
            const SizedBox(height: 18),
            LadderRow(rung: r, remaining: s.ladder.remaining(DateTime.now())),
            const SizedBox(height: 18),
            Material(
              color: W.sos,
              elevation: 8,
              shadowColor: W.sos.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onLongPress: app.help,
                onTap: app.help,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0x33FFFFFF),
                        child: Icon(WIcons.danger, color: Colors.white)),
                    SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Help me',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      Text('Alerts your guardians now', style: TextStyle(color: Colors.white70)),
                    ]),
                  ]),
                ),
              ),
            ),
            const Spacer(),
            Text(_wrong ? 'Wrong PIN, try again' : "I'm safe: enter your PIN",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w500, color: _wrong ? W.sos : W.text)),
            const SizedBox(height: 8),
            PinDots(length: _pin.length),
            const SizedBox(height: 14),
            PinPad(
              onDigit: (d) => setState(() {
                _wrong = false;
                if (_pin.length < 8) _pin += d;
              }),
              onBack: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
              onSubmit: _pin.length >= 3
                  ? () async {
                      final ok = await app.checkInSafe(_pin);
                      setState(() {
                        _wrong = !ok;
                        _pin = '';
                      });
                    }
                  : null,
            ),
          ]),
        ),
      ),
    );
  }
}
