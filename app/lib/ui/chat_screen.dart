import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/help_guide.dart';
import '../services/chat_agent.dart';
import '../state/app_state.dart';
import 'theme.dart';

class _Msg {
  final bool mine;
  final String text;
  final Guide? guide;
  final bool urgent;
  _Msg(this.mine, this.text, {this.guide, this.urgent = false});
}

/// Help chat: bundled guides answer on the phone; the ElevenLabs text agent
/// tailors them when online. Nothing is saved.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _starters = [
    'Someone is blackmailing me',
    'I am being followed',
    'My photos were morphed',
    'Police refused my FIR',
    'Harassment at work',
    'Violence at home',
  ];

  HelpGuide? _guides;
  final _agent = ChatAgent();
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [
    _Msg(false,
        "Tell me what happened, in your own words. I'll give you clear steps and the right numbers to call. If you are in danger right now, call 112."),
  ];
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/config/guides.json').then((s) => setState(() => _guides = HelpGuide.parse(s)));
  }

  @override
  void dispose() {
    _agent.close();
    super.dispose();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _send(String message, {bool tailor = false, Guide? forGuide}) async {
    message = message.trim();
    if ((message.isEmpty && !tailor) || _guides == null) return;
    _text.clear();
    final urgent = HelpGuide.isUrgent(message);
    final guide = forGuide ?? _guides!.match(message);
    setState(() {
      if (!tailor) _msgs.add(_Msg(true, message));
      _thinking = true;
    });
    _toEnd();

    // A matching guide in English answers from the phone, no network.
    if (guide != null && !tailor && HelpGuide.isEnglish(message)) {
      setState(() {
        _msgs.add(_Msg(false, '', guide: guide, urgent: urgent));
        _thinking = false;
      });
      _toEnd();
      return;
    }
    try {
      final reply = await _agent.ask(
        tailor ? 'Fit these steps to my situation: ${_lastMine()}' : message,
        guide: guide,
        language: AppScope.read(context).settings.lang,
      );
      setState(() => _msgs.add(_Msg(false, reply, urgent: urgent)));
    } catch (_) {
      setState(() => _msgs.add(guide != null
          ? _Msg(false, '', guide: guide, urgent: urgent)
          : _Msg(false,
              "I don't have a guide for that on this phone. If you are in danger, call 112. For anything online, call 1930. The women helpline 181 can advise on everything else.",
              urgent: urgent)));
    }
    setState(() => _thinking = false);
    _toEnd();
  }

  String _lastMine() => _msgs.lastWhere((m) => m.mine, orElse: () => _Msg(true, '')).text;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Help'),
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: W.sos, minimumSize: const Size(0, 44)),
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
                icon: const Icon(WIcons.call),
                label: const Text('Call 112'),
              ),
            ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
              for (final m in _msgs) _bubble(m),
              if (_msgs.length == 1)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in _starters) ActionChip(label: Text(s), onPressed: () => _send(s)),
                ]),
              if (_thinking)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  onSubmitted: (t) => _send(t),
                  decoration: InputDecoration(
                    hintText: 'What happened?',
                    fillColor: W.containerHigh,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    enabledBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: W.plum, minimumSize: const Size(50, 50)),
                onPressed: () => _send(_text.text),
                icon: const Icon(WIcons.send, color: Colors.white),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('General information, not legal advice. Not saved on this phone.',
                style: TextStyle(fontSize: 11, color: W.text2)),
          ),
        ]),
      );

  Widget _bubble(_Msg m) {
    if (m.mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: W.plum, borderRadius: BorderRadius.circular(20)),
          child: Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ),
      );
    }
    final g = m.guide;
    final helplines = g?.helplines ??
        (m.urgent ? const [Helpline('Police', '112')] : const <Helpline>[]);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: W.card, borderRadius: BorderRadius.circular(22), boxShadow: W.shadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m.urgent)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('If you are in danger right now, call 112 first.',
                style: TextStyle(color: W.sos, fontWeight: FontWeight.w700)),
          ),
        if (g != null) ...[
          Text(g.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 10),
          for (var i = 0; i < g.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 26,
                    child: Text('${i + 1}.',
                        style: const TextStyle(color: W.plum, fontWeight: FontWeight.w800, fontSize: 16))),
                Expanded(child: Text(g.steps[i], style: const TextStyle(fontSize: 16, height: 1.45))),
              ]),
            ),
        ] else
          Text(m.text, style: const TextStyle(fontSize: 16, height: 1.45)),
        if (helplines.isNotEmpty) const SizedBox(height: 4),
        for (final h in helplines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44), foregroundColor: W.plum, side: const BorderSide(color: W.outline)),
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: h.number)),
              icon: const Icon(WIcons.call, size: 18),
              label: Text('${h.name} · ${h.number}'),
            ),
          ),
        if (g != null && _agent.configured)
          TextButton(
            onPressed: () => _send('', tailor: true, forGuide: g),
            child: const Text('Fit this to my situation'),
          ),
      ]),
    );
  }
}
