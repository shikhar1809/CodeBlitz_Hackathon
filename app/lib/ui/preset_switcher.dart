import 'package:flutter/material.dart';

import '../config.dart';
import '../core/pin_vault.dart';
import '../state/app_state.dart';
import 'coming_soon_screen.dart';
import 'onboarding_screen.dart';
import 'theme.dart';

/// Chips under the Home header: one per enabled preset, plus "Add".
class PresetSwitcher extends StatelessWidget {
  const PresetSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final enabled = presetCards.where((c) => app.enabled(c.id)).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: SizedBox(
        height: 42,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          if (enabled.length > 1)
            for (final c in enabled)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(c.icon, size: 18, color: app.homeTab == c.id ? Colors.white : c.colors.last),
                  label: Text(c.name.split(' ').first),
                  selected: app.homeTab == c.id,
                  showCheckmark: false,
                  selectedColor: W.plum,
                  labelStyle: TextStyle(
                      color: app.homeTab == c.id ? Colors.white : W.text, fontWeight: FontWeight.w600),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: W.outline),
                  onSelected: (_) => app.homeTab = c.id,
                ),
              ),
          if (enabled.length < presetCards.length)
            ActionChip(
              avatar: const Icon(Icons.add, size: 18, color: W.plum),
              label: Text(enabled.length > 1 ? 'Add' : 'Add a preset'),
              backgroundColor: Colors.white,
              side: const BorderSide(color: W.outline),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const AddPresetSheet(),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Pick another preset to add to this phone.
class AddPresetSheet extends StatelessWidget {
  const AddPresetSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final more = presetCards.where((c) => !app.enabled(c.id)).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add to Winger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Same engine, different job.', style: TextStyle(color: W.text2)),
          const SizedBox(height: 14),
          for (final c in more)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PresetCard(
                card: c,
                selected: false,
                onTap: () async {
                  final nav = Navigator.of(context);
                  if (c.comingSoon) {
                    nav.push(MaterialPageRoute(builder: (_) => ComingSoonScreen(card: c)));
                    return;
                  }
                  if (c.id == 'women' && !app.vault.isSet) {
                    nav.pop();
                    nav.push(MaterialPageRoute(builder: (_) => const EnableWomenScreen()));
                    return;
                  }
                  app.enablePreset(c.id);
                  if (c.id == 'prescription' && isDemo && app.doses.book.medicines.isEmpty) app.doses.seedDemo();
                  nav.pop();
                },
              ),
            ),
        ]),
      ),
    );
  }
}

/// Women Companion needs a guardian and two PINs before it can be on.
class EnableWomenScreen extends StatefulWidget {
  const EnableWomenScreen({super.key});
  @override
  State<EnableWomenScreen> createState() => _EnableWomenScreenState();
}

class _EnableWomenScreenState extends State<EnableWomenScreen> {
  final _gName = TextEditingController(text: isDemo ? Demo.guardianName : '');
  final _gPhone = TextEditingController(text: isDemo ? Demo.guardianPhone : '');
  final _pin = TextEditingController(text: isDemo ? Demo.pin : '');
  final _duress = TextEditingController(text: isDemo ? Demo.duressPin : '');
  String? _error;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Women Companion')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('A guardian gets an SMS with your location when you need help. Your two PINs stop an alert; the duress PIN keeps alerting in secret.',
              style: TextStyle(color: W.text2, height: 1.4)),
          const SizedBox(height: 16),
          TextField(controller: _gName, decoration: const InputDecoration(labelText: 'Guardian name')),
          const SizedBox(height: 10),
          TextField(
              controller: _gPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Guardian phone')),
          const SizedBox(height: 10),
          TextField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN (4 to 8 digits)')),
          const SizedBox(height: 10),
          TextField(
              controller: _duress,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duress PIN')),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: W.sos))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final app = AppScope.read(context);
              if (_gName.text.trim().isEmpty || _gPhone.text.trim().length < 8) {
                setState(() => _error = 'Add a guardian with a phone number.');
                return;
              }
              try {
                app.vault = PinVault()..setPins(_pin.text, _duress.text);
              } on ArgumentError catch (e) {
                setState(() => _error = '${e.message}');
                return;
              }
              app.settings.guardians = [
                ...app.settings.guardians,
                Guardian(_gName.text.trim(), _gPhone.text.trim()),
              ];
              app.enablePreset('women');
              Navigator.pop(context);
            },
            child: const Text('Turn on'),
          ),
        ]),
      );
}
