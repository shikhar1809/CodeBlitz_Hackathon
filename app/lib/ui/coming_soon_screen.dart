import 'package:flutter/material.dart';

import 'onboarding_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// One-screen preview for a preset that is not built yet. Never a dead end.
class ComingSoonScreen extends StatelessWidget {
  final PresetCardData card;
  const ComingSoonScreen({super.key, required this.card});

  static const _adhdSteps = [
    ('9:30 AM', 'Time to start: open the laptop and write one line', 'Tiny first step'),
    ('9:40 AM', 'Started yet? Two snoozes, no guilt', 'Gentle nudge'),
    ('9:50 AM', 'Want a body double? A friend calls and works alongside you', 'Same call screen as Riya'),
    ('10:15 AM', 'Your buddy gets a light "how\'s it going?"', 'Only if you opted in'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(card.name)),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Row(children: [
            GradientIcon(card.icon, card.colors, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(card.tagline, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const Text('Preview: coming soon', style: TextStyle(color: W.text2)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Text(card.detail, style: const TextStyle(fontSize: 16, height: 1.45)),
          const SizedBox(height: 16),
          const Text('How a task will go', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 10),
          for (final (time, what, why) in _adhdSteps)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WCard(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                      width: 72, child: Text(time, style: const TextStyle(fontWeight: FontWeight.w700, color: W.plum))),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(what, style: const TextStyle(fontSize: 15)),
                      Text(why, style: const TextStyle(color: W.text2, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          const Text('No streaks to lose, no red, no "failed". Done is one tap and gets celebrated.',
              style: TextStyle(color: W.text2)),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          const SizedBox(height: 10),
          const Text('A companion, not a treatment.',
              textAlign: TextAlign.center, style: TextStyle(color: W.text2, fontSize: 12)),
        ]),
      );
}
