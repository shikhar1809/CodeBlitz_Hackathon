import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_caretaker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import 'caretaker_pairing.dart';

/// The caretaker types what the patient's phone shows: the patient's name and
/// a 4-digit code. A match completes the link.
class CaretakerConfirmScreen extends StatefulWidget {
  const CaretakerConfirmScreen({
    super.key,
    required this.pairing,
    required this.onLinked,
    this.onBack,
  });

  final CaretakerPairing pairing;

  /// After the "connection successful" popup is closed.
  final VoidCallback onLinked;
  final VoidCallback? onBack;

  @override
  State<CaretakerConfirmScreen> createState() => _CaretakerConfirmScreenState();
}

class _CaretakerConfirmScreenState extends State<CaretakerConfirmScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  ConfirmError? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await widget.pairing.confirm(
      patientName: _name.text,
      code: _code.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error != null) return;
    final s = L10n.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.green,
          size: 56,
        ),
        title: Text(s.connectionSuccessful, textAlign: TextAlign.center),
        content: Text(
          s.linkedTo(widget.pairing.linked?.name ?? _name.text.trim()),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(d), child: Text(s.ok)),
        ],
      ),
    );
    if (mounted) widget.onLinked();
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: s.enterPatientCode,
      why: s.confirmWhy,
      children: [
        BigTextField(
          controller: _name,
          hint: s.patientNameHint,
          keyboardType: TextInputType.name,
          errorText: _error == ConfirmError.nameMissing
              ? s.patientNameMissing
              : null,
        ),
        const SizedBox(height: 16),
        BigTextField(
          controller: _code,
          hint: s.fourDigitCode,
          digits: 4,
          errorText: switch (_error) {
            ConfirmError.codeShort => s.codeShort,
            ConfirmError.wrongCode => s.codeWrong,
            _ => null,
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 28),
        FilledButton(onPressed: _submit, child: Text(s.connect)),
        if (widget.onBack != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: widget.onBack, child: Text(s.back)),
        ],
        const SizedBox(height: 8),
        HintPill(text: s.pairingDemoHint),
      ],
    );
  }
}
