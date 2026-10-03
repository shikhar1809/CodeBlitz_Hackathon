import 'package:flutter/material.dart';

import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/big_choice_tile.dart';
import '../../core/widgets/onboarding_scaffold.dart';

/// The only screen that speaks both languages at once — the user cannot have
/// chosen yet. Exactly two options.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.onChosen});

  final ValueChanged<AppLanguage> onChosen;

  @override
  Widget build(BuildContext context) {
    const optionStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    );
    return OnboardingScaffold(
      logoSize: 68,
      title: AppStrings.languageQuestionEn,
      why: AppStrings.languageQuestionHi,
      voiceText:
          '${AppStrings.languageQuestionEn} '
          '${AppStrings.languageQuestionHi}',
      voiceLanguage: AppLanguage.hi,
      children: [
        BigChoiceTile(
          title: AppStrings.englishOption,
          titleStyle: optionStyle,
          onTap: () => onChosen(AppLanguage.en),
        ),
        const SizedBox(height: 18),
        BigChoiceTile(
          title: AppStrings.hindiOption,
          titleStyle: optionStyle,
          onTap: () => onChosen(AppLanguage.hi),
        ),
      ],
    );
  }
}
