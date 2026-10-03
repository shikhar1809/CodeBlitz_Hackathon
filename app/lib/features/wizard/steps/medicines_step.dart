import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/plain_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/merge_engine.dart';
import '../medicine_card.dart';
import '../wizard_controller.dart';
import '../wizard_widgets.dart';
import 'takeaways_step.dart';

/// Step 7: one card per medicine. Every card is confirmed, fixed, or left
/// out before the plan moves on.
class MedicinesStep extends StatelessWidget {
  const MedicinesStep({super.key, required this.controller});

  final VisitWizardController controller;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final rows = controller.rows;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        StepIntro(s.medicinesWhy),
        for (var i = 0; i < rows.length; i++) ...[
          MedicineCard(
            medicine: rows[i],
            decision: controller.decisionOf(rows[i]),
            finalSig: controller.finalSig(rows[i]),
            index: i,
            total: rows.length,
            canConfirm: controller.canConfirm(rows[i]),
            onConfirm: () => controller.confirm(rows[i]),
            onEdit: () => _edit(context, rows[i]),
            onPutBack: () => controller.leaveOut(rows[i]),
          ),
          const SizedBox(height: 16),
        ],
        if (rows.isNotEmpty && !controller.allDecided)
          Text(
            s.confirmAllFirst,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, MergedMedicine m) async {
    final s = L10n.of(context);
    final sides = {for (final c in m.conflicts) ...c.sides}.toList();

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: AppTheme.pagePadding,
            children: [
              Text(
                PlainLanguage.displayName(m),
                style: Theme.of(sheet).textTheme.headlineMedium,
              ),
              if (sides.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(s.chooseOne, style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 10),
                for (var i = 0; i < sides.length; i++) ...[
                  ToneCard(
                    fill: AppColors.surface,
                    border: AppColors.hairline,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${PlainLanguage.sourceLabel(sides[i].source, s)}: '
                          '“${sides[i].raw}”',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          PlainLanguage.describe(sides[i].sig, s),
                          style: Theme.of(sheet).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => Navigator.pop(sheet, 'side:$i'),
                          child: Text(s.keepThis),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: Text(s.edit),
                onPressed: () => Navigator.pop(sheet, 'edit'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red, width: 2),
                ),
                icon: const Icon(Icons.remove_circle_outline),
                label: Text(s.leaveOut),
                onPressed: () => Navigator.pop(sheet, 'out'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    if (action.startsWith('side:')) {
      controller.choose(m, sides[int.parse(action.substring(5))]);
    } else if (action == 'out') {
      controller.leaveOut(m);
    } else if (action == 'edit') {
      final result = await showEditMedicineSheet(
        context,
        name: controller.finalName(m),
        instruction: PlainLanguage.describe(controller.finalSig(m), english),
      );
      if (result != null) controller.editRow(m, result.$1, result.$2);
    }
  }
}
