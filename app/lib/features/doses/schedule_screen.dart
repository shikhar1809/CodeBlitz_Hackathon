import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/plain_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/pictograms.dart';
import '../../domain/schedule_engine.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../medicines/medicine_store.dart';
import '../patient/prescriptions_screen.dart';
import 'dose_log_store.dart';
import 'dose_screen.dart';
import 'month_calendar.dart';

/// Today, slot by slot, and the month.
///
/// Only slots with something due are shown. Opening it looks for missed doses
/// and re-syncs reminders, through [onOpened], because nothing else runs in
/// the background to do either.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.store,
    required this.logs,
    this.clock = DateTime.now,
    this.onOpened,
    this.onConfirmed,
    this.onShare,
    this.reminderBanner,
  });

  final MedicineStore store;
  final DoseLogStore logs;
  final DateTime Function() clock;
  final Future<void> Function(List<ScheduledMedicine> medicines, DateTime now)?
  onOpened;
  final void Function(DoseSlot slot, DateTime date)? onConfirmed;
  final VoidCallback? onShare;

  /// Shown when reminders cannot run, so nobody believes they are handled.
  final String? reminderBanner;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late List<ScheduledMedicine> _meds = widget.store.active();

  @override
  void initState() {
    super.initState();
    widget.onOpened?.call(_meds, widget.clock());
  }

  Future<void> _open(DoseSlot slot, List<ScheduledMedicine> due) async {
    final now = widget.clock();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DoseScreen(
          slot: slot,
          date: now,
          medicines: due,
          logs: widget.logs,
          clock: widget.clock,
          onConfirmed: widget.onConfirmed,
        ),
      ),
    );
    if (mounted) setState(() => _meds = widget.store.active());
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final now = widget.clock();
    final today = ScheduleEngine.dueOn(_meds, now);
    final sos = ScheduleEngine.whenNeeded(_meds, now);

    return VoicePrompt(
      text: _spoken(s, today, now),
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.medicineSchedule),
          actions: [
            if (widget.onShare != null)
              IconButton(
                tooltip: s.share,
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: widget.onShare,
              ),
          ],
        ),
        body: _meds.isEmpty
            ? EmptyState(
                icon: Icons.schedule_rounded,
                text: s.noPrescriptionsYet,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (today.isEmpty)
                    Text(s.nothingDueToday, style: text.bodyMedium),
                  for (final entry in today.entries) ...[
                    _SlotCard(
                      slot: entry.key,
                      medicines: entry.value,
                      status: widget.logs.statusOf(now, now, entry.key),
                      onTap: () => _open(entry.key, entry.value),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (sos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(s.whenNeeded, style: text.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      s.takeOnlyWhenNeeded(sos.map((m) => m.name).join(', ')),
                      style: text.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  ],
                  if (widget.reminderBanner != null) ...[
                    const SizedBox(height: 20),
                    _Banner(text: widget.reminderBanner!),
                  ],
                  const SizedBox(height: 24),
                  Text(s.thisMonth, style: text.titleLarge),
                  const SizedBox(height: 10),
                  MonthCalendar(
                    month: now,
                    markOf: (d) => widget.logs.markFor(now, d, _meds),
                  ),
                ],
              ),
      ),
    );
  }

  String _spoken(
    AppStrings s,
    Map<DoseSlot, List<ScheduledMedicine>> today,
    DateTime now,
  ) => [
    s.medicineSchedule,
    for (final e in today.entries)
      '${PlainLanguage.slot(e.key, s)}: '
          '${e.value.map((m) => m.name).join(', ')}. '
          '${_word(widget.logs.statusOf(now, now, e.key), s)}.',
  ].join(' ');
}

String _word(DoseStatus st, AppStrings s) => switch (st) {
  DoseStatus.taken => s.statusTaken,
  DoseStatus.missed => s.statusMissed,
  DoseStatus.dueNow => s.statusDueNow,
  DoseStatus.notYet => s.statusNotYet,
};

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.medicines,
    required this.status,
    required this.onTap,
  });

  final DoseSlot slot;
  final List<ScheduledMedicine> medicines;
  final DoseStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
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

    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: border, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // A slot already taken is done; tapping it again would log twice.
        onTap: status == DoseStatus.taken ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
          child: Row(
            children: [
              Icon(slotIcon(slot), size: 38, color: AppColors.inkSoft),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PlainLanguage.slot(slot, s),
                      style: text.headlineMedium?.copyWith(fontSize: 28),
                    ),
                    Text(
                      medicines.map((m) => m.name).join(', '),
                      style: text.bodySmall?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Icon(icon, size: 30, color: color),
                  const SizedBox(height: 2),
                  Text(
                    _word(status, s),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color == AppColors.muted ? AppColors.muted : color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.amberSoft,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      border: Border.all(color: AppColors.amberBorder, width: 2),
    ),
    child: Row(
      children: [
        const Icon(Icons.notifications_off_outlined, color: AppColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    ),
  );
}
