import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dev_flags.dart';
import '../../core/feedback/haptics.dart';
import '../../core/feedback/pressable.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_family.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import 'family_crypto.dart';
import 'family_sync.dart';

/// Onboarding: connect to the Winger Home Vault, then show the family code.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, required this.sync, required this.onDone});

  final FamilySync sync;
  final VoidCallback onDone;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late final _address = TextEditingController(
    text: widget.sync.vaultUrl ??
        (DemoProfile.vaultUrl.isNotEmpty ? DemoProfile.vaultUrl : null),
  );
  bool _busy = false;
  String? _error;
  String? _code;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final s = L10n.of(context);
    if (_address.text.trim().isEmpty) {
      Haptics.error();
      setState(() => _error = s.vaultNotFound);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.sync.reachable(_address.text);
    final code = ok ? await widget.sync.connect(_address.text) : null;
    if (!mounted) return;
    if (code == null) Haptics.error();
    setState(() {
      _busy = false;
      _code = code;
      _error = code == null ? s.vaultNotFound : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    if (_code != null) {
      final pretty = FamilyCrypto.pretty(_code!);
      return OnboardingScaffold(
        title: s.familyCodeTitle,
        why: s.familyCodeWhy,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.green),
              const SizedBox(width: 8),
              Flexible(child: Text(s.vaultConnected, style: text.titleMedium)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.hairline, width: 2),
            ),
            child: SelectableText(
              pretty,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(letterSpacing: 2, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: pretty)),
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy'),
          ),
          const SizedBox(height: 16),
          Pressable(child: FilledButton(onPressed: widget.onDone, child: Text(s.continueToApp))),
        ],
      );
    }
    return OnboardingScaffold(
      title: s.vaultTitle,
      why: s.vaultWhy,
      children: [
        BigTextField(
          controller: _address,
          hint: s.vaultHint,
          keyboardType: TextInputType.url,
          errorText: _error,
          onSubmitted: (_) => _connect(),
        ),
        const SizedBox(height: 24),
        Pressable(
          child: FilledButton(
            onPressed: _busy ? null : _connect,
            child: Text(_busy ? s.vaultChecking : s.vaultConnect),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  await widget.sync.later();
                  widget.onDone();
                },
          child: Text(s.vaultLater),
        ),
      ],
    );
  }
}
