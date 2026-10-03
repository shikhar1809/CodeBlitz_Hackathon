import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../voice/voice_prompt.dart';
import 'rx_logo.dart';

/// One question per screen, centred.
///
/// Logo, the question, a line on why we are asking, then whatever answers it.
/// Scrolls when the keyboard is up, and centres when it is not — a column of
/// `Expanded` tiles here overflowed by 72 pixels on a small phone.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    this.why,
    required this.children,
    this.logoSize = 52,
    this.voiceText,
    this.voiceLanguage,
  });

  final String title;
  final String? why;
  final List<Widget> children;
  final double logoSize;

  /// What the voice reads. Defaults to the question and why it is asked.
  final String? voiceText;
  final AppLanguage? voiceLanguage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return VoicePrompt(
      text: voiceText ?? [title, ?why].join(' '),
      language: voiceLanguage,
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
                    Center(child: RxLogo(size: logoSize)),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: text.headlineLarge?.copyWith(fontSize: 32),
                    ),
                    if (why != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        why!,
                        textAlign: TextAlign.center,
                        style: text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 24),
                    ...children,
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

/// A large text field. Digits-only when [digits] is set.
class BigTextField extends StatelessWidget {
  const BigTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.digits,
    this.obscure = false,
    this.errorText,
    this.onSubmitted,
    this.autofocus = false,
    this.keyboardType,
    this.prefixText,
  });

  final TextEditingController controller;
  final String hint;

  /// Allow only digits, up to this many.
  final int? digits;
  final bool obscure;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputType? keyboardType;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscure,
      obscuringCharacter: '●',
      keyboardType:
          keyboardType ?? (digits != null ? TextInputType.number : null),
      inputFormatters: digits == null
          ? null
          : [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(digits),
            ],
      style: const TextStyle(fontSize: 24, letterSpacing: .5),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 18, color: AppColors.red),
        prefixText: prefixText,
        prefixStyle: const TextStyle(fontSize: 24, color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 24,
        ),
      ),
    );
  }
}

/// A small amber pill with an info icon. Used for honest demo hints.
class HintPill extends StatelessWidget {
  const HintPill({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.amberBorder),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? Icons.info_outline_rounded,
            size: 22,
            color: AppColors.ink,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: .2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small "Optional" tag beside a label.
class OptionalTag extends StatelessWidget {
  const OptionalTag({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amberBorder),
      ),
      child: Text(text, style: const TextStyle(fontSize: 15)),
    );
  }
}
