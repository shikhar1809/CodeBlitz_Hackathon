import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_alarm.dart';
import '../../core/plain_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/pictograms.dart';
import '../../domain/medicine_form.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../../platform/dose_reminders.dart';
import '../../platform/photo_thumb.dart';
import 'dose_log_store.dart';

/// A picture of the medicine, if there is one. Injectable so a stored strip
/// crop — or a test — can supply it; null falls back to the form pictogram.
typedef MedicinePhoto = Widget? Function(ScheduledMedicine medicine);

Widget? storedPhoto(ScheduledMedicine m) =>
    m.imagePath == null ? null : photoThumb(m.imagePath!, size: 96);

/// What wakes the phone when a dose is due.
///
/// One question, two answers, nothing else to press. The medicines are shown
/// the way the strip in the patient's hand looks: a photo when one exists,
/// the name in English letters, and the dose as pictures.
///
/// **Yes** logs the whole slot and cancels its alarms — the same log the
/// dose screen writes. **No / Later** writes nothing: the dose is still due,
/// and the +30 nudge (if it is still ahead) stays set. A demo writes nothing
/// either way.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({
    super.key,
    required this.slot,
    required this.date,
    required this.medicines,
    required this.logs,
    this.reminders,
    this.clock = DateTime.now,
    this.demo = false,
    this.photoOf = storedPhoto,
    this.onTaken,
    this.onLater,
  });

  final DoseSlot slot;
  final DateTime date;
  final List<ScheduledMedicine> medicines;
  final DoseLogStore logs;

  /// Where the slot's alarms are cancelled on "Yes". Null in a golden.
  final DoseReminders? reminders;
  final DateTime Function() clock;
  final bool demo;
  final MedicinePhoto photoOf;

  /// After the screen has closed: the caregiver alert and the re-sync. A slow
  /// network must never hold the alarm open.
  final void Function(DoseSlot slot, DateTime date)? onTaken;

  /// After "No / Later": re-sync, so the nudge is what the plan says it is.
  final void Function(DoseSlot slot, DateTime date)? onLater;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _busy = false;

  Future<void> _taken() async {
    setState(() => _busy = true);
    if (!widget.demo) {
      await widget.logs.logTaken(
        date: widget.date,
        slot: widget.slot,
        medicineIds: [for (final m in widget.medicines) m.id],
        at: widget.clock(),
      );
      // Before anything else: the nudge must never ring for a dose taken.
      await widget.reminders?.cancelSlot(widget.slot);
    }
    if (!mounted) return;
    final s = L10n.of(context);
    _close(true, widget.demo ? s.alarmDemoDone : s.doseSaved);
    if (!widget.demo) widget.onTaken?.call(widget.slot, widget.date);
  }

  void _later() {
    final s = L10n.of(context);
    _close(false, widget.demo ? s.alarmDemoDone : s.alarmLaterNote);
    if (!widget.demo) widget.onLater?.call(widget.slot, widget.date);
  }

  void _close(bool taken, String message) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(taken);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final slotName = PlainLanguage.slot(widget.slot, s);

    return VoicePrompt(
      text: spokenAlarm(s, widget.slot, widget.medicines),
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.demo) _DemoBanner(text: s.alarmDemoBanner),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: AppColors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        slotIcon(widget.slot),
                        size: 44,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slotName,
                            style: text.headlineMedium?.copyWith(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            s.alarmTitle,
                            style: text.bodyMedium?.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  children: [
                    for (final m in widget.medicines) ...[
                      _AlarmMedicine(
                        medicine: m,
                        photo: widget.photoOf(m),
                        strings: s,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              _Answers(
                question: s.alarmQuestion,
                yes: s.alarmTaken,
                no: s.alarmLater,
                onYes: _busy ? null : _taken,
                onNo: _busy ? null : _later,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The alarm, read aloud: the slot, then each medicine with its dose, then
/// the question.
String spokenAlarm(
  AppStrings s,
  DoseSlot slot,
  List<ScheduledMedicine> medicines,
) => [
  '${PlainLanguage.slot(slot, s)}. ${s.alarmTitle}.',
  for (final m in medicines) '${m.name}, ${_doseWords(m.sig, s)}.',
  s.alarmQuestion,
  s.alarmPressYesOrNo,
].join(' ');

String _doseWords(Sig sig, AppStrings s) {
  final units = sig.unitsPerDose;
  return [
    if (units == 1)
      s.alarmOneTablet
    else if (units == .5)
      s.halfTablet
    else
      s.tablets(units == units.roundToDouble() ? units.round() : units),
    if (sig.food == FoodTiming.before) s.beforeFood,
    if (sig.food == FoodTiming.after) s.afterFood,
  ].join(', ');
}

class _AlarmMedicine extends StatelessWidget {
  const _AlarmMedicine({
    required this.medicine,
    required this.photo,
    required this.strings,
  });

  final ScheduledMedicine medicine;
  final Widget? photo;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${medicine.name}. ${_doseWords(medicine.sig, strings)}',
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.hairline, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child:
                photo ??
                FormPictogram(form: formOf(medicine.name), strings: strings),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // English letters, as on the strip in their hand.
                Text(
                  medicine.name,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                if (medicine.strength != null &&
                    !medicine.name.contains(medicine.strength!))
                  Text(
                    medicine.strength!,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DoseDots(
                      units: medicine.sig.unitsPerDose,
                      strings: strings,
                    ),
                    FoodPictogram(food: medicine.sig.food, strings: strings),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Answers extends StatelessWidget {
  const _Answers({
    required this.question,
    required this.yes,
    required this.no,
    required this.onYes,
    required this.onNo,
  });

  final String question;
  final String yes;
  final String no;
  final VoidCallback? onYes;
  final VoidCallback? onNo;

  static const _label = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontFamilyFallback: AppTheme.fontFamilyFallback,
    fontSize: 30,
    fontWeight: FontWeight.w800,
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.hairline, width: 2)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        // The tick and cross are icons, not "✓" / "✗" in the label: the
        // bundled fonts have no such glyphs, and offline there is no
        // fallback to fetch.
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(96),
            backgroundColor: AppColors.green,
            textStyle: _label,
            iconSize: 40,
          ),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.check_rounded),
          onPressed: onYes,
          label: Text(yes),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(84),
            foregroundColor: AppColors.red,
            side: const BorderSide(color: AppColors.red, width: 3),
            textStyle: _label.copyWith(fontSize: 26),
            iconSize: 34,
          ),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.close_rounded),
          onPressed: onNo,
          label: Text(no),
        ),
      ],
    ),
  );
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.ink,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, color: AppColors.amber, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
