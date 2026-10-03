import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_caretaker.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/widgets/big_choice_tile.dart';
import '../../core/widgets/onboarding_scaffold.dart';

/// Who are you to the patient? Family sees everything; a paid caretaker sees
/// the doses and notes, behind the patient's PIN.
class CaretakerTypeScreen extends StatelessWidget {
  const CaretakerTypeScreen({super.key, required this.onChosen, this.current});

  final ValueChanged<CaretakerType> onChosen;
  final CaretakerType? current;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: s.caretakerTypeQuestion,
      why: s.caretakerTypeWhy,
      voiceText:
          '${s.caretakerTypeQuestion} ${s.familyMember}: ${s.familyMemberWhy} '
          '${s.commercialCaretaker}: ${s.commercialCaretakerWhy}',
      children: [
        BigChoiceTile(
          icon: Icons.family_restroom_rounded,
          title: s.familyMember,
          subtitle: s.familyMemberWhy,
          selected: current == CaretakerType.family,
          onTap: () => onChosen(CaretakerType.family),
        ),
        const SizedBox(height: 18),
        BigChoiceTile(
          icon: Icons.medical_services_outlined,
          title: s.commercialCaretaker,
          subtitle: s.commercialCaretakerWhy,
          selected: current == CaretakerType.commercial,
          onTap: () => onChosen(CaretakerType.commercial),
        ),
      ],
    );
  }
}
