import 'package:flutter/material.dart';

import '../config.dart';
import '../core/pin_vault.dart';
import '../state/app_state.dart';
import 'coming_soon_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// First run: pick what Winger should help with, then only the steps that
/// preset needs.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _preset;
  int _step = 0;
  String _lang = 'en';
  bool _homeMode = false;
  bool _caregiver = false;
  bool _seedDemo = isDemo;
  String? _error;
  final _name = TextEditingController(text: isDemo ? Demo.name : '');
  final _patient = TextEditingController(text: isDemo ? 'Kamla (Grandma)' : '');
  final _g1Name = TextEditingController(text: isDemo ? Demo.guardianName : '');
  final _g1Phone = TextEditingController(text: isDemo ? Demo.guardianPhone : '');
  final _g2Name = TextEditingController();
  final _g2Phone = TextEditingController();
  final _famName = TextEditingController(text: isDemo ? 'Rahul (son)' : '');
  final _famPhone = TextEditingController(text: isDemo ? '+91 98000 00002' : '');
  final _pin = TextEditingController(text: isDemo ? Demo.pin : '');
  final _duress = TextEditingController(text: isDemo ? Demo.duressPin : '');

  bool get _women => _preset == 'women';

  List<String> get _steps => [
        'pick',
        'name',
        'contacts',
        if (_women) 'pins',
        if (_preset == 'prescription') 'meds',
      ];

  bool _phoneOk(String p) => RegExp(r'^\+?[\d\s-]{8,16}$').hasMatch(p.trim());

  String? _check(String step) {
    switch (step) {
      case 'pick':
        if (_preset == null) return 'Pick one to start. You can add more later.';
      case 'name':
        if (_name.text.trim().isEmpty) return 'Tell us your name.';
        if (_caregiver && _patient.text.trim().isEmpty) return 'Who are the medicines for?';
      case 'contacts':
        if (_women) {
          if (_g1Name.text.trim().isEmpty || !_phoneOk(_g1Phone.text)) {
            return 'Add at least one guardian with a phone number.';
          }
          if (_g2Phone.text.trim().isNotEmpty && !_phoneOk(_g2Phone.text)) return "Guardian 2's number looks wrong.";
        } else if (_famPhone.text.trim().isNotEmpty && !_phoneOk(_famPhone.text)) {
          return 'That phone number looks wrong.';
        }
      case 'pins':
        if (!PinVault.validPin(_pin.text) || !PinVault.validPin(_duress.text)) return 'PINs are 4 to 8 digits.';
        if (_pin.text == _duress.text) return 'Your PIN and duress PIN must differ.';
    }
    return null;
  }

  void _next() {
    final err = _check(_steps[_step]);
    setState(() => _error = err);
    if (err != null) return;
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      return;
    }
    final app = AppScope.read(context);
    final contacts = <Guardian>[
      if (_women) Guardian(_g1Name.text.trim(), _g1Phone.text.trim()),
      if (_women && _g2Phone.text.trim().isNotEmpty)
        Guardian(_g2Name.text.trim().isEmpty ? 'Guardian 2' : _g2Name.text.trim(), _g2Phone.text.trim()),
      if (!_women && _famPhone.text.trim().isNotEmpty)
        Guardian(_famName.text.trim().isEmpty ? 'Family' : _famName.text.trim(), _famPhone.text.trim(), 'family'),
    ];
    app.settings.patientName = _caregiver ? _patient.text.trim() : null;
    app.finishOnboarding(
      name: _name.text,
      lang: _lang,
      guardians: contacts,
      pin: _women ? _pin.text : null,
      duress: _women ? _duress.text : null,
      homeMode: _homeMode,
      presets: [_preset!],
      caregiver: _caregiver,
    );
    if (_preset == 'prescription' && _seedDemo) app.doses.seedDemo();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final body = switch (step) {
      'pick' => _stepPick(),
      'name' => _stepName(),
      'contacts' => _women ? _stepGuardians() : _stepFamily(),
      'pins' => _stepPins(),
      _ => _stepMeds(),
    };
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
              for (var i = 0; i < _steps.length; i++)
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
              Text('${_step + 1}/${_steps.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: W.text2)),
            ]),
            Expanded(
              child: SingleChildScrollView(padding: const EdgeInsets.only(top: 28), child: body),
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
                child: Text(_step == _steps.length - 1 ? 'Finish' : 'Continue'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _preset == 'prescription' ? 'Not medical advice. Follow your doctor.' : honestCopy,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: W.text2),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _header(IconData icon, Color color, String title, String body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintIcon(icon, color, size: 64),
          const SizedBox(height: 22),
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 16, color: W.text2, height: 1.45)),
          const SizedBox(height: 22),
        ],
      );

  Widget _stepPick() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('What should Winger help with?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
        const SizedBox(height: 8),
        const Text('One wingman that notices and asks. Pick a job to start; you can add the others later.',
            style: TextStyle(fontSize: 16, color: W.text2, height: 1.45)),
        const SizedBox(height: 20),
        for (final p in presetCards)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PresetCard(
              card: p,
              selected: _preset == p.id,
              onTap: () {
                if (p.comingSoon) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComingSoonScreen(card: p)));
                } else {
                  setState(() {
                    _preset = p.id;
                    _error = null;
                  });
                }
              },
            ),
          ),
      ]);

  Widget _stepName() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _women
            ? _header(WIcons.profile, W.leaf, 'Who are we protecting?',
                "Winger stays quiet, notices when something looks wrong, asks if you're okay, and gets help if you can't answer.")
            : _header(WIcons.pill, W.indigo, 'Who is this for?',
                'Winger reminds at each dose, checks it was taken, and tells family if a dose is missed.'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(WIcons.user)),
        ),
        if (!_women) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('For me')),
                ButtonSegment(value: true, label: Text('Someone I care for')),
              ],
              selected: {_caregiver},
              onSelectionChanged: (s) => setState(() => _caregiver = s.first),
              style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: W.plum, selectedForegroundColor: Colors.white, minimumSize: const Size(0, 52)),
            ),
          ),
          if (_caregiver) ...[
            const SizedBox(height: 12),
            TextField(controller: _patient, decoration: const InputDecoration(labelText: 'Their name')),
          ],
        ],
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
            controller: _g1Phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 20),
        const Text('Guardian 2 (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _g2Name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(
            controller: _g2Phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
      ]);

  Widget _stepFamily() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(WIcons.people, W.magenta, 'Who should know about a missed dose?',
            'If a dose is not confirmed within an hour, Winger texts this person from the phone. They need no app.'),
        TextField(controller: _famName, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(
            controller: _famPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone (optional)')),
      ]);

  Widget _stepPins() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(WIcons.key, W.indigo, 'Two PINs',
            'Your PIN stops an alert. The duress PIN looks exactly the same, but keeps alerting your guardians in secret.'),
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

  Widget _stepMeds() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(WIcons.pill, W.leaf, 'The first prescription',
            'Add each medicine exactly as the doctor wrote it. Winger never guesses a dose, and nothing is scheduled until you approve it.'),
        if (isDemo)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _seedDemo,
            onChanged: (v) => setState(() => _seedDemo = v ?? false),
            title: const Text('Use the demo prescription', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Metformin, Amlodipine and Atorvastatin, at 9 AM and 9 PM'),
          ),
        const SizedBox(height: 8),
        const Text('You can add medicines any time from Home.', style: TextStyle(color: W.text2)),
      ]);
}

/// What the picker and the switcher show for each preset.
class PresetCardData {
  final String id;
  final String name;
  final String tagline;
  final String detail;
  final IconData icon;
  final List<Color> colors;
  final bool comingSoon;
  const PresetCardData(this.id, this.name, this.tagline, this.detail, this.icon, this.colors, {this.comingSoon = false});
}

const presetCards = [
  PresetCardData('women', 'Women Companion', 'Getting home safe',
      'A friend calls and stays. Safe phrases, check-ins, guardians alerted.', WIcons.shield, W.orange),
  PresetCardData('prescription', 'Prescription Agent', 'Right medicine, on time',
      'Reminds at each dose, confirms each pill, tells family if one is missed.', WIcons.pill, W.green),
  PresetCardData('adhd', 'ADHD Companion', 'Starting and finishing',
      'A tiny first step, "started yet?", and a body-double call.', WIcons.flash, W.violet,
      comingSoon: true),
];

class PresetCard extends StatelessWidget {
  final PresetCardData card;
  final bool selected;
  final VoidCallback onTap;
  const PresetCard({super.key, required this.card, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: selected ? W.plum : Colors.transparent, width: 2),
        ),
        child: WCard(
          radius: 24,
          onTap: onTap,
          child: Row(children: [
            GradientIcon(card.icon, card.colors, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(card.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  if (card.comingSoon) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: W.containerHigh, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Coming soon', style: TextStyle(fontSize: 11, color: W.text2)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(card.tagline, style: const TextStyle(color: W.plum, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(card.detail, style: const TextStyle(color: W.text2, fontSize: 13, height: 1.35)),
              ]),
            ),
            if (selected) const Icon(WIcons.tick, color: W.plum),
          ]),
        ),
      );
}
