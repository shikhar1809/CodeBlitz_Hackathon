import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'widgets.dart';

/// Loud deterrent: a flashing screen and a spoken warning, backed by a real
/// recording and a real guardian alert.
class DeterrentScreen extends StatefulWidget {
  const DeterrentScreen({super.key});
  @override
  State<DeterrentScreen> createState() => _DeterrentScreenState();
}

class _DeterrentScreenState extends State<DeterrentScreen> {
  static const _line =
      'This is being recorded. Police have been informed. Location has been shared.';
  late final Timer _flash;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    _flash = Timer.periodic(const Duration(milliseconds: 450), (_) => setState(() => _on = !_on));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final app = AppScope.read(context);
    await app.startQuiet(SessionKind.wingman);
    app.note('Deterrent on');
    await app.alertGuardians('Deterrent used');
    for (var i = 0; i < 3 && mounted; i++) {
      await app.voice.say(_line);
    }
  }

  @override
  void dispose() {
    _flash.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _on ? const Color(0xFFE5383B) : const Color(0xFF8E1013),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              const Icon(Icons.fiber_manual_record, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              const Text('RECORDING STARTED\n•\nPOLICE INFORMED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 16),
              const Text('Location has been shared.',
                  style: TextStyle(color: Colors.white70, fontSize: 18)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                  onPressed: () async {
                    final app = AppScope.read(context);
                    final nav = Navigator.of(context);
                    final pin = await askPin(context, title: 'PIN to stop');
                    if (pin == null) return;
                    if (await app.answerPin(pin)) {
                      await app.voice.stop();
                      nav.pop();
                    }
                  },
                  child: const Text('Stop (PIN)'),
                ),
              ),
            ]),
          ),
        ),
      );
}
