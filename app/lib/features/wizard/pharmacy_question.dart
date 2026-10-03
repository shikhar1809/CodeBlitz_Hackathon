import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_pharmacy.dart';
import '../../core/plain_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/mention.dart';
import '../../domain/pharmacy_check.dart';
import '../../platform/dictation.dart';
import '../visit/capture_tools.dart';
import 'wizard_widgets.dart';

/// What a person said in the pop-up. Closing it says nothing.
class PharmacyAnswer {
  const PharmacyAnswer(
    this.choice, {
    this.explanation = '',
    this.voiceNote,
    this.by = AnsweredBy.patient,
  });

  final PharmacyChoice choice;
  final String explanation;
  final XFile? voiceNote;
  final AnsweredBy by;
}

/// Ask one pharmacy question, the moment it is found. Returns null when the
/// pop-up is closed — which answers nothing, and leaves the card red.
Future<PharmacyAnswer?> showPharmacyQuestion(
  BuildContext context, {
  required PharmacyIssue issue,
  required String medicineName,
  required Dictation dictation,
  required AudioCapture audio,
  AnsweredBy defaultBy = AnsweredBy.patient,
  PharmacyResolution? previous,
}) => showDialog<PharmacyAnswer>(
  context: context,
  builder: (_) => PharmacyQuestionDialog(
    issue: issue,
    medicineName: medicineName,
    dictation: dictation,
    audio: audio,
    defaultBy: previous?.answeredBy ?? defaultBy,
    previous: previous,
  ),
);

String pharmacyTitle(PharmacyIssueKind kind, AppStrings s) => switch (kind) {
  PharmacyIssueKind.substitution => s.phSubstitutionTitle,
  PharmacyIssueKind.strength => s.phStrengthTitle,
  PharmacyIssueKind.notPrescribed => s.phNotPrescribedTitle,
  PharmacyIssueKind.quantity => s.phQuantityTitle,
  PharmacyIssueKind.unreadable => s.phUnreadableTitle,
};

/// What picking A or B means, in the words on its button's card.
String pharmacyPickLabel(
  PharmacyIssue i,
  PharmacyChoice choice,
  AppStrings s,
) {
  final a = choice == PharmacyChoice.a;
  return switch (i.kind) {
    PharmacyIssueKind.substitution ||
    PharmacyIssueKind.strength => (a ? i.a : i.b)?.name ?? '',
    PharmacyIssueKind.notPrescribed => a ? s.phTakeIt : s.leaveOut,
    PharmacyIssueKind.quantity =>
      a
          ? s.phCourseDetail(i.needed!, i.courseDays!)
          : s.phBillDetail(i.sold!, i.billDays!),
    PharmacyIssueKind.unreadable => a ? s.phInList : s.phNotMedicine,
  };
}

/// Where a question stands, in one line for the card.
String pharmacyState(
  PharmacyIssue i,
  PharmacyResolution? r, {
  required bool settled,
  required AppStrings s,
}) {
  if (r != null && r.settles) {
    return '${s.phAnswered}: ${pharmacyPickLabel(i, r.choice, s)}';
  }
  if (settled) return s.phAnswered;
  if (r == null) return s.phNotAnswered;
  if (r.choice == PharmacyChoice.notSure) return s.phStillNotSure;
  final said = r.explanation.isNotEmpty
      ? s.phExplained(r.explanation)
      : s.phVoiceNoteKept;
  return '$said\n${s.phNeedsPick}';
}

/// The pop-up: the doubt in plain words, both readings side by side with
/// where each came from, and four ways to answer. Only A or B settles it.
class PharmacyQuestionDialog extends StatefulWidget {
  const PharmacyQuestionDialog({
    super.key,
    required this.issue,
    required this.medicineName,
    required this.dictation,
    required this.audio,
    this.defaultBy = AnsweredBy.patient,
    this.previous,
  });

  final PharmacyIssue issue;
  final String medicineName;
  final Dictation dictation;
  final AudioCapture audio;
  final AnsweredBy defaultBy;
  final PharmacyResolution? previous;

  @override
  State<PharmacyQuestionDialog> createState() => _PharmacyQuestionDialogState();
}

class _PharmacyQuestionDialogState extends State<PharmacyQuestionDialog> {
  late final _text = TextEditingController(
    text: widget.previous?.explanation ?? '',
  );
  late AnsweredBy _by = widget.defaultBy;
  late bool _explaining = widget.previous?.choice == PharmacyChoice.neither;
  bool _listening = false;
  bool _recording = false;
  XFile? _note;

  PharmacyIssue get i => widget.issue;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (_listening) widget.dictation.stop();
    if (_recording) widget.audio.stop();
    _text.dispose();
    super.dispose();
  }

  void _done(PharmacyChoice choice) => Navigator.of(context).pop(
    PharmacyAnswer(
      choice,
      explanation: _text.text.trim(),
      voiceNote: _note,
      by: _by,
    ),
  );

  Future<void> _dictate() async {
    if (_listening) {
      await widget.dictation.stop();
      setState(() => _listening = false);
      return;
    }
    final before = _text.text.trim();
    final ok = await widget.dictation.listen(
      language: L10n.languageOf(context),
      onWords: (words, done) {
        _text.text = [before, words].where((x) => x.isNotEmpty).join(' ');
        if (done && mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!ok) {
      _say(L10n.of(context).dictationUnavailable);
      return;
    }
    setState(() => _listening = true);
  }

  Future<void> _record() async {
    if (_recording) {
      final file = await widget.audio.stop();
      setState(() {
        _recording = false;
        _note = file ?? _note;
      });
      return;
    }
    if (!await widget.audio.start()) {
      if (mounted) _say(L10n.of(context).micUnavailable);
      return;
    }
    setState(() => _recording = true);
  }

  void _say(String message) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  String _question(AppStrings s) => switch (i.kind) {
    PharmacyIssueKind.substitution => s.phSubstitutionAsk(i.a!.name, i.b!.name),
    PharmacyIssueKind.strength => s.phStrengthAsk(i.a!.name, i.b!.name),
    PharmacyIssueKind.notPrescribed => s.phNotPrescribedAsk(i.a!.name),
    PharmacyIssueKind.quantity => s.phQuantityAsk(
      widget.medicineName,
      i.sold!,
      i.needed!,
      i.courseDays!,
    ),
    PharmacyIssueKind.unreadable => s.phUnreadableAsk,
  };

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;

    Widget reading({
      required String source,
      required String headline,
      String? quote,
      String? pickLabel,
      PharmacyChoice? choice,
    }) => ToneCard(
      fill: AppColors.surface,
      border: AppColors.hairline,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            source,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            headline,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (quote != null) ...[
            const SizedBox(height: 4),
            Text(quote, style: const TextStyle(fontSize: 16, height: 1.3)),
          ],
          if (choice != null) ...[
            const Spacer(),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => _done(choice),
              child: Text(pickLabel!, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );

    String label(Mention m) => PlainLanguage.sourceLabel(m.source, s);
    String quoted(Mention m) => '“${m.raw}”';

    final Widget readings = switch (i.kind) {
      PharmacyIssueKind.unreadable => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          reading(
            source:
                '${PlainLanguage.sourceLabel(i.line!.source, s)} · '
                '${s.phReadAs}',
            headline: '“${i.line!.text}”',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _done(PharmacyChoice.a),
            child: Text(s.phInList),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _done(PharmacyChoice.b),
            child: Text(s.phNotMedicine),
          ),
        ],
      ),
      _ => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: reading(
                source: label(i.a!),
                headline: switch (i.kind) {
                  PharmacyIssueKind.quantity => s.phCourseDetail(
                    i.needed!,
                    i.courseDays!,
                  ),
                  _ => i.a!.name,
                },
                quote: quoted(i.a!),
                pickLabel: i.kind == PharmacyIssueKind.notPrescribed
                    ? s.phTakeIt
                    : s.phPickThis,
                choice: PharmacyChoice.a,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: i.b == null
                  ? reading(
                      source: s.phNotMentioned,
                      headline: s.phNotMentionedQuote,
                      pickLabel: s.leaveOut,
                      choice: PharmacyChoice.b,
                    )
                  : reading(
                      source: label(i.b!),
                      headline: switch (i.kind) {
                        PharmacyIssueKind.quantity => s.phBillDetail(
                          i.sold!,
                          i.billDays!,
                        ),
                        _ => i.b!.name,
                      },
                      quote: quoted(i.b!),
                      pickLabel: s.phPickThis,
                      choice: PharmacyChoice.b,
                    ),
            ),
          ],
        ),
      ),
    };

    Widget by(AnsweredBy who, String name) => Pill(
      name,
      tone: _by == who ? PillTone.strong : PillTone.neutral,
      onTap: () => setState(() => _by = who),
    );

    return Dialog(
      backgroundColor: AppColors.paper,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: const BorderSide(color: AppColors.red, width: 2),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4, right: 10),
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.red,
                    size: 30,
                  ),
                ),
                Expanded(
                  child: Text(
                    pharmacyTitle(i.kind, s),
                    style: text.titleLarge?.copyWith(color: AppColors.red),
                  ),
                ),
                IconButton(
                  tooltip: s.phDecideLater,
                  icon: const Icon(Icons.close_rounded, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _question(s),
              style: text.bodyMedium?.copyWith(fontSize: 20, height: 1.35),
            ),
            const SizedBox(height: 14),
            readings,
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.record_voice_over_outlined),
              label: Text(s.phNeither),
              onPressed: () => setState(() => _explaining = !_explaining),
            ),
            if (_explaining) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                minLines: 2,
                maxLines: 5,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  hintText: s.phExplainHint,
                  suffixIcon: IconButton(
                    tooltip: s.speak,
                    icon: Icon(
                      _listening
                          ? Icons.stop_circle_rounded
                          : Icons.mic_rounded,
                      color: _listening ? AppColors.red : AppColors.inkSoft,
                      size: 30,
                    ),
                    onPressed: _dictate,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                icon: Icon(
                  _recording
                      ? Icons.stop_rounded
                      : _note != null
                      ? Icons.check_circle_rounded
                      : Icons.mic_none_rounded,
                  color: _recording
                      ? AppColors.red
                      : _note != null
                      ? AppColors.green
                      : AppColors.inkSoft,
                ),
                label: Text(
                  _recording
                      ? s.stopRecording
                      : _note != null
                      ? s.phNoteSaved
                      : s.phRecordNote,
                ),
                onPressed: _record,
              ),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: _text.text.trim().isEmpty && _note == null
                    ? null
                    : () => _done(PharmacyChoice.neither),
                child: Text(s.phSaveExplanation),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(AppTheme.tapTarget),
                foregroundColor: AppColors.red,
              ),
              onPressed: () => _done(PharmacyChoice.notSure),
              child: Text(s.phNotSure, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 6),
            Text(s.phWhoAnswers, style: text.titleMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                by(AnsweredBy.patient, s.phByPatient),
                by(AnsweredBy.caretaker, s.phByCaretaker),
                by(AnsweredBy.doctor, s.phByDoctor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A pharmacy question on a medicine card: what it is, where it stands, and
/// a way back to it. Red while it is open.
class PharmacyIssueNote extends StatelessWidget {
  const PharmacyIssueNote({
    super.key,
    required this.issue,
    required this.resolution,
    required this.settled,
    required this.onAnswer,
  });

  final PharmacyIssue issue;
  final PharmacyResolution? resolution;
  final bool settled;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final tone = settled ? AppColors.green : AppColors.red;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: settled ? AppColors.greenSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            settled ? Icons.check_circle_outline : Icons.help_outline_rounded,
            color: tone,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pharmacyTitle(issue.kind, s),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
                Text(
                  pharmacyState(issue, resolution, settled: settled, s: s),
                  style: const TextStyle(fontSize: 16, height: 1.3),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onAnswer, child: Text(s.phAnswer)),
        ],
      ),
    );
  }
}

/// A photo line nobody could read, as its own card above the medicines.
class UnreadLineCard extends StatelessWidget {
  const UnreadLineCard({
    super.key,
    required this.issue,
    required this.resolution,
    required this.settled,
    required this.onAnswer,
  });

  final PharmacyIssue issue;
  final PharmacyResolution? resolution;
  final bool settled;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final tone = settled ? AppColors.muted : AppColors.red;
    return ToneCard(
      fill: settled ? AppColors.paper : AppColors.redSoft,
      border: settled ? AppColors.hairline : AppColors.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.phUnreadableTitle,
            style: text.titleLarge?.copyWith(color: tone),
          ),
          const SizedBox(height: 6),
          Text(
            '${PlainLanguage.sourceLabel(issue.line!.source, s)}: '
            '“${issue.line!.text}”',
            style: const TextStyle(fontSize: 18, height: 1.3),
          ),
          const SizedBox(height: 6),
          Text(
            pharmacyState(issue, resolution, settled: settled, s: s),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.help_outline_rounded),
            label: Text(s.phAnswer),
            onPressed: onAnswer,
          ),
        ],
      ),
    );
  }
}
