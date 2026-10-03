import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/plain_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/voice/voice_guide.dart';
import '../../domain/mention.dart';
import '../../domain/merge_engine.dart';
import '../../domain/sig.dart';
import 'wizard_models.dart';
import 'wizard_widgets.dart';

/// One medicine, with the evidence behind it — not a claim.
///
/// Every source that mentioned it is quoted in its own words. A red card shows
/// each conflicting reading side by side and cannot be confirmed until a
/// person picks one.
class MedicineCard extends StatelessWidget {
  const MedicineCard({
    super.key,
    required this.medicine,
    required this.decision,
    required this.finalSig,
    required this.index,
    required this.total,
    required this.onConfirm,
    required this.onEdit,
    required this.onPutBack,
    this.canConfirm = true,
    this.verdict,
    this.status,
    this.notes = const [],
    this.outLabel,
  });

  final MergedMedicine medicine;
  final MedicineDecision decision;
  final Sig finalSig;
  final int index;
  final int total;
  final bool canConfirm;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onPutBack;

  /// The card's colour when a pharmacy question is still open on it — red,
  /// whatever the sources agreed. Defaults to the merge's verdict.
  final Verdict? verdict;

  /// The line under the name, when something more pressing than the merge's
  /// own status needs saying.
  final String? status;

  /// The pharmacy questions on this medicine, each with where it stands.
  final List<Widget> notes;

  /// Instead of "Left out", when an answer folded this row into another.
  final String? outLabel;

  (Color, Color, Color) get _tone => switch (verdict ?? medicine.verdict) {
    Verdict.green => (AppColors.greenSoft, AppColors.green, AppColors.green),
    Verdict.amber => (AppColors.warnSoft, AppColors.warn, AppColors.warn),
    Verdict.red => (AppColors.redSoft, AppColors.red, AppColors.red),
  };

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final (fill, border, accent) = _tone;
    final name =
        decision.editedName ??
        decision.identity?.name ??
        PlainLanguage.displayName(medicine);

    if (decision.leftOut) {
      return ToneCard(
        fill: AppColors.paper,
        border: AppColors.hairline,
        child: Row(
          children: [
            Expanded(
              child: Text(
                outLabel ?? '$name — ${s.leftOut}',
                style: text.titleMedium?.copyWith(
                  color: AppColors.muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
            TextButton(onPressed: onPutBack, child: Text(s.putBack)),
          ],
        ),
      );
    }

    final plain = PlainLanguage.describe(finalSig, s);
    return ToneCard(
      fill: fill,
      border: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: text.headlineMedium?.copyWith(fontSize: 26),
                ),
              ),
              Text(
                '${index + 1} / $total',
                style: text.labelMedium?.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                (verdict ?? medicine.verdict) == Verdict.green
                    ? Icons.verified_outlined
                    : Icons.info_outline,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  status ?? PlainLanguage.status(medicine, s),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final m in medicine.evidence) _EvidenceRow(mention: m),
          ...notes,
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  plain,
                  style: text.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ),
              IconButton(
                tooltip: plain,
                icon: const Icon(Icons.volume_up_rounded),
                onPressed: () => VoiceScope.maybeOf(context)
                    ?.speak(this, '$name. $plain', L10n.languageOf(context)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: decision.confirmed
                        ? accent
                        : AppColors.ink,
                  ),
                  icon: Icon(
                    decision.confirmed
                        ? Icons.check_rounded
                        : Icons.check_box_outline_blank_rounded,
                  ),
                  label: Text(decision.confirmed ? s.confirmed : s.confirm),
                  onPressed: canConfirm ? onConfirm : onEdit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(s.edit),
                  onPressed: onEdit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.mention});

  final Mention mention;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              '${PlainLanguage.sourceLabel(mention.source, s)}:',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '“${mention.raw}”',
              style: const TextStyle(fontSize: 16, height: 1.3),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            mention.readOnline ? Icons.cloud_outlined : Icons.check_rounded,
            size: 18,
            color: mention.readOnline ? AppColors.muted : AppColors.green,
          ),
        ],
      ),
    );
  }
}
