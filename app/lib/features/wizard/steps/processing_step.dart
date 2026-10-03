import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../wizard_controller.dart';
import '../wizard_widgets.dart';

/// Step 6: judge, extract, verify — on the phone.
///
/// It shows the work rather than a spinner, and says where it happened. When
/// the phone is online and a key is set, one extra card offers to read the
/// handwriting online ([online]); offline it is simply absent, because a
/// button that cannot work is worse than no button.
class ProcessingStep extends StatelessWidget {
  const ProcessingStep({super.key, required this.controller, this.online});

  final VisitWizardController controller;
  final Widget? online;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final done = !controller.analysing && controller.analysis != null;
    final found = controller.rows.length;

    Widget stage(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: done
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.green,
                    size: 32,
                  )
                : const Padding(
                    padding: EdgeInsets.all(5),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        stage(s.stageJudge),
        stage(s.stageExtract),
        stage(s.stageVerify),
        const SizedBox(height: 4),
        InfoCard(text: online == null ? s.onDeviceOnly : s.onDeviceDone),
        if (online != null) ...[const SizedBox(height: 16), online!],
        if (done) ...[
          const SizedBox(height: 20),
          Text(
            found == 0 ? s.foundNothing : s.foundMedicines(found),
            style: found == 0
                ? text.bodyMedium?.copyWith(color: AppColors.warn)
                : text.titleLarge,
          ),
        ],
      ],
    );
  }
}
