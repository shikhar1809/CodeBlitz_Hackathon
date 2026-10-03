import 'package:flutter/material.dart';

import '../core/clock.dart';
import '../core/schedule.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Demo builds only (long-press the version in Profile): move the in-app
/// clock so a "+60 min" ladder shows in seconds, without changing the real
/// windows.
class DemoPanel extends StatelessWidget {
  const DemoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final clock = app.clock;
    final offset = clock is DemoClock ? clock.offset : Duration.zero;
    final now = app.now();
    Widget action(IconData icon, String title, String sub, VoidCallback onTap) => ListTile(
          leading: TintIcon(icon, W.indigo, size: 44),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(sub),
          onTap: onTap,
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Demo panel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(
                'App time ${DayTime(now.hour, now.minute).label}'
                '${offset == Duration.zero ? '' : ' (+${offset.inMinutes} min)'}',
                style: const TextStyle(color: W.text2),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          action(WIcons.timer, 'Skip 30 min', 'Moves the app clock forward', () => app.skipTime(const Duration(minutes: 30))),
          action(WIcons.alarm, 'Jump to next dose', 'The next dose becomes due now', () {
            if (!app.jumpToNextDose()) app.showBanner('No dose scheduled');
            Navigator.pop(context);
          }),
          action(WIcons.pill, 'Seed demo household', 'Prescription Agent with a checked prescription and a family contact', () {
            app.doses.seedDemo();
            app.homeTab = 'prescription';
            Navigator.pop(context);
          }),
          action(WIcons.trash, 'Reset demo', 'Back to first run', () async {
            final nav = Navigator.of(context);
            await app.resetDemo();
            nav.popUntil((r) => r.isFirst);
          }),
        ]),
      ),
    );
  }
}
