import 'package:flutter/material.dart';

import '../../core/feedback/haptics.dart';
import '../../core/feedback/pressable.dart';
import '../../core/l10n/l10n.dart';
import '../../core/plain_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_guide.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/pictograms.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import 'dose_log_store.dart';

/// Taking one slot's medicines.
///
/// Two gates, on purpose. A tick per medicine stops a half-finished slot being
/// logged as done. The final "सब ले ली" — locked until every row is ticked —
/// is the single confirmation the family's phone hears about.
class DoseScreen extends StatefulWidget {
  const DoseScreen({
    super.key,
    required this.slot,
    required this.date,
    required this.medicines,
    required this.logs,
    this.clock = DateTime.now,
    this.onConfirmed,
  });

  final DoseSlot slot;
  final DateTime date;
  final List<ScheduledMedicine> medicines;
  final DoseLogStore logs;
  final DateTime Function() clock;

  /// Fired after the screen has closed — the caregiver alert and cancelling
  /// the slot's reminders. A slow network must never hold this screen open.
  final void Function(DoseSlot slot, DateTime date)? onConfirmed;

  @override
  State<DoseScreen> createState() => _DoseScreenState();
}

class _DoseScreenState extends State<DoseScreen> {
  final _ticked = <String>{};
  bool _saving = false;

  bool get _all => _ticked.length == widget.medicines.length;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    await widget.logs.logTaken(
      date: widget.date,
      slot: widget.slot,
      medicineIds: [for (final m in widget.medicines) m.id],
      at: widget.clock(),
    );
    if (!mounted) return;
    final s = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(SnackBar(content: Text(s.doseSaved)));
    // After the pop, and not awaited before it.
    widget.onConfirmed?.call(widget.slot, widget.date);
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final title = PlainLanguage.slot(widget.slot, s);

    return VoicePrompt(
      text:
          '$title. ${s.tickAsYouGo} '
          '${widget.medicines.map((m) => m.name).join(', ')}',
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Icon(slotIcon(widget.slot), size: 36, color: AppColors.inkSoft),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    s.tickAsYouGo,
                    style: text.bodySmall?.copyWith(fontSize: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final m in widget.medicines) ...[
              _DoseRow(
                medicine: m,
                ticked: _ticked.contains(m.id),
                onTap: () => setState(() {
                  _ticked.contains(m.id)
                      ? _ticked.remove(m.id)
                      : _ticked.add(m.id);
                }),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.paper,
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_ticked.length} / ${widget.medicines.length}',
                  style: text.labelMedium?.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 10),
                Pressable(
                  enabled: _all && !_saving,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(76),
                      backgroundColor: AppColors.green,
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontFamilyFallback: AppTheme.fontFamilyFallback,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // The tap shows at once: a spinner while the log is
                    // written, never a button that seems to ignore the finger.
                    icon: _saving
                        ? const _Busy(color: AppColors.green)
                        : const Icon(Icons.check_circle_rounded, size: 32),
                    label: Text(s.allTaken),
                    onPressed: _all && !_saving
                        ? Haptics.on(_confirm, HapticKind.confirm)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.medicine,
    required this.ticked,
    required this.onTap,
  });

  final ScheduledMedicine medicine;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return Semantics(
      checked: ticked,
      button: true,
      label: medicine.name,
      child: Material(
        color: ticked ? AppColors.greenSoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(
            color: ticked ? AppColors.green : AppColors.hairline,
            width: ticked ? 3 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  ticked
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 42,
                  color: ticked ? AppColors.green : AppColors.muted,
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
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FoodPictogram(food: medicine.sig.food, strings: s),
                          DoseDots(
                            units: medicine.sig.unitsPerDose,
                            strings: s,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 30),
                  onPressed: () => VoiceScope.maybeOf(context)?.speak(
                    this,
                    '${medicine.name}. '
                    '${PlainLanguage.describe(medicine.sig, s)}',
                    L10n.languageOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 28,
    child: CircularProgressIndicator(strokeWidth: 3, color: color),
  );
}
