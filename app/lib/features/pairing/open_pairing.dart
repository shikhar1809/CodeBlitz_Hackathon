import 'package:flutter/material.dart';

import 'caretaker_confirm_screen.dart';
import 'caretaker_pairing.dart';
import 'caretaker_qr_screen.dart';

/// The QR code and the code entry, as pushed routes from the caretaker home —
/// the same screens onboarding shows as stages.
Future<void> openCaretakerPairing(
  BuildContext context, {
  required CaretakerPairing pairing,
}) {
  final nav = Navigator.of(context);
  return nav.push(
    MaterialPageRoute<void>(
      builder: (_) => CaretakerQrScreen(
        pairing: pairing,
        onLater: nav.pop,
        onEnterCode: () => nav.push(
          MaterialPageRoute<void>(
            builder: (_) => CaretakerConfirmScreen(
              pairing: pairing,
              onBack: nav.pop,
              onLinked: () => nav.popUntil((r) => r.isFirst),
            ),
          ),
        ),
      ),
    ),
  );
}
