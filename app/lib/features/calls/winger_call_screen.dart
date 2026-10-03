import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/strings_family.dart';
import '../../core/widgets/rx_logo.dart';
import 'call_voice.dart';

enum CallKind { medicine, checkIn }

enum Feeling { fine, unwell, help }

/// A call from Winger, drawn like the phone's own incoming call: it rings,
/// she answers, and Winger speaks. Built for someone who will not read a
/// notification but will always pick up a ringing phone.
///
/// The voice is the ElevenLabs companion agent when it is reachable, and the
/// phone's own voice otherwise. Every answer is also a big button, so the
/// call works even if nothing is heard.
class WingerCallScreen extends StatefulWidget {
  const WingerCallScreen({
    super.key,
    required this.kind,
    required this.patientName,
    required this.language,
    this.medicines = const [],
    this.onTook,
    this.onLater,
    this.onFeeling,
    this.voice,
  });

  final CallKind kind;
  final String patientName;
  final AppLanguage language;
  final List<String> medicines;

  /// "I took them": the caller opens the per-medicine confirmation.
  final Future<void> Function()? onTook;
  final Future<void> Function()? onLater;
  final Future<void> Function(Feeling feeling)? onFeeling;

  /// Injected by tests.
  final CallVoice? voice;

  @override
  State<WingerCallScreen> createState() => _WingerCallScreenState();
}

enum _Phase { ringing, connected, done }

class _WingerCallScreenState extends State<WingerCallScreen> {
  late final CallVoice _voice = widget.voice ?? CallVoice();
  _Phase _phase = _Phase.ringing;
  Timer? _ring;
  Timer? _clock;
  DateTime? _answeredAt;
  String _caption = '';
  String _closing = '';

  AppStrings get s => AppStrings(widget.language);

  @override
  void initState() {
    super.initState();
    // A gentle buzz pattern while ringing.
    _ring = Timer.periodic(const Duration(milliseconds: 1400), (_) => HapticFeedback.heavyImpact());
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  @override
  void dispose() {
    _ring?.cancel();
    _clock?.cancel();
    _voice.end();
    super.dispose();
  }

  String get _opening => widget.kind == CallKind.medicine
      ? s.medicineLine(widget.patientName, widget.medicines)
      : s.checkInLine(widget.patientName);

  Future<void> _answer() async {
    _ring?.cancel();
    setState(() {
      _phase = _Phase.connected;
      _answeredAt = DateTime.now();
      _caption = s.callConnecting;
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    _voice.onAgentText = (t) {
      if (mounted) setState(() => _caption = t);
    };
    final live = await _voice.connectAgent(
      variables: {
        'user_name': widget.patientName,
        'language': widget.language == AppLanguage.hi ? 'Hindi' : 'English',
        'call_kind': widget.kind == CallKind.medicine ? 'medicine' : 'check_in',
        'medicines': widget.medicines.join(', '),
      },
      tools: {
        'confirm_taken': (_) async {
          unawaited(_took());
          return 'Opening the confirmation on screen.';
        },
        'remind_later': (_) async {
          unawaited(_later());
          return 'Will remind again.';
        },
        'report_feeling': (p) async {
          final f = '${p['feeling'] ?? ''}'.toLowerCase();
          unawaited(_feeling(f.contains('help') ? Feeling.help : f.contains('unwell') || f.contains('not') ? Feeling.unwell : Feeling.fine));
          return 'Noted.';
        },
      },
      onLost: () {},
    );
    if (!mounted) return;
    if (!live) {
      setState(() => _caption = _opening);
      await _voice.say(_opening, widget.language);
    }
  }

  Future<void> _decline() async {
    _ring?.cancel();
    await widget.onLater?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _finish(String line) async {
    setState(() {
      _phase = _Phase.done;
      _closing = line;
      _caption = line;
    });
    if (!_voice.live) await _voice.say(line, widget.language);
  }

  Future<void> _took() async {
    _voice.tell('She pressed: I took them.');
    // Never wait on audio to move on: the confirmation matters more.
    unawaited(_voice.end());
    if (!mounted) return;
    Navigator.of(context).maybePop();
    await widget.onTook?.call();
  }

  Future<void> _later() async {
    _voice.tell('She pressed: remind me later.');
    await widget.onLater?.call();
    if (mounted) await _finish(s.laterLine);
  }

  Future<void> _feeling(Feeling f) async {
    _voice.tell('She says she is ${f.name}.');
    await widget.onFeeling?.call(f);
    if (mounted) await _finish(f == Feeling.fine ? s.thanksLine : s.unwellLine);
  }

  String get _timer {
    final a = _answeredAt;
    if (a == null) return '';
    final d = DateTime.now().difference(a);
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.kind == CallKind.medicine ? s.callMedicine : s.callCheckIn;
    return PopScope(
      canPop: _phase != _Phase.ringing,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2B1A12), Color(0xFF120B08)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    _phase == _Phase.ringing ? s.callIncoming : _timer,
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(s.callerName, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Color(0xFFFFB46B), fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 32),
                  _Avatar(pulsing: _phase == _Phase.ringing),
                  const SizedBox(height: 24),
                  if (_phase != _Phase.ringing)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _caption,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.4),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(height: 16),
                  ..._controls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _controls() {
    switch (_phase) {
      case _Phase.ringing:
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundButton(color: const Color(0xFFD93025), icon: Icons.call_end, label: s.callDecline, onTap: _decline),
              _RoundButton(key: const Key('call-answer'), color: const Color(0xFF1E8E3E), icon: Icons.call, label: s.callAnswer, onTap: _answer, big: true),
            ],
          ),
          const SizedBox(height: 16),
        ];
      case _Phase.connected:
        return [
          if (widget.kind == CallKind.medicine) ...[
            _AnswerButton(key: const Key('call-took'), label: s.callTookThem, color: const Color(0xFF1E8E3E), onTap: _took),
            const SizedBox(height: 12),
            _AnswerButton(label: s.callLater, color: const Color(0xFF5F6368), onTap: _later),
          ] else ...[
            _AnswerButton(label: s.callFeelGood, color: const Color(0xFF1E8E3E), onTap: () => _feeling(Feeling.fine)),
            const SizedBox(height: 12),
            _AnswerButton(label: s.callFeelUnwell, color: const Color(0xFFE37400), onTap: () => _feeling(Feeling.unwell)),
            const SizedBox(height: 12),
            _AnswerButton(label: s.callNeedHelp, color: const Color(0xFFD93025), onTap: () => _feeling(Feeling.help)),
          ],
          const SizedBox(height: 16),
          _RoundButton(color: const Color(0xFFD93025), icon: Icons.call_end, label: s.callEnd, onTap: () => Navigator.of(context).maybePop()),
        ];
      case _Phase.done:
        return [
          if (_closing.isNotEmpty) const SizedBox(height: 8),
          _RoundButton(color: const Color(0xFFD93025), icon: Icons.call_end, label: s.callEnd, onTap: () => Navigator.of(context).maybePop()),
        ];
    }
  }
}

class _Avatar extends StatefulWidget {
  const _Avatar({required this.pulsing});
  final bool pulsing;
  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final t = widget.pulsing ? _c.value : 0.0;
      return SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulsing)
              Container(
                width: 130 + 70 * t,
                height: 130 + 70 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFA94D).withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(32)),
              child: Image(image: AssetImage(RxLogo.asset), width: 130, height: 130),
            ),
          ],
        ),
      );
    },
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.color, required this.icon, required this.label, required this.onTap, this.big = false});
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 84.0 : 72.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: label,
          child: Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: size, height: size, child: Icon(icon, color: Colors.white, size: size * 0.45)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({super.key, required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 64,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onTap,
      child: Text(label),
    ),
  );
}
