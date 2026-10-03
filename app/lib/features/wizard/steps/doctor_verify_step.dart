import 'package:flutter/material.dart';

import '../../../core/app_state.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/strings_recording.dart';
import '../../../core/plain_language.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/mention.dart';
import '../../../domain/sig.dart';
import '../../../platform/dictation.dart';
import '../../recording/recording_feedback.dart';
import '../../recording/recording_sessions.dart';
import '../../visit/visit.dart';
import '../wizard_controller.dart';
import '../wizard_models.dart';
import '../wizard_widgets.dart';
import 'takeaways_step.dart';

/// Step 2: who checks what the phone understood from the doctor?
///
/// **Doctor** runs a checklist in seconds: one tick per point, or "not
/// provided". **Me** is the person holding the phone, ticking and fixing rows.
/// Either way, anything left unchecked stays flagged — nothing is accepted
/// silently. Below both sits the note for the caretaker.
class DoctorVerifyStep extends StatelessWidget {
  const DoctorVerifyStep({
    super.key,
    required this.controller,
    required this.dictation,
  });

  final VisitWizardController controller;
  final Dictation dictation;

  @override
  Widget build(BuildContext context) {
    final toggle = _VerifierToggle(controller: controller);
    final note = _CaretakerNote(controller: controller, dictation: dictation);
    if (controller.verifier == Verifier.me) {
      return TakeawaysStep(
        controller: controller,
        who: SourceKind.doctor,
        leading: [toggle, const SizedBox(height: 16)],
        trailing: [const SizedBox(height: 16), note],
      );
    }
    final s = L10n.of(context);
    final rows = controller.takeaways(SourceKind.doctor);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        toggle,
        const SizedBox(height: 16),
        Text(s.doctorCheckTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        StepIntro(s.doctorCheckWhy),
        if (rows.isEmpty)
          InfoCard(text: s.nothingToCheck, icon: Icons.info_outline),
        for (var i = 0; i < rows.length; i++) ...[
          rows[i].isNote
              ? _AdviceCheck(
                  text: rows[i].name,
                  ticked: rows[i].ticked,
                  onTap: () => controller.toggleTakeaway(SourceKind.doctor, i),
                )
              : _DoctorCheckCard(
                  row: rows[i],
                  onSet: (point, state) =>
                      controller.setCheck(SourceKind.doctor, i, point, state),
                ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 8),
        note,
      ],
    );
  }
}

class _VerifierToggle extends StatelessWidget {
  const _VerifierToggle({required this.controller});

  final VisitWizardController controller;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final caretaker = AppScope.maybeOf(context)?.role == AppRole.caregiver;
    Widget option(Verifier v, IconData icon, String label) {
      final on = controller.verifier == v;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: Material(
            color: on ? AppColors.ink : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius * .8),
              side: BorderSide(
                color: on ? AppColors.ink : AppColors.hairline,
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => controller.setVerifier(v),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTheme.tapTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: on ? Colors.white : AppColors.inkSoft),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: on ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.whoVerifies, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            option(
              Verifier.doctor,
              Icons.medical_services_outlined,
              s.verifierDoctor,
            ),
            const SizedBox(width: 10),
            option(
              Verifier.me,
              Icons.person_outline,
              caretaker ? s.verifierCaretaker : s.verifierPatient,
            ),
          ],
        ),
      ],
    );
  }
}

class _DoctorCheckCard extends StatelessWidget {
  const _DoctorCheckCard({required this.row, required this.onSet});

  final Takeaway row;
  final void Function(CheckPoint, CheckState) onSet;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final left = row.checks.values
        .where((c) => c == CheckState.unchecked)
        .length;
    final done = row.doctorVerified;
    return ToneCard(
      fill: done ? AppColors.greenSoft : AppColors.surface,
      border: done
          ? AppColors.green
          : left > 0
          ? AppColors.warn
          : AppColors.hairline,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(row.name, style: text.titleLarge)),
              Pill(
                done ? s.verified : s.pointsLeft(left),
                tone: done ? PillTone.green : PillTone.warn,
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in CheckPoint.values)
            _PointRow(
              label: _label(p, s),
              value: _value(p, s),
              state: row.checks[p]!,
              onSet: (st) => onSet(p, st),
            ),
        ],
      ),
    );
  }

  String _label(CheckPoint p, AppStrings s) => switch (p) {
    CheckPoint.name => s.pointName,
    CheckPoint.dose => s.pointDose,
    CheckPoint.timing => s.pointTiming,
    CheckPoint.food => s.pointFood,
    CheckPoint.duration => s.pointDuration,
    CheckPoint.purpose => s.pointPurpose,
  };

  /// What the phone heard for this point — or that nothing was heard.
  String _value(CheckPoint p, AppStrings s) {
    final sig = row.sig;
    return switch (p) {
      CheckPoint.name => row.name,
      CheckPoint.dose =>
        sig.unitsPerDose == 1
            ? s.oneTablet
            : sig.unitsPerDose == .5
            ? s.halfTablet
            : s.tablets(sig.unitsPerDose.round()),
      CheckPoint.timing =>
        sig.hasTiming
            ? PlainLanguage.describe(
                Sig(slots: sig.slots, sos: sig.sos, stat: sig.stat),
                s,
                withUnits: false,
              )
            : s.notMentioned,
      CheckPoint.food => switch (sig.food) {
        FoodTiming.before => s.beforeFood,
        FoodTiming.after => s.afterFood,
        FoodTiming.unspecified => s.notMentioned,
      },
      CheckPoint.duration => [
        if (sig.everyNDays != null) s.everyNDays(sig.everyNDays!),
        if (sig.durationDays != null) s.forDays(sig.durationDays!),
      ].join(' · ').ifEmpty(s.notMentioned),
      CheckPoint.purpose => row.purpose ?? s.notMentioned,
    };
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.label,
    required this.value,
    required this.state,
    required this.onSet,
  });

  final String label;
  final String value;
  final CheckState state;
  final ValueChanged<CheckState> onSet;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final confirmed = state == CheckState.confirmed;
    final absent = state == CheckState.notProvided;
    return InkWell(
      onTap: () =>
          onSet(confirmed ? CheckState.unchecked : CheckState.confirmed),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: confirmed,
              activeColor: AppColors.green,
              onChanged: (_) => onSet(
                confirmed ? CheckState.unchecked : CheckState.confirmed,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      color: absent ? AppColors.muted : AppColors.ink,
                      decoration: absent ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
            Pill(
              s.notProvided,
              tone: absent ? PillTone.strong : PillTone.neutral,
              onTap: () =>
                  onSet(absent ? CheckState.unchecked : CheckState.notProvided),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdviceCheck extends StatelessWidget {
  const _AdviceCheck({
    required this.text,
    required this.ticked,
    required this.onTap,
  });

  final String text;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ToneCard(
    fill: ticked ? AppColors.greenSoft : AppColors.surface,
    border: ticked ? AppColors.green : AppColors.hairline,
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Checkbox(
            value: ticked,
            activeColor: AppColors.green,
            onChanged: (_) => onTap(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.of(context).adviceCheck,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                Text(text, style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A note for the caretaker, with how much it matters. Dictation fills the
/// box; the priority is a colour and a word.
class _CaretakerNote extends StatefulWidget {
  const _CaretakerNote({required this.controller, required this.dictation});

  final VisitWizardController controller;
  final Dictation dictation;

  @override
  State<_CaretakerNote> createState() => _CaretakerNoteState();
}

class _CaretakerNoteState extends State<_CaretakerNote> {
  late final _text = TextEditingController(
    text: widget.controller.visit.caretakerNote,
  );
  late final _speech = DictationSession(
    dictation: widget.dictation,
    read: () => _text.text,
    write: (text) {
      _text.text = text;
      widget.controller.setCaretakerNote(text);
    },
  );

  @override
  void dispose() {
    _speech.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _dictate() async {
    if (_speech.listening) return _speech.stop();
    await _listen(_speech.start);
  }

  Future<void> _listen(Future<bool> Function(AppLanguage) how) async {
    final s = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await how(L10n.languageOf(context))) {
      messenger.showSnackBar(SnackBar(content: Text(s.dictationUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final c = widget.controller;
    Widget chip(NotePriority p, String label, Color color, Color soft) {
      final on = c.visit.notePriority == p;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: Material(
            color: on ? color : soft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: color, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => c.setNotePriority(p),
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.caretakerNoteTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _text,
          minLines: 2,
          maxLines: 5,
          style: const TextStyle(fontSize: 20),
          onChanged: c.setCaretakerNote,
          decoration: InputDecoration(
            hintText: s.caretakerNoteHint,
            suffixIcon: ListenableBuilder(
              listenable: _speech.recorder,
              builder: (context, _) => IconButton(
                tooltip: s.speak,
                icon: Icon(
                  _speech.listening
                      ? Icons.stop_circle_rounded
                      : Icons.mic_rounded,
                  color: _speech.listening ? AppColors.red : AppColors.inkSoft,
                  size: 30,
                ),
                onPressed: _dictate,
              ),
            ),
          ),
        ),
        RecordingFeedback(
          controller: _speech.recorder,
          liveLabel: s.listeningLive,
          onRedo: () => _listen(_speech.redo),
          onDelete: _speech.delete,
          onRetry: () => _listen(_speech.retry),
        ),
        const SizedBox(height: 12),
        Text(s.priority, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            chip(
              NotePriority.low,
              s.priorityLow,
              AppColors.green,
              AppColors.greenSoft,
            ),
            const SizedBox(width: 8),
            chip(
              NotePriority.medium,
              s.priorityMedium,
              AppColors.warn,
              AppColors.warnSoft,
            ),
            const SizedBox(width: 8),
            chip(
              NotePriority.high,
              s.priorityHigh,
              AppColors.red,
              AppColors.redSoft,
            ),
          ],
        ),
      ],
    );
  }
}
