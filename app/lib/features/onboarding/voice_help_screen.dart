import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/big_choice_tile.dart';
import '../../core/widgets/onboarding_scaffold.dart';

/// Do you need voice help? If yes, every later screen reads its question and
/// the reason for it aloud, in the chosen language.
class VoiceHelpScreen extends StatelessWidget {
  const VoiceHelpScreen({super.key, required this.onChosen, this.current});

  final ValueChanged<bool> onChosen;

  /// Highlights the current answer when the user comes back to this screen.
  final bool? current;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: s.voiceQuestion,
      why: s.voiceWhy,
      children: [
        BigChoiceTile(
          icon: Icons.volume_up_rounded,
          plainIcon: true,
          title: s.yes,
          selected: current ?? true,
          onTap: () => onChosen(true),
        ),
        const SizedBox(height: 18),
        BigChoiceTile(
          icon: Icons.volume_off_rounded,
          plainIcon: true,
          title: s.no,
          selected: current == false,
          onTap: () => onChosen(false),
        ),
      ],
    );
  }
}
