import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'phone_call_view.dart';
import 'theme.dart';
import 'widgets.dart';

const _momLines = [
  'Hello? Where are you? It is getting late.',
  'Your father is asking. Come home now, okay?',
  'I am sending your brother to pick you up. Stay where people are.',
  'Okay. Stay on the line till you see him.',
];

/// Schedules a believable call from "Mom" to get her out of a situation.
class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});
  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  final _caller = TextEditingController(text: 'Mom');
  Timer? _wait;
  int? _left;

  void _schedule(int seconds) {
    _wait?.cancel();
    if (seconds == 0) return _ring();
    setState(() => _left = seconds);
    _wait = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left = _left! - 1);
      if (_left! <= 0) {
        t.cancel();
        _left = null;
        _ring();
      }
    });
  }

  void _ring() => Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, _, _) => _FakeCall(name: _caller.text.trim().isEmpty ? 'Mom' : _caller.text.trim()),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ));

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fake call')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              'Need a reason to leave? Get a call that looks real. The caller talks, so you can answer out loud.',
              style: TextStyle(color: W.text2, fontSize: 15, height: 1.4)),
          const SizedBox(height: 16),
          TextField(controller: _caller, decoration: const InputDecoration(labelText: 'Caller name')),
          const SizedBox(height: 16),
          if (_left != null)
            WCard(
              child: Row(children: [
                const TintIcon(WIcons.timer, W.leaf),
                const SizedBox(width: 12),
                Expanded(child: Text('Ringing in ${_left}s', style: const TextStyle(fontWeight: FontWeight.w700))),
                TextButton(
                    onPressed: () => setState(() {
                          _wait?.cancel();
                          _left = null;
                        }),
                    child: const Text('Cancel')),
              ]),
            )
          else
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (label, s) in const [('Now', 0), ('In 30 s', 30), ('In 1 min', 60), ('In 5 min', 300)])
                FilledButton.tonal(onPressed: () => _schedule(s), child: Text(label)),
            ]),
        ]),
      );
}

class _FakeCall extends StatefulWidget {
  final String name;
  const _FakeCall({required this.name});
  @override
  State<_FakeCall> createState() => _FakeCallState();
}

class _FakeCallState extends State<_FakeCall> {
  final _started = DateTime.now();
  late final Timer _tick;
  int _line = 0;
  bool _muted = false, _speaker = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {});
      final secs = DateTime.now().difference(_started).inSeconds;
      if (secs % 8 == 2 && _line < _momLines.length) {
        AppScope.read(context).voice.say(_momLines[_line++]);
      }
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: PhoneCallView(
          name: widget.name,
          status: mmss(DateTime.now().difference(_started)),
          muted: _muted,
          speaker: _speaker,
          onEnd: () {
            AppScope.read(context).voice.stop();
            Navigator.pop(context);
          },
          onMute: () => setState(() => _muted = !_muted),
          onMuteHeld: () {},
          onSpeaker: () => setState(() => _speaker = !_speaker),
        ),
      );
}
