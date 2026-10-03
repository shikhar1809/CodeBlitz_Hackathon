import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../wizard/wizard_widgets.dart';
import 'pmjay_client.dart';

/// A PM-JAY card looked up while offline and found later. It is not saved as
/// the patient's until they say so — same rule as on the health screen.
class FoundCardBanner extends StatefulWidget {
  const FoundCardBanner({super.key});

  @override
  State<FoundCardBanner> createState() => _FoundCardBannerState();
}

class _FoundCardBannerState extends State<FoundCardBanner> {
  bool _answered = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.maybeOf(context);
    final json = state?.prefs.foundAyushmanCardJson;
    if (state == null || json == null || _answered) {
      return const SizedBox.shrink();
    }
    final card = AyushmanCard.fromJson(
      (jsonDecode(json) as Map).cast<String, Object?>(),
    );
    final s = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ToneCard(
        fill: AppColors.amberSoft,
        border: AppColors.amberBorder,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.pmjayFoundLater, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${card.name} · ${card.pmjayId}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (card.demo) Pill(s.demoData, tone: PillTone.warn),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                    onPressed: () async {
                      await state.prefs.confirmFoundAyushmanCard(card.pmjayId);
                      setState(() => _answered = true);
                    },
                    child: Text(s.yesThisIsMe),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await state.prefs.setFoundAyushmanCard(null);
                      setState(() => _answered = true);
                    },
                    child: Text(s.notMe),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
