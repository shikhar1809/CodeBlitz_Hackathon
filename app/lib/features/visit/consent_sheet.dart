import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';

/// Consent is a gate, not a checkbox (ADR-21).
///
/// It appears before the first capture of a visit, says in plain words where
/// the photos go, and nothing is captured unless the answer is yes.
Future<bool> askConsent(BuildContext context) async {
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => const ConsentSheet(),
  );
  return agreed ?? false;
}

class ConsentSheet extends StatelessWidget {
  const ConsentSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return VoicePrompt(
      text: '${s.consentTitle}. ${s.consentBody}',
      child: SafeArea(
        child: Padding(
          padding: AppTheme.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: AppColors.inkSoft,
              ),
              const SizedBox(height: 12),
              Text(
                s.consentTitle,
                textAlign: TextAlign.center,
                style: text.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(s.consentBody, style: text.bodyMedium),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.consentAgree),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.consentDecline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
