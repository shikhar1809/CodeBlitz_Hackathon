import 'package:flutter/material.dart';

import '../../core/feedback/haptics.dart';
import '../../core/feedback/pressable.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../wizard/wizard_widgets.dart';
import 'health_profile.dart';
import 'health_profile_controller.dart';
import 'pmjay_client.dart';

/// Age (required), height and weight (optional), and an optional Ayushman
/// card — looked up, shown, and saved only once the patient says "this is me".
class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({
    super.key,
    required this.controller,
    required this.onDone,
  });

  final HealthProfileController controller;
  final VoidCallback onDone;

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  late final _age = TextEditingController(text: _s(c.prefs.age));
  late final _height = TextEditingController(text: _s(c.prefs.heightCm));
  late final _weight = TextEditingController(text: _s(c.prefs.weightKg));
  late final _ayushman = TextEditingController(text: c.prefs.ayushmanId);

  HealthProfileController get c => widget.controller;

  static String _s(int? v) => v?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    c.removeListener(_changed);
    for (final t in [_age, _height, _weight, _ayushman]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await c.submit(
      age: _age.text,
      height: _height.text,
      weight: _weight.text,
      ayushmanId: _ayushman.text,
    );
    if (ok) {
      widget.onDone();
    } else {
      Haptics.error();
    }
  }

  String? _error(HealthError? e, String missing, String range) => switch (e) {
    HealthError.missing => missing,
    HealthError.outOfRange => range,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return OnboardingScaffold(
      title: s.healthTitle,
      why: s.healthWhy,
      children: [
        _Label(s.ageLabel),
        BigTextField(
          controller: _age,
          hint: s.ageLabel,
          digits: 3,
          errorText: _error(c.ageError, s.ageMissing, s.ageOutOfRange),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(s.heightLabel, optional: s.optional),
                  BigTextField(
                    controller: _height,
                    hint: 'cm',
                    digits: 3,
                    errorText: _error(c.heightError, '', s.heightOutOfRange),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(s.weightLabel, optional: s.optional),
                  BigTextField(
                    controller: _weight,
                    hint: 'kg',
                    digits: 3,
                    errorText: _error(c.weightError, '', s.weightOutOfRange),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Label(s.ayushmanLabel, optional: s.optional),
        BigTextField(
          controller: _ayushman,
          hint: s.ayushmanHint,
          keyboardType: TextInputType.text,
          errorText: switch (c.state) {
            PmjayState.badFormat => s.pmjayBadFormat,
            PmjayState.notFound => s.pmjayNotFound,
            _ => null,
          },
        ),
        if (c.state == PmjayState.queued) ...[
          const SizedBox(height: 8),
          HintPill(text: s.pmjayQueued, icon: Icons.cloud_off_rounded),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: c.state == PmjayState.fetching
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : const Icon(Icons.badge_outlined),
          label: Text(
            c.state == PmjayState.fetching ? s.fetchingPmjay : s.fetchPmjay,
          ),
          onPressed: c.state == PmjayState.fetching
              ? null
              : () => c.fetch(_ayushman.text),
        ),
        if (c.card != null) ...[
          const SizedBox(height: 14),
          _CardView(
            card: c.card!,
            confirmed: c.state == PmjayState.confirmed,
            onYes: c.confirmCard,
            onNo: () {
              _ayushman.clear();
              c.rejectCard();
            },
          ),
        ],
        const SizedBox(height: 26),
        Pressable(
          child: FilledButton(
            onPressed: Haptics.on(_submit),
            child: Text(s.continueLabel),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.optional});

  final String text;
  final String? optional;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        if (optional != null) OptionalTag(text: optional!),
      ],
    ),
  );
}

class _CardView extends StatelessWidget {
  const _CardView({
    required this.card,
    required this.confirmed,
    required this.onYes,
    required this.onNo,
  });

  final AyushmanCard card;
  final bool confirmed;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return ToneCard(
      fill: confirmed ? AppColors.greenSoft : AppColors.surface,
      border: confirmed ? AppColors.green : AppColors.amberBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(card.name, style: text.titleLarge)),
              if (card.demo) Pill(s.demoData, tone: PillTone.warn),
            ],
          ),
          const SizedBox(height: 8),
          _row(s.pmjayIdLabel, card.pmjayId),
          _row(s.familyIdLabel, card.familyId),
          _row(s.stateLabel, card.state),
          const SizedBox(height: 6),
          Text(
            s.eligibleCover(card.cover),
            style: text.titleMedium?.copyWith(color: AppColors.green),
          ),
          Text(s.validTill(card.validTill), style: text.bodySmall),
          const SizedBox(height: 14),
          if (confirmed)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.green),
                const SizedBox(width: 8),
                Text(s.cardConfirmed, style: text.titleMedium),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppTheme.tapTarget),
                      backgroundColor: AppColors.green,
                    ),
                    onPressed: onYes,
                    child: Text(s.yesThisIsMe),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(onPressed: onNo, child: Text(s.notMe)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            k,
            style: const TextStyle(fontSize: 16, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
