import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_caretaker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../wizard/wizard_widgets.dart';
import 'caretaker_pairing.dart';

/// The caretaker's QR code, for the patient to scan — and the same code as
/// text, for a patient with no working camera.
///
/// It expires after fifteen minutes and says so; "Make a new code" keeps the
/// same caretaker id. "I'll do this later" never traps anyone here: the home
/// screen offers it again.
class CaretakerQrScreen extends StatefulWidget {
  const CaretakerQrScreen({
    super.key,
    required this.pairing,
    required this.onEnterCode,
    required this.onLater,
    this.refreshEvery = const Duration(seconds: 20),
  });

  final CaretakerPairing pairing;
  final VoidCallback onEnterCode;
  final VoidCallback onLater;

  /// How often the "minutes left" line is redrawn.
  final Duration refreshEvery;

  @override
  State<CaretakerQrScreen> createState() => _CaretakerQrScreenState();
}

class _CaretakerQrScreenState extends State<CaretakerQrScreen> {
  Timer? _tick;

  CaretakerPairing get p => widget.pairing;

  @override
  void initState() {
    super.initState();
    p.addListener(_changed);
    _tick = Timer.periodic(widget.refreshEvery, (_) => _changed());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    p.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final code = p.encoded();
    final expired = p.expired;
    return OnboardingScaffold(
      title: s.pairingQrTitle,
      why: s.pairingQrWhy,
      logoSize: 40,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: expired ? AppColors.red : AppColors.hairline,
                width: 2,
              ),
            ),
            child: Opacity(
              opacity: expired ? .18 : 1,
              child: QrImageView(
                data: code,
                size: 236,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                semanticsLabel: s.pairingQrTitle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (expired) ...[
          ToneCard(
            fill: AppColors.redSoft,
            border: AppColors.red,
            padding: const EdgeInsets.all(14),
            child: Text(
              s.pairingExpired,
              style: const TextStyle(fontSize: 20, color: AppColors.red),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: Text(s.makeNewCode),
            onPressed: p.makeNewCode,
          ),
        ] else
          Center(
            child: Pill(s.pairingValidFor(p.minutesLeft), tone: PillTone.green),
          ),
        const SizedBox(height: 18),
        Text(s.orTypeThisCode, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: SelectableText(
            code,
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(s.shareCode),
            onPressed: expired
                ? null
                : () => SharePlus.instance.share(ShareParams(text: code)),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: widget.onEnterCode,
          child: Text(s.enterPatientCode),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: widget.onLater, child: Text(s.doThisLater)),
        const SizedBox(height: 8),
        HintPill(text: s.pairingDemoHint),
      ],
    );
  }
}
