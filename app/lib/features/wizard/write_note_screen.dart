import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';

/// A full page to write what was said.
///
/// A three-line box inside the step was too small to read back an instruction
/// with several medicines in it, so writing gets the whole screen.
class WriteNoteScreen extends StatefulWidget {
  const WriteNoteScreen({super.key, required this.initial, this.title});

  final String initial;
  final String? title;

  @override
  State<WriteNoteScreen> createState() => _WriteNoteScreenState();
}

class _WriteNoteScreenState extends State<WriteNoteScreen> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return VoicePrompt(
      text: widget.title ?? s.writeNoteTitle,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title ?? s.writeNoteTitle)),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: AppTheme.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    autofocus: true,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 22, height: 1.4),
                    decoration: InputDecoration(hintText: s.writeNoteHint),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: Text(s.done),
                  onPressed: () => Navigator.pop(context, _text.text.trim()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
