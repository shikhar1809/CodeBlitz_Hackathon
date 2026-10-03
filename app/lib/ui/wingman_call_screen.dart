import 'dart:async';

import 'package:flutter/material.dart';

import '../core/pin_vault.dart';
import '../state/app_state.dart';
import '../state/wingman_call.dart';
import 'phone_call_view.dart';
import 'widgets.dart';

/// The Wingman call, drawn as the phone's own call screen.
class WingmanCallScreen extends StatefulWidget {
  final WingmanCall call;
  const WingmanCallScreen({super.key, required this.call});
  @override
  State<WingmanCallScreen> createState() => _WingmanCallScreenState();
}

class _WingmanCallScreenState extends State<WingmanCallScreen> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    widget.call.addListener(_changed);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  void _changed() {
    if (!mounted) return;
    if (widget.call.ended) {
      Navigator.of(context).maybePop();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    widget.call.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.call;
    final app = AppScope.of(context);
    return PopScope(
      canPop: c.ended,
      child: Scaffold(
        body: PhoneCallView(
          name: app.settings.companionName,
          status: c.phase == CallPhase.calling ? 'Calling…' : mmss(c.elapsed(DateTime.now())),
          muted: c.muted,
          speaker: c.speaker,
          keypadEntry: c.keypad,
          onEnd: () => c.end(),
          onMute: c.toggleMute,
          onMuteHeld: c.holdMute,
          onSpeaker: c.toggleSpeaker,
          onKey: (k) async {
            final r = await c.press(k);
            if (r == PinResult.real || r == PinResult.code) {
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            }
          },
        ),
      ),
    );
  }
}
