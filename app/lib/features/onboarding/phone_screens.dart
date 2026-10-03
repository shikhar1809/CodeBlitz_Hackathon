import 'package:flutter/material.dart';

import '../../core/feedback/haptics.dart';
import '../../core/feedback/pressable.dart';
import '../../core/l10n/l10n.dart';
import '../../core/widgets/onboarding_scaffold.dart';

/// The hardcoded demo code.
///
/// No SMS is sent: Firebase phone auth needs the paid Blaze plan. The OTP
/// screen says so in a visible hint rather than pretending.
const demoOtp = '1234';

/// Your mobile number — ten digits, +91 shown.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, required this.onSubmitted, this.initial});

  final ValueChanged<String> onSubmitted;
  final String? initial;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final digits = _controller.text.trim();
    if (digits.length != 10) {
      Haptics.error();
      setState(() => _error = L10n.of(context).phoneInvalid);
      return;
    }
    Haptics.tap();
    widget.onSubmitted(digits);
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: s.phoneTitle,
      why: s.phoneWhy,
      children: [
        BigTextField(
          controller: _controller,
          hint: s.phoneHint,
          digits: 10,
          keyboardType: TextInputType.phone,
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 28),
        Pressable(
          child: FilledButton(onPressed: _submit, child: Text(s.continueLabel)),
        ),
      ],
    );
  }
}

/// Enter the code. Used for the user's own number and, when given, for the
/// family member's number.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    required this.onVerified,
    this.title,
  });

  final String phone;
  final VoidCallback onVerified;
  final String? title;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim() != demoOtp) {
      Haptics.error();
      setState(() => _error = L10n.of(context).otpWrong);
      return;
    }
    Haptics.confirm();
    widget.onVerified();
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: widget.title ?? s.otpTitle,
      why: s.otpSentTo(widget.phone),
      children: [
        BigTextField(
          controller: _controller,
          hint: s.otpHint,
          digits: 4,
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 28),
        Pressable(
          child: FilledButton(onPressed: _submit, child: Text(s.verify)),
        ),
        const SizedBox(height: 20),
        HintPill(text: s.otpDemoHint),
      ],
    );
  }
}

/// Your name. A caretaker is linked later, by scanning their QR code — their
/// own verified number is in it, and alerts go there.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onSubmitted, this.initialName});

  final ValueChanged<String> onSubmitted;
  final String? initialName;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _name = TextEditingController(text: widget.initialName);
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    setState(
      () => _nameError = name.isEmpty ? L10n.of(context).nameMissing : null,
    );
    if (_nameError != null) {
      Haptics.error();
      return;
    }
    Haptics.tap();
    widget.onSubmitted(name);
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: s.profileTitle,
      children: [
        BigTextField(
          controller: _name,
          hint: s.nameHint,
          errorText: _nameError,
          keyboardType: TextInputType.name,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 28),
        Pressable(
          child: FilledButton(onPressed: _submit, child: Text(s.continueLabel)),
        ),
      ],
    );
  }
}

/// Set a PIN, or confirm it. The confirm step is the same screen with a
/// different title and a check.
class PinScreen extends StatefulWidget {
  const PinScreen({
    super.key,
    required this.onSubmitted,
    this.confirming = false,
    this.errorText,
  });

  final ValueChanged<String> onSubmitted;
  final bool confirming;
  final String? errorText;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.errorText;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _controller.text.trim();
    if (pin.length != 4) {
      Haptics.error();
      setState(() => _error = L10n.of(context).pinInvalid);
      return;
    }
    Haptics.tap();
    widget.onSubmitted(pin);
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: widget.confirming ? s.pinConfirmTitle : s.pinTitle,
      why: widget.confirming ? s.pinConfirmWhy : s.pinWhy,
      children: [
        BigTextField(
          controller: _controller,
          hint: widget.confirming ? s.pinConfirmTitle : s.pinTitle,
          digits: 4,
          obscure: true,
          errorText: _error,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 28),
        Pressable(
          child: FilledButton(onPressed: _submit, child: Text(s.continueLabel)),
        ),
      ],
    );
  }
}
