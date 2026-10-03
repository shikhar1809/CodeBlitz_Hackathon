import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/big_choice_tile.dart';
import '../../core/widgets/rx_logo.dart';

/// Who is using this app?
///
/// Two tiles and nothing else. The answer decides which half of the product
/// this phone becomes, so it gets a whole screen to itself.
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key, required this.onChosen});

  final ValueChanged<AppRole> onChosen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = L10n.of(context);
    return VoicePrompt(
      text:
          '${s.roleQuestion} ${s.patient}: ${s.patientWhy}. '
          '${s.caregiver}: ${s.caregiverWhy}.',
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: AppTheme.pagePadding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight - AppTheme.pagePadding.vertical,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: RxWordmark(tagline: s.tagline)),
                    const SizedBox(height: 24),
                    Text(
                      s.roleQuestion,
                      textAlign: TextAlign.center,
                      style: text.headlineLarge?.copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 20),
                    BigChoiceTile(
                      icon: Icons.elderly_rounded,
                      title: s.patient,
                      subtitle: s.patientWhy,
                      onTap: () => onChosen(AppRole.patient),
                    ),
                    const SizedBox(height: 18),
                    BigChoiceTile(
                      icon: Icons.volunteer_activism_rounded,
                      title: s.caregiver,
                      subtitle: s.caregiverWhy,
                      onTap: () => onChosen(AppRole.caregiver),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
