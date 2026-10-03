import 'dart:async';

import 'package:flutter/material.dart';

import '../core/phrase_match.dart';
import '../services/ear.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Her own safe phrases: add, record (check the recogniser hears it), test.
class PhrasesScreen extends StatefulWidget {
  const PhrasesScreen({super.key});
  @override
  State<PhrasesScreen> createState() => _PhrasesScreenState();
}

class _PhrasesScreenState extends State<PhrasesScreen> {
  final _add = TextEditingController();
  String? _error;
  String? _testResult;
  bool _listening = false;
  String? _recording;
  final Ear _ear = Ear();

  Future<String?> _listenFor(Duration d, List<String> phrases) async {
    final done = Completer<String?>();
    final ok = await _ear.start(
      phrases: phrases,
      onHeard: (e) {
        if (e.kind == Heard.safePhrase && !done.isCompleted) done.complete(e.phrase);
      },
    );
    if (!ok) return 'MIC';
    final timer = Timer(d, () {
      if (!done.isCompleted) done.complete(null);
    });
    final r = await done.future;
    timer.cancel();
    await _ear.stop();
    return r;
  }

  Future<void> _test() async {
    final app = AppScope.read(context);
    setState(() {
      _listening = true;
      _testResult = 'Listening for 8 seconds…';
    });
    final heard = await _listenFor(const Duration(seconds: 8), app.settings.phrases);
    if (!mounted) return;
    setState(() {
      _listening = false;
      _testResult = heard == 'MIC'
          ? 'The microphone is not available here.'
          : heard == null
              ? 'Did not hear a phrase. Try again a little slower.'
              : 'Heard: "$heard"';
    });
  }

  Future<void> _record(String phrase) async {
    setState(() => _recording = phrase);
    final heard = await _listenFor(const Duration(seconds: 6), [phrase]);
    if (!mounted) return;
    setState(() => _recording = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(heard == phrase
            ? 'Got it. Winger knows how you say it.'
            : heard == 'MIC'
                ? 'The microphone is not available here.'
                : "Didn't catch it. Try once more.")));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final phrases = app.settings.phrases;
    void addPhrase(String p) {
      final err = phraseProblem(p, phrases);
      setState(() => _error = err);
      if (err != null) return;
      app.update((s) => s.phrases = [...s.phrases, p.trim()]);
      _add.clear();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Safe phrases')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        const Text(
            'Say one of these out loud while Winger is on, for example in the middle of a call. Nothing changes on the phone, and your guardians are alerted silently.',
            style: TextStyle(color: W.text2, fontSize: 15, height: 1.4)),
        const SizedBox(height: 16),
        for (final p in phrases)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: Text('"$p"', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  if (phrases.length > 1)
                    IconButton(
                      icon: const Icon(WIcons.close, color: W.text2),
                      onPressed: () => app.update((s) => s.phrases = s.phrases.where((x) => x != p).toList()),
                    ),
                ]),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF7D7E8),
                      foregroundColor: W.text2,
                      minimumSize: const Size(0, 40)),
                  onPressed: _recording == null ? () => _record(p) : null,
                  icon: const Icon(WIcons.mic, size: 18),
                  label: Text(_recording == p ? 'Say it now…' : 'Record in your voice'),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        const Text('Add a phrase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _add,
              onSubmitted: addPhrase,
              decoration: InputDecoration(hintText: 'For example: Is the dog okay?', errorText: _error),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(onPressed: () => addPhrase(_add.text), child: const Text('Add')),
        ]),
        const SizedBox(height: 6),
        const Text('English words, at least three. Up to five phrases. Then record it.',
            style: TextStyle(color: W.text2, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in const ['Save me some dinner', 'I forgot my charger'])
            if (!phrases.contains(s)) ActionChip(label: Text(s), onPressed: () => addPhrase(s)),
        ]),
        const SizedBox(height: 20),
        const Text('Test', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        WCard(
          child: Column(children: [
            Text(
                _testResult ??
                    'Say one of your phrases the way you would on a call. Winger listens for 8 seconds. A test never alerts anyone.',
                style: const TextStyle(fontSize: 15, height: 1.4)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _listening ? null : _test,
                icon: const Icon(WIcons.voice),
                label: Text(_listening ? 'Listening…' : 'Start test'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
