import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/plain_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/placement_advisor.dart';
import '../wizard_controller.dart';
import '../wizard_widgets.dart';

/// Step 8: where each new medicine sits beside what is already being taken,
/// with the reason in words. Then one button: approve and add.
class PlacementStep extends StatelessWidget {
  const PlacementStep({super.key, required this.controller});

  final VisitWizardController controller;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        StepIntro(s.placementWhy),
        for (final p in controller.placements) ...[
          _PlacementCard(placement: p),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _PlacementCard extends StatelessWidget {
  const _PlacementCard({required this.placement});

  final Placement placement;

  static const _cautions = {
    PlacementReason.suggested,
    PlacementReason.duplicate,
    PlacementReason.busy,
    PlacementReason.foodClash,
  };

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final m = placement.medicine;
    final caution = placement.reasons.any(_cautions.contains);

    return ToneCard(
      fill: caution ? AppColors.warnSoft : AppColors.greenSoft,
      border: caution ? AppColors.warn : AppColors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                caution ? Icons.info_outline : Icons.check_circle_outline,
                color: caution ? AppColors.warn : AppColors.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  PlainLanguage.titleCase(m.name),
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            PlainLanguage.describe(m.sig, s, withUnits: false),
            style: text.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in PlacementReason.values)
                if (placement.reasons.contains(r))
                  Pill(_label(r, s), tone: _tone(r)),
            ],
          ),
          if (placement.duplicateOf != null) ...[
            const SizedBox(height: 10),
            Text(
              PlainLanguage.titleCase(placement.duplicateOf!.name),
              style: text.labelMedium?.copyWith(fontSize: 17),
            ),
          ],
        ],
      ),
    );
  }

  static String _label(PlacementReason r, AppStrings s) => switch (r) {
    PlacementReason.kept => s.placementKept,
    PlacementReason.suggested => s.placementSuggested,
    PlacementReason.duplicate => s.placementDuplicate,
    PlacementReason.busy => s.placementBusy,
    PlacementReason.foodClash => s.placementFoodClash,
    PlacementReason.course => s.placementCourse,
  };

  static PillTone _tone(PlacementReason r) => switch (r) {
    PlacementReason.kept || PlacementReason.course => PillTone.amber,
    _ => PillTone.warn,
  };
}
