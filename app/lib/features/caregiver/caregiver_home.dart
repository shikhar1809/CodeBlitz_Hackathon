import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_caretaker.dart';
import '../../core/plain_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/app_bar_actions.dart';
import '../../core/widgets/rx_logo.dart';
import '../../domain/schedule_engine.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../doses/dose_log_store.dart';
import '../medicines/medicine_store.dart';
import '../pairing/caretaker_pairing.dart';
import '../pairing/open_pairing.dart';
import 'family.dart';
import 'plan_summary.dart';
import 'whatsapp_alerts.dart';

/// The caregiver's half: today at a glance, the family number, and the plan in
/// plain words — sendable to anyone, installable by no one.
class CaregiverHome extends StatefulWidget {
  const CaregiverHome({
    super.key,
    required this.onRestart,
    this.store,
    this.logs,
    this.alerts,
    this.clock = DateTime.now,
  });

  final VoidCallback onRestart;
  final MedicineStore? store;
  final DoseLogStore? logs;
  final WhatsAppAlerts? alerts;
  final DateTime Function() clock;

  @override
  State<CaregiverHome> createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {
  MedicineStore? _store;
  DoseLogStore? _logs;
  late final WhatsAppAlerts _alerts = widget.alerts ?? WhatsAppAlerts();

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    _logs = widget.logs;
    if (_store == null || _logs == null) _load();
  }

  Future<void> _load() async {
    final store = await MedicineStore.load();
    final logs = await DoseLogStore.load();
    if (mounted) {
      setState(() {
        _store = store;
        _logs = logs;
      });
    }
  }

  List<ScheduledMedicine> get _meds => _store?.active() ?? const [];

  /// Visits that carried a note for the caretaker: high first, newest first.
  List<PrescriptionRecord> get _notes {
    const rank = {'high': 0, 'medium': 1, 'low': 2};
    return [
      for (final r in _store?.records() ?? const <PrescriptionRecord>[])
        if (r.caretakerNote != null) r,
    ]..sort((a, b) {
      final p = rank[a.notePriority]!.compareTo(rank[b.notePriority]!);
      return p != 0 ? p : b.addedAt.compareTo(a.addedAt);
    });
  }

  Future<void> _changeNumber() async {
    final state = AppScope.of(context);
    final s = L10n.of(context);
    final ctl = TextEditingController(text: state.prefs.alertPhone ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(s.familyNumberTitle),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 22),
          decoration: const InputDecoration(prefixText: '+91 '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 56)),
            onPressed: () => Navigator.pop(d, ctl.text),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    final number = WhatsAppAlerts.normalise(value);
    if (number == null) {
      _say(s.familyNumberInvalid);
      return;
    }
    // Stored as ten digits, like the onboarding field.
    await state.prefs.setBackupPhone(number.substring(3));
    setState(() {});
  }

  Future<void> _sendStatus() async {
    final state = AppScope.of(context);
    final s = L10n.of(context);
    final to = WhatsAppAlerts.normalise(state.prefs.alertPhone);
    if (to == null) {
      _say(s.addFamilyFirst);
      return;
    }
    final body = PlanSummary.status(
      name: state.prefs.name ?? '',
      medicines: _meds,
      logs: _logs!,
      now: widget.clock(),
      s: s,
    );
    final result = await _alerts.send(to, body);
    if (!mounted) return;
    _say(switch (result) {
      AlertDelivery.sentAutomatically => s.sentAutomatically,
      AlertDelivery.openedInWhatsApp => s.openedInWhatsApp,
      AlertDelivery.failed => s.sendFailed,
    });
  }

  Future<void> _openPairing() async {
    await openCaretakerPairing(
      context,
      pairing: CaretakerPairing(prefs: AppScope.of(context).prefs),
    );
    if (mounted) setState(() {});
  }

  void _say(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final state = AppScope.of(context);
    final phone = state.prefs.alertPhone;
    final now = widget.clock();
    final due = _logs == null
        ? const <DoseSlot, List<ScheduledMedicine>>{}
        : ScheduleEngine.dueOn(_meds, now);

    return VoicePrompt(
      text: '${s.todaysDoses}. ${s.alertsWhy}',
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(
            children: [
              const RxLogo(size: 32),
              const SizedBox(width: 12),
              Text(s.appName),
            ],
          ),
          actions: appBarActions(context, onRestart: widget.onRestart),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _LinkCard(
              patient: LinkedPatient.fromJsonString(
                state.prefs.linkedPatientJson,
              ),
              onShowQr: _openPairing,
            ),
            const SizedBox(height: 16),
            // A High-priority note from the patient's side is the first
            // thing a caretaker sees.
            for (final r in _notes.where((r) => r.notePriority == 'high')) ...[
              NoteCard(record: r),
              const SizedBox(height: 12),
            ],
            Text(s.todaysDoses, style: text.titleLarge),
            const SizedBox(height: 10),
            if (_meds.isEmpty)
              _Muted(s.noPrescriptionsYet)
            else
              Row(
                children: [
                  for (final (i, e) in due.entries.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _SlotPill(
                        label: PlainLanguage.slot(e.key, s),
                        status: _logs!.statusOf(now, now, e.key),
                      ),
                    ),
                  ],
                ],
              ),
            if (due.isEmpty && _meds.isNotEmpty) _Muted(s.nothingDueToday),
            const SizedBox(height: 22),
            Text(s.alerts, style: text.titleLarge),
            Text(s.alertsWhy, style: text.labelMedium?.copyWith(fontSize: 16)),
            const SizedBox(height: 10),
            _NumberRow(
              phone: phone,
              emptyText: s.noFamilyYet,
              changeLabel: s.change,
              onChange: _changeNumber,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.chat_rounded),
              label: Text(s.sendStatus),
              onPressed: _logs == null ? null : _sendStatus,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(s.sharePlan),
              onPressed: () => sharePlan(context, _meds),
            ),
            const SizedBox(height: 26),
            if (_notes.any((r) => r.notePriority != 'high')) ...[
              Text(s.caretakerNotes, style: text.titleLarge),
              const SizedBox(height: 8),
              for (final r in _notes.where((r) => r.notePriority != 'high'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NoteCard(record: r),
                ),
              const SizedBox(height: 16),
            ],
            Text(s.medicineSchedule, style: text.titleLarge),
            const SizedBox(height: 8),
            if (_meds.isEmpty)
              _Muted(s.noPrescriptionsYet)
            else
              for (final m in _meds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Muted('• ${PlanSummary.sentence(m, now, s)}'),
                ),
          ],
        ),
      ),
    );
  }
}

/// Who this caretaker is linked to — or the way to link.
class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.patient, required this.onShowQr});

  final LinkedPatient? patient;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final linked = patient != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: linked ? AppColors.greenSoft : AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: linked ? AppColors.green : AppColors.amberBorder,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                linked ? Icons.link_rounded : Icons.link_off_rounded,
                color: linked ? AppColors.green : AppColors.ink,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  linked ? s.linkedPatientLine(patient!.name) : s.notLinkedYet,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!linked) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(s.showMyQr),
              onPressed: onShowQr,
            ),
          ],
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppColors.muted),
  );
}

class _SlotPill extends StatelessWidget {
  const _SlotPill({required this.label, required this.status});

  final String label;
  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    final (fill, border, icon, color) = switch (status) {
      DoseStatus.taken => (
        AppColors.greenSoft,
        AppColors.green,
        Icons.check_circle_rounded,
        AppColors.green,
      ),
      DoseStatus.missed => (
        AppColors.redSoft,
        AppColors.red,
        Icons.error_rounded,
        AppColors.red,
      ),
      DoseStatus.dueNow => (
        AppColors.amberSoft,
        AppColors.amberDark,
        Icons.notifications_active_rounded,
        AppColors.amberDark,
      ),
      DoseStatus.notYet => (
        AppColors.surface,
        AppColors.hairline,
        Icons.schedule_rounded,
        AppColors.muted,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppTheme.radius * .8),
        border: Border.all(color: border, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.phone,
    required this.emptyText,
    required this.changeLabel,
    required this.onChange,
  });

  final String? phone;
  final String emptyText;
  final String changeLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final set = phone != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: BoxDecoration(
        color: set ? AppColors.greenSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: set ? AppColors.green : AppColors.hairline,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            set ? Icons.person_rounded : Icons.person_add_alt_outlined,
            color: set ? AppColors.green : AppColors.muted,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              set ? '+91 $phone' : emptyText,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            onPressed: onChange,
            child: Text(changeLabel),
          ),
        ],
      ),
    );
  }
}

/// A caretaker note, coloured by how much it matters.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.record});

  final PrescriptionRecord record;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final (fill, border, word) = switch (record.notePriority) {
      'high' => (AppColors.redSoft, AppColors.red, s.priorityHigh),
      'medium' => (AppColors.warnSoft, AppColors.warn, s.priorityMedium),
      _ => (AppColors.greenSoft, AppColors.green, s.priorityLow),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: border, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            record.notePriority == 'high'
                ? Icons.priority_high_rounded
                : Icons.sticky_note_2_outlined,
            color: border,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: border,
                  ),
                ),
                Text(
                  record.caretakerNote ?? '',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
