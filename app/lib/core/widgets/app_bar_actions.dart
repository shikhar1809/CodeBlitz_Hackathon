import 'package:flutter/material.dart';

import '../app_state.dart';
import '../storage/app_prefs.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../l10n/strings_caretaker.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../../features/pairing/patient_pairing.dart';

/// Voice, language and account — the three controls on every home screen.
///
/// Each is a single tap with an immediate, visible result. None of them hides
/// behind a settings page, because the person most likely to need them is the
/// person least likely to go looking for one.
List<Widget> appBarActions(
  BuildContext context, {
  required VoidCallback onRestart,
}) {
  final state = AppScope.of(context);
  final s = L10n.of(context);
  return [
    IconButton(
      tooltip: state.voiceHelp ? s.voiceOn : s.voiceOff,
      icon: Icon(
        state.voiceHelp ? Icons.volume_up_rounded : Icons.volume_off_rounded,
      ),
      onPressed: () => state.setVoiceHelp(!state.voiceHelp),
    ),
    IconButton(
      tooltip: s.switchLanguage,
      icon: const Icon(Icons.translate_rounded),
      onPressed: state.toggleLanguage,
    ),
    IconButton(
      tooltip: s.account,
      icon: const Icon(Icons.manage_accounts_outlined),
      onPressed: () => _showAccount(context, onRestart),
    ),
    const SizedBox(width: 4),
  ];
}

void _showAccount(BuildContext context, VoidCallback onRestart) {
  final state = AppScope.of(context);
  final s = L10n.of(context);
  final name = state.prefs.name;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: AppTheme.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (name != null) ...[
              Text(name, style: Theme.of(sheet).textTheme.titleLarge),
              if (state.prefs.phoneNumber != null)
                Text(
                  '+91 ${state.prefs.phoneNumber}',
                  style: Theme.of(sheet).textTheme.bodySmall,
                ),
              const SizedBox(height: 20),
            ],
            if (state.prefs.role == AppRole.patient) ...[
              Text(
                s.yourCaretaker,
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _caretakerLine(sheet, state, s),
              const SizedBox(height: 20),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(s.changeRole),
              onPressed: () {
                Navigator.pop(sheet);
                state.setRole(null);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(s.startAgain),
              onPressed: () {
                Navigator.pop(sheet);
                onRestart();
              },
            ),
            const SizedBox(height: 8),
            Text(
              s.startAgainWhy,
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _caretakerLine(BuildContext sheet, AppState state, AppStrings s) {
  final linked = LinkedCaretaker.of(state.prefs);
  if (linked == null) {
    return Text(
      s.noCaretakerLinked,
      style: Theme.of(sheet).textTheme.bodyMedium,
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${linked.name} — ${s.caretakerTypeLabel(linked.type)}',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      Text('+91 ${linked.phone}', style: Theme.of(sheet).textTheme.bodySmall),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => _confirmUnlink(sheet, state, s, linked),
          child: Text(s.unlink),
        ),
      ),
    ],
  );
}

Future<void> _confirmUnlink(
  BuildContext sheet,
  AppState state,
  AppStrings s,
  LinkedCaretaker linked,
) async {
  final go = await showDialog<bool>(
    context: sheet,
    builder: (d) => AlertDialog(
      title: Text(s.unlinkQuestion(linked.name)),
      content: Text(s.unlinkWhy),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(s.unlink),
        ),
      ],
    ),
  );
  if (go != true) return;
  await unlinkCaretaker(state.prefs);
  if (sheet.mounted) Navigator.pop(sheet);
}
