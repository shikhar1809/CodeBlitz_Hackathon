import 'package:flutter/material.dart';

import '../../../core/feedback/pressable.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/strings_recording.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/mention.dart';
import '../../../platform/dictation.dart';
import '../../recording/clip_player.dart';
import '../../recording/recording_feedback.dart';
import '../../recording/recording_sessions.dart';
import '../../visit/capture_tools.dart';
import '../wizard_controller.dart';
import '../wizard_widgets.dart';
import '../write_note_screen.dart';

/// Steps 1 and 4: what the doctor said, what the chemist said.
///
/// One primary button — Speak. Writing is the alternative, on a full page.
/// Saving the audio is a separate, secondary choice, off by default: the
/// recording is for the family, and it is not what gets cross-checked.
///
/// Every take answers "did it record?" beneath its button: a live dot, timer
/// and meter while the mic is open, then "Recorded ✓ 0:42" or "Nothing
/// heard, try again".
class WordsStep extends StatefulWidget {
  const WordsStep({
    super.key,
    required this.controller,
    required this.who,
    required this.dictation,
    required this.audio,
    this.player,
  });

  final VisitWizardController controller;
  final SourceKind who;
  final Dictation dictation;
  final AudioCapture audio;
  final ClipPlayer? player;

  @override
  State<WordsStep> createState() => _WordsStepState();
}

class _WordsStepState extends State<WordsStep> {
  late final _speech = DictationSession(
    dictation: widget.dictation,
    read: () => c.wordsOf(widget.who),
    write: (text) => c.setWords(widget.who, text),
  );
  late final _clip = ClipSession(audio: widget.audio);
  late final ClipPlayer _player = widget.player ?? ClipPlayer();

  VisitWizardController get c => widget.controller;

  String? get _audioPath => widget.who == SourceKind.doctor
      ? c.visit.doctorAudioPath
      : c.visit.chemistAudioPath;

  @override
  void initState() {
    super.initState();
    if (_audioPath != null) _clip.recorder.restoreKept();
  }

  @override
  void dispose() {
    _speech.dispose();
    _clip.dispose();
    if (widget.player == null) _player.dispose();
    super.dispose();
  }

  Future<void> _toggleSpeak() async {
    if (_speech.listening) return _speech.stop();
    await _listen(_speech.start);
  }

  Future<void> _listen(Future<bool> Function(AppLanguage) how) async {
    final s = L10n.of(context);
    final ok = await how(L10n.languageOf(context));
    if (!ok && mounted) _say(s.dictationUnavailable);
  }

  Future<void> _write() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => WriteNoteScreen(initial: c.wordsOf(widget.who)),
      ),
    );
    if (text != null) c.setWords(widget.who, text);
  }

  Future<void> _toggleAudio() async {
    if (_clip.recording) {
      final file = await _clip.stop();
      if (file != null) await c.keepAudio(widget.who, file);
      return;
    }
    await _startAudio();
  }

  Future<void> _startAudio() async {
    final s = L10n.of(context);
    if (!await _clip.start() && mounted) _say(s.micUnavailable);
  }

  Future<void> _redoAudio() async {
    await c.dropAudio(widget.who);
    _clip.recorder.reset();
    await _startAudio();
  }

  Future<void> _deleteAudio() async {
    await _player.stop();
    await c.dropAudio(widget.who);
    _clip.recorder.delete();
  }

  Future<void> _play() async {
    final s = L10n.of(context);
    final path = _audioPath;
    if (path == null || !await _player.play(path)) {
      if (mounted) _say(s.cannotPlay);
    }
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final words = c.wordsOf(widget.who).trim();
    final audioKept = widget.who == SourceKind.doctor
        ? c.visit.doctorAudioPath != null
        : c.visit.chemistAudioPath != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        StepIntro(
          widget.who == SourceKind.doctor ? s.doctorWordsWhy : s.pharmacyWhy,
        ),
        ListenableBuilder(
          listenable: _speech.recorder,
          builder: (context, _) {
            final on = _speech.listening;
            return Pressable(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(72),
                  backgroundColor: on ? AppColors.red : AppColors.ink,
                ),
                icon: Icon(
                  on ? Icons.stop_rounded : Icons.graphic_eq_rounded,
                  size: 30,
                ),
                label: Text(on ? s.listening : s.speak),
                onPressed: _toggleSpeak,
              ),
            );
          },
        ),
        RecordingFeedback(
          controller: _speech.recorder,
          liveLabel: s.listeningLive,
          onRedo: () => _listen(_speech.redo),
          onDelete: _speech.delete,
          onRetry: () => _listen(_speech.retry),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined, size: 26),
          label: Text(s.writeIt),
          onPressed: _write,
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: _write,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.hairline, width: 2),
            ),
            child: Text(
              words.isEmpty ? s.nothingWrittenYet : words,
              style: words.isEmpty
                  ? text.bodySmall?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    )
                  : text.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              audioKept ? Icons.check_circle_rounded : Icons.mic_none_rounded,
              color: audioKept ? AppColors.green : AppColors.inkSoft,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audioKept ? s.audioSaved : s.alsoSaveAudio,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    s.alsoSaveAudioWhy,
                    style: text.bodySmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // Once kept, the panel below holds play, again and delete.
            if (!audioKept)
              ListenableBuilder(
                listenable: _clip.recorder,
                builder: (context, _) => TextButton(
                  onPressed: _toggleAudio,
                  child: Text(
                    _clip.recording ? s.stopRecording : s.speak,
                    style: TextStyle(
                      color: _clip.recording ? AppColors.red : AppColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        RecordingFeedback(
          controller: _clip.recorder,
          liveLabel: s.recordingLive,
          onPlay: _play,
          onRedo: _redoAudio,
          onDelete: _deleteAudio,
          onRetry: () {
            _clip.recorder.reset();
            _startAudio();
          },
        ),
      ],
    );
  }
}
