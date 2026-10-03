import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// "How Winger works".
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _cards = [
    (WIcons.shield, W.marigold, 'Active duty',
        'Tap it when you feel unsafe. A friend calls you and Winger starts watching: location, recording, check-ins.'),
    (WIcons.call, W.leaf, 'The call',
        'It looks like a normal phone call. Chat as you would. Hold Mute for a silent alert. Keypad, your PIN, then # stops a false alarm.'),
    (WIcons.mic, W.magenta, 'Safe phrases',
        'Say your phrase ("Did you feed the cat") on the call. Nothing changes on screen; your guardians get a silent alert.'),
    (WIcons.voice, W.coral, 'Listening',
        'After the call Winger goes silent and keeps listening on the phone. A scream or a cry for help makes it ask "Are you okay?". No answer alerts your guardians.'),
    (WIcons.route, W.leaf, 'Set route',
        'Pick where you are going. Winger stays quiet unless you leave the route, stop too long or run late.'),
    (WIcons.locker, W.indigo, 'Locker',
        'Location, sound and photos are encrypted and chained as they are recorded. Any change to the record shows.'),
    (WIcons.message, W.plum, 'Help chat',
        'Step-by-step guides for blackmail, stalking, harassment and more, with the right helplines. Works offline.'),
    (WIcons.key, W.sos, 'Two PINs',
        'Your PIN stops everything and tells guardians you are safe. The duress PIN looks the same but keeps alerting in secret.'),
  ];

  static const _colors = [
    (W.watching, 'Green', 'Watching. All quiet.'),
    (W.checking, 'Orange', 'Checking on you.'),
    (W.alerting, 'Red', 'Alerting your guardians or 112.'),
    (W.silentHelp, 'Yellow', 'Silent help is on its way.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('How Winger works')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          for (final (icon, color, title, body) in _cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TintIcon(icon, color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(body, style: const TextStyle(color: W.text2, height: 1.4)),
                    ]),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          const Text('The line at the top', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 10),
          WCard(
            child: Column(children: [
              for (final (c, name, meaning) in _colors)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(width: 36, height: 6, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 12),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(meaning, style: const TextStyle(color: W.text2))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          const Text(honestCopy, textAlign: TextAlign.center, style: TextStyle(color: W.text2, fontSize: 12)),
        ]),
      );
}
