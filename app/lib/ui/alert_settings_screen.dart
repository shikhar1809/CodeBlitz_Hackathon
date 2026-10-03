import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'phrases_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class AlertSettingsScreen extends StatelessWidget {
  const AlertSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Widget row(IconData icon, Color color, String title, String sub,
            {VoidCallback? onTap, Widget? trailing}) =>
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: TintIcon(icon, color),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub, style: const TextStyle(color: W.text2)),
          trailing: trailing ?? (onTap == null ? null : const Icon(Icons.arrow_right, color: W.text2)),
          onTap: onTap,
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Alert settings')),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        row(WIcons.mic, W.magenta, 'Safe phrases', 'Add a phrase, record it in your voice, test it',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhrasesScreen()))),
        row(WIcons.keypad, W.indigo, 'Keypad code',
            app.vault.hasCode
                ? 'Your own code is set. Dial it then # on a call.'
                : 'On a call, dial your PIN then # to cancel a false alarm',
            onTap: () => showModalBottomSheet(
                context: context, isScrollControlled: true, builder: (_) => const _CodeSheet())),
        row(WIcons.shake, W.marigold, 'Shake to start', 'Three hard shakes while Winger is open',
            trailing: Switch(
                value: app.settings.shakeToStart,
                onChanged: (v) => app.update((s) => s.shakeToStart = v))),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          shape: const Border(),
          title: const Text('More tools', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          children: [
            row(WIcons.call, W.leaf, 'Fake call', 'A call from "Mom" to get you out of a situation',
                onTap: () => _soon(context, 'Fake call')),
            if (!app.settings.homeMode)
              row(WIcons.speaker, W.sos, 'Deterrent', 'Loud "recording started, police informed"',
                  onTap: () => _soon(context, 'Deterrent')),
            row(WIcons.walk, W.coral, 'Followed', 'Record now, check in every 2 minutes',
                onTap: () => _soon(context, 'Followed')),
            row(WIcons.activity, W.indigo, 'Stalked', 'Dated incident log and PDF report',
                onTap: () => _soon(context, 'Stalked')),
            row(WIcons.home3, W.magenta, 'Home mode', 'Silent alerts only',
                trailing: Switch(
                    value: app.settings.homeMode, onChanged: (v) => app.update((s) => s.homeMode = v))),
          ],
        ),
      ]),
    );
  }

  static void _soon(BuildContext context, String what) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('$what is coming in the next build')));
}

class _CodeSheet extends StatefulWidget {
  const _CodeSheet();
  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _code = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Keypad code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
            'On a call, open Keypad, dial this code and then #. Everything stops and your guardians are told you are safe. Without a code, your PIN works.',
            style: TextStyle(color: W.text2)),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: InputDecoration(labelText: '3 to 8 digits', errorText: _error),
        ),
        const SizedBox(height: 8),
        Row(children: [
          if (app.vault.hasCode)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  app.setCode(null);
                  Navigator.pop(context);
                },
                child: const Text('Use my PIN'),
              ),
            ),
          if (app.vault.hasCode) const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                try {
                  app.setCode(_code.text);
                  Navigator.pop(context);
                } on ArgumentError catch (e) {
                  setState(() => _error = e.message as String);
                }
              },
              child: const Text('Save code'),
            ),
          ),
        ]),
      ]),
    );
  }
}
