import 'package:flutter/material.dart';

import '../../core/feedback/haptics.dart';
import '../../core/feedback/pressable.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_caretaker.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../platform/qr_scanner.dart';
import '../caregiver/whatsapp_alerts.dart';
import 'patient_pairing.dart';

/// The patient scans (or types) a caretaker's code, sets a PIN if they are
/// paid, and shows the 4-digit code that finishes the link on the other phone.
class PatientScanScreen extends StatefulWidget {
  const PatientScanScreen({
    super.key,
    required this.pairing,
    this.scanner,
    this.alerts,
  });

  final PatientPairing pairing;
  final QrScanner? scanner;
  final WhatsAppAlerts? alerts;

  @override
  State<PatientScanScreen> createState() => _PatientScanScreenState();
}

class _PatientScanScreenState extends State<PatientScanScreen> {
  late final QrScanner _scanner = widget.scanner ?? QrScanner();
  late final WhatsAppAlerts _alerts = widget.alerts ?? WhatsAppAlerts();
  final _typed = TextEditingController();
  final _pin = TextEditingController();
  final _pinAgain = TextEditingController();

  PatientPairing get p => widget.pairing;

  @override
  void initState() {
    super.initState();
    p.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    p.removeListener(_changed);
    _scanner.dispose();
    _typed.dispose();
    _pin.dispose();
    _pinAgain.dispose();
    super.dispose();
  }

  void _submitScan(String raw) {
    if (p.submit(raw)) Haptics.confirm();
  }

  Future<void> _accept() async {
    Haptics.tap();
    await p.accept();
  }

  Future<void> _setPin() async {
    final ok = await p.setPin(_pin.text, _pinAgain.text);
    if (ok) {
      Haptics.confirm();
    } else {
      Haptics.error();
    }
  }

  Future<void> _sendCode() async {
    final found = p.found;
    final code = p.confirmationCode;
    if (found == null || code == null) return;
    Haptics.tap();
    final s = L10n.of(context);
    await _alerts.openInWhatsApp(
      found.phone,
      s.pairingWhatsApp(p.prefs.name ?? '', code),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (p.step) {
      ScanStep.scan => _scan(),
      ScanStep.found => _found(),
      ScanStep.setPin => _pinStep(),
      ScanStep.done => _done(),
    };
  }

  Widget _scan() {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: s.scanCaretakerQr,
      why: s.pointCamera,
      logoSize: 40,
      children: [
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _scanner.view(
              onCode: _submitScan,
              problem: (why) => _problem(why, s),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_scanner.supported)
          Align(
            alignment: Alignment.centerRight,
            child: ValueListenableBuilder<bool>(
              valueListenable: _scanner.torchOn,
              builder: (_, on, _) => TextButton.icon(
                onPressed: _scanner.toggleTorch,
                icon: Icon(
                  on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
                label: Text(s.torch),
              ),
            ),
          ),
        if (p.error != null) ...[
          const SizedBox(height: 8),
          Text(
            pairingErrorMessage(p.error!, s),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(s.orTypeCode, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        BigTextField(
          controller: _typed,
          hint: s.codeFieldHint,
          onSubmitted: _submitScan,
        ),
        const SizedBox(height: 16),
        Pressable(
          child: FilledButton(
            onPressed: () => _submitScan(_typed.text),
            child: Text(s.checkCode),
          ),
        ),
      ],
    );
  }

  Widget _problem(ScanProblem why, AppStrings s) {
    final text = switch (why) {
      ScanProblem.permissionDenied => s.cameraDenied,
      ScanProblem.unsupported => s.cannotScanHere,
      ScanProblem.failed => s.cameraFailed,
    };
    return ColoredBox(
      color: AppColors.paper,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              if (why != ScanProblem.unsupported) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: _scanner.retry, child: Text(s.tryAgain)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _found() {
    final s = L10n.of(context);
    final c = p.found!;
    final family = c.type == CaretakerType.family;
    return OnboardingScaffold(
      title: s.whoIsIt(c.name, c.type),
      why: family ? s.familySees(c.name) : s.commercialSees(c.name),
      logoSize: 40,
      children: [
        Pressable(
          child: FilledButton(
            onPressed: _accept,
            child: Text(s.linkName(c.name)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: p.rescan, child: Text(s.notThem)),
      ],
    );
  }

  Widget _pinStep() {
    final s = L10n.of(context);
    final name = p.found!.name;
    final err = switch (p.pinProblem) {
      PinProblem.short => s.caretakerPinShort,
      PinProblem.mismatch => s.caretakerPinMismatch,
      null => null,
    };
    return OnboardingScaffold(
      title: s.pinForTitle(name),
      why: s.pinForWhy(name),
      logoSize: 40,
      children: [
        BigTextField(
          controller: _pin,
          hint: s.pinTitle,
          digits: 4,
          obscure: true,
          errorText: err,
        ),
        const SizedBox(height: 16),
        BigTextField(
          controller: _pinAgain,
          hint: s.pinAgain,
          digits: 4,
          obscure: true,
        ),
        const SizedBox(height: 24),
        Pressable(
          child: FilledButton(onPressed: _setPin, child: Text(s.continueLabel)),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: p.rescan, child: Text(s.notThem)),
      ],
    );
  }

  Widget _done() {
    final s = L10n.of(context);
    final name = p.found!.name;
    return OnboardingScaffold(
      title: s.connectionSuccessful,
      why: s.showCodeTo(name),
      logoSize: 40,
      children: [
        Text(
          p.confirmationCode ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 24),
        Pressable(
          child: FilledButton.icon(
            onPressed: _sendCode,
            icon: const Icon(Icons.chat_rounded),
            label: Text(s.sendCodeWhatsApp),
          ),
        ),
        const SizedBox(height: 16),
        Pressable(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(s.ok),
          ),
        ),
      ],
    );
  }
}
