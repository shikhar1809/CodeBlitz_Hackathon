import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/plain_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/mention.dart';
import '../wizard_controller.dart';
import '../wizard_models.dart';
import '../wizard_widgets.dart';

/// Steps 2 and 5: a person checks what the phone understood.
///
/// The rows come from deterministic rules on the phone, not a language model,
/// and the screen says so: auditable, instant, no quota, and nothing
/// invented. A substitution at the counter — "Telma ki jagah Telmisartan de
/// diya" — becomes a row someone ticks or corrects, not a silent difference.
class TakeawaysStep extends StatelessWidget {
  const TakeawaysStep({
    super.key,
    required this.controller,
    required this.who,
    this.leading = const [],
    this.trailing = const [],
  });

  final VisitWizardController controller;
  final SourceKind who;

  /// Shown above and below the rows — the doctor step puts its toggle and
  /// the caretaker note here.
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final rows = controller.takeaways(who);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ...leading,
        StepIntro(s.takeawaysWhy),
        if (rows.isEmpty)
          InfoCard(text: s.nothingToCheck, icon: Icons.info_outline),
        for (var i = 0; i < rows.length; i++) ...[
          rows[i].isNote
              ? _NoteRow(
                  text: rows[i].name,
                  ticked: rows[i].ticked,
                  onTap: () => controller.toggleTakeaway(who, i),
                )
              : _TakeawayCard(
                  row: rows[i],
                  onToggle: () => controller.toggleTakeaway(who, i),
                  onEdit: () => _edit(context, i, rows[i]),
                ),
          const SizedBox(height: 14),
        ],
        TextButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: Text(s.addRow),
          onPressed: () => _edit(context, null, null),
        ),
        ...trailing,
      ],
    );
  }

  Future<void> _edit(BuildContext context, int? i, Takeaway? row) async {
    final result = await showEditMedicineSheet(
      context,
      name: row?.name ?? '',
      // Always the English form: it reads back through the parser exactly,
      // where the Hindi line would not.
      instruction: row == null
          ? ''
          : row.rawInstruction ?? PlainLanguage.describe(row.sig, english),
    );
    if (result == null) return;
    if (i == null) {
      controller.addTakeaway(who, result.$1, result.$2);
    } else {
      controller.editTakeaway(who, i, result.$1, result.$2);
    }
  }
}

class _TakeawayCard extends StatelessWidget {
  const _TakeawayCard({
    required this.row,
    required this.onToggle,
    required this.onEdit,
  });

  final Takeaway row;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final line = row.rawInstruction ?? PlainLanguage.describe(row.sig, s);
    return Material(
      color: row.ticked ? AppColors.greenSoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(
          color: row.ticked
              ? AppColors.green
              : row.clear
              ? AppColors.hairline
              : AppColors.warn,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: row.ticked,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.green,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      row.name,
                      style: text.titleLarge?.copyWith(fontSize: 22),
                    ),
                    Text(line, style: text.bodySmall?.copyWith(fontSize: 19)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Pill(
                          row.clear ? s.looksClear : s.pleaseCheck,
                          tone: row.clear ? PillTone.green : PillTone.warn,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 22),
                          label: Text(s.edit),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.muted,
                          ),
                          onPressed: onEdit,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.text,
    required this.ticked,
    required this.onTap,
  });

  final String text;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Row(
        children: [
          Checkbox(value: ticked, onChanged: (_) => onTap()),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 19),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Name and instruction, edited by a person. Returns (name, instruction).
Future<(String, String)?> showEditMedicineSheet(
  BuildContext context, {
  required String name,
  required String instruction,
}) {
  final s = L10n.of(context);
  final nameCtl = TextEditingController(text: name);
  final instCtl = TextEditingController(text: instruction);
  return showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: SafeArea(
        child: Padding(
          padding: AppTheme.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.medicineName,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
              Text(
                s.medicineNameWhy,
                style: Theme.of(sheet).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 16),
              Text(s.whenToTake, style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: instCtl,
                style: const TextStyle(fontSize: 22),
                decoration: const InputDecoration(
                  hintText: '1-0-1, after food',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (nameCtl.text.trim().isEmpty) return;
                  Navigator.pop(sheet, (
                    nameCtl.text.trim(),
                    instCtl.text.trim(),
                  ));
                },
                child: Text(s.save),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
