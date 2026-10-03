import 'package:flutter/material.dart';

import '../config.dart';
import '../core/pin_vault.dart';
import '../state/app_state.dart';
import 'coming_soon_screen.dart';
import 'demo_panel.dart';
import 'help_screen.dart';
import 'onboarding_screen.dart';
import 'preset_switcher.dart';
import 'theme.dart';
import 'widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    Widget row(IconData icon, Color color, String title, String sub, Widget trailing, {VoidCallback? onTap}) =>
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: TintIcon(icon, color, size: 44),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub, style: const TextStyle(color: W.text2, fontSize: 13)),
          trailing: trailing,
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Activity log',
            icon: const Icon(WIcons.activity),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _LogScreen())),
          ),
          IconButton(
            tooltip: 'How Winger works',
            icon: const Icon(WIcons.info),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: W.brandPlum, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: W.gold,
              child: Text(s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 26, color: W.text, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const Row(children: [
                Icon(WIcons.shield, color: W.gold, size: 16),
                SizedBox(width: 4),
                Text('Protected by Winger', style: TextStyle(color: Colors.white70)),
              ]),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('Guardians', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in s.guardians)
            InputChip(
              avatar: CircleAvatar(backgroundColor: W.gold, child: Text(g.initial)),
              label: Text(g.name),
              onDeleted: s.guardians.length > 1
                  ? () => app.update((x) => x.guardians = x.guardians.where((y) => y != g).toList())
                  : null,
            ),
          if (s.guardians.length < 5)
            ActionChip(
              avatar: const Icon(WIcons.add, color: W.plum),
              label: const Text('Add'),
              onPressed: () => _addGuardian(context, app),
            ),
        ]),
        const SizedBox(height: 16),
        WCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            row(
              WIcons.language,
              W.magenta,
              'Voice language',
              s.lang == 'hi' ? 'Hindi' : 'English',
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: W.plum, selectedForegroundColor: Colors.white),
                segments: const [
                  ButtonSegment(value: 'en', label: Text('EN')),
                  ButtonSegment(value: 'hi', label: Text('हि')),
                ],
                selected: {s.lang},
                onSelectionChanged: (v) => app.update((x) => x.lang = v.first),
              ),
            ),
            row(WIcons.voice, W.indigo, 'Voice companion',
                s.voiceCompanion ? 'Winger speaks to you' : 'Silent: vibration and screen only',
                Switch(value: s.voiceCompanion, onChanged: (v) => app.update((x) => x.voiceCompanion = v))),
            row(WIcons.home3, W.leaf, 'Home location',
                s.home == null ? 'Tap to use where you are now' : '${s.home}', const Icon(Icons.my_location),
                onTap: () async {
              final p = await app.location();
              app.update((x) => x.home = p);
            }),
            row(WIcons.gallery, W.indigo, 'Home mode', 'Silent alerts only',
                Switch(value: s.homeMode, onChanged: (v) => app.update((x) => x.homeMode = v))),
            row(WIcons.flash, W.marigold, 'Demo mode', 'Simulated walk instead of GPS',
                Switch(value: s.demoMode || isDemo, onChanged: isDemo ? null : (v) => app.update((x) => x.demoMode = v))),
            if (app.vault.isSet)
              row(WIcons.key, W.sos, 'Change PINs', 'PIN and duress PIN', const Icon(Icons.arrow_right),
                onTap: () => _changePins(context, app)),
          ]),
        ),
        const SizedBox(height: 20),
        const Text('Presets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        WCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            for (final c in presetCards)
              ListTile(
                leading: GradientIcon(c.icon, c.colors, size: 40),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(c.comingSoon ? 'Coming soon' : c.tagline),
                trailing: c.comingSoon
                    ? const Icon(Icons.arrow_right)
                    : Switch(
                        value: app.enabled(c.id),
                        onChanged: (v) {
                          if (!v) return app.disablePreset(c.id);
                          showModalBottomSheet(
                              context: context, isScrollControlled: true, builder: (_) => const AddPresetSheet());
                        },
                      ),
                onTap: c.comingSoon
                    ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComingSoonScreen(card: c)))
                    : null,
              ),
          ]),
        ),
        const SizedBox(height: 20),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(WIcons.key, size: 18, color: W.text2),
          SizedBox(width: 10),
          Expanded(
            child: Text(
                'PINs stored only as salted hashes. Evidence encrypted on this phone. Location shared only during a session. No ads, no data sale.',
                style: TextStyle(color: W.text2, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onLongPress: isDemo
                ? () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const DemoPanel())
                : null,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Winger 2.1${isDemo ? ' · demo build (long-press for the demo panel)' : ''}',
                  style: const TextStyle(color: W.text2, fontSize: 12)),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _addGuardian(BuildContext context, AppState app) async {
    final name = TextEditingController(), phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add a guardian'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && phone.text.trim().length >= 8) {
      app.update((x) => x.guardians = [...x.guardians, Guardian(name.text.trim(), phone.text.trim())]);
    }
  }

  Future<void> _changePins(BuildContext context, AppState app) async {
    final old = await askPin(context, title: 'Current PIN');
    if (old == null || !context.mounted) return;
    if (app.vault.check(old) != PinResult.real) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong PIN')));
      return;
    }
    final pin = await askPin(context, title: 'New PIN');
    if (pin == null || !context.mounted) return;
    final duress = await askPin(context, title: 'New duress PIN');
    if (duress == null || !context.mounted) return;
    try {
      app.changePins(pin, duress);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs changed')));
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.message}')));
    }
  }
}

class _LogScreen extends StatelessWidget {
  const _LogScreen();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Activity log')),
      body: app.log.isEmpty
          ? const Center(child: Text('Nothing yet.'))
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final e in app.log)
                ListTile(
                  dense: true,
                  leading: Text(hhmm(e.at), style: const TextStyle(color: W.text2)),
                  title: Text(e.text),
                ),
            ]),
    );
  }
}
