import 'package:flutter/material.dart';

import '../config.dart';
import '../core/pin_vault.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Three steps: name and voice language; guardians; PINs and Home mode.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  String _lang = 'en';
  bool _homeMode = false;
  String? _error;
  final _name = TextEditingController(text: isDemo ? Demo.name : '');
  final _g1Name = TextEditingController(text: isDemo ? Demo.guardianName : '');
  final _g1Phone = TextEditingController(text: isDemo ? Demo.guardianPhone : '');
  final _g2Name = TextEditingController();
  final _g2Phone = TextEditingController();
  final _pin = TextEditingController(text: isDemo ? Demo.pin : '');
  final _duress = TextEditingController(text: isDemo ? Demo.duressPin : '');

  bool _phoneOk(String p) => RegExp(r'^\+?[\d\s-]{8,16}$').hasMatch(p.trim());

  void _next() {
    String? err;
    switch (_step) {
      case 0:
        if (_name.text.trim().isEmpty) err = 'Tell us your name.';
      case 1:
        if (_g1Name.text.trim().isEmpty || !_phoneOk(_g1Phone.text)) {
          err = 'Add at least one guardian with a phone number.';
        } else if (_g2Phone.text.trim().isNotEmpty && !_phoneOk(_g2Phone.text)) {
          err = "Guardian 2's number looks wrong.";
        }
      case 2:
        if (!PinVault.validPin(_pin.text) || !PinVault.validPin(_duress.text)) {
          err = 'PINs are 4 to 8 digits.';
        } else if (_pin.text == _duress.text) {
          err = 'Your PIN and duress PIN must differ.';
        }
    }
    setState(() => _error = err);
    if (err != null) return;
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    AppScope.read(context).finishOnboarding(
      name: _name.text,
      lang: _lang,
      guardians: [
        Guardian(_g1Name.text.trim(), _g1Phone.text.trim()),
        if (_g2Phone.text.trim().isNotEmpty)
          Guardian(_g2Name.text.trim().isEmpty ? 'Guardian 2' : _g2Name.text.trim(),
              _g2Phone.text.trim()),
      ],
      pin: _pin.text,
      duress: _duress.text,
      homeMode: _homeMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [_stepName(), _stepGuardians(), _stepPins()];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(children: [
            Row(children: [
              IconButton(
                onPressed: _step == 0 ? null : () => setState(() => _step--),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= _step ? W.plum : W.containerHigh,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text('${_step + 1}/3',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: W.text2)),
            ]),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 32),
                child: steps[_step],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: W.sos)),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _next,
                child: Text(_step == 2 ? 'Finish' : 'Continue'),
              ),
            ),
            const SizedBox(height: 10),
            const Text(honestCopy,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: W.text2)),
          ]),
        ),
      ),
    );
  }

  Widget _header(IconData icon, Color color, String title, String body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon(icon, color, size: 64),
          const SizedBox(height: 24),
          Text(title,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 16, color: W.text2, height: 1.45)),
          const SizedBox(height: 24),
        ],
      );

  Widget _stepName() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(WIcons.profile, W.leaf, 'Who are we protecting?',
            "Winger stays quiet, notices when something looks wrong, asks if you're okay, and gets help if you can't answer."),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(WIcons.user)),
        ),
        const SizedBox(height: 20),
        const Text('Voice language', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'hi', label: Text('हिन्दी')),
            ],
            selected: {_lang},
            onSelectionChanged: (s) => setState(() => _lang = s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: W.plum,
              selectedForegroundColor: Colors.white,
              minimumSize: const Size(0, 52),
            ),
          ),
        ),
      ]);

  Widget _stepGuardians() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(WIcons.people, W.magenta, 'Who should we tell?',
            'Guardians get a plain SMS with your location when you need help. They need no app.'),
        const Text('Guardian 1', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _g1Name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(
            controller: _g1Phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 20),
        const Text('Guardian 2 (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _g2Name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(
            controller: _g2Phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone')),
      ]);

  Widget _stepPins() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(WIcons.key, W.indigo, 'Two PINs',
            'Your PIN stops an alert and opens Winger. The duress PIN looks exactly the same, but keeps alerting your guardians in secret.'),
        TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(labelText: 'PIN (4 to 8 digits)')),
        const SizedBox(height: 6),
        TextField(
            controller: _duress,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(labelText: 'Duress PIN')),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _homeMode,
          onChanged: (v) => setState(() => _homeMode = v),
          title: const Text('Home mode', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Silent alerts only, for an unsafe home.'),
        ),
      ]);
}
