import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The line under a step's title that says what to do and why.
class StepIntro extends StatelessWidget {
  const StepIntro(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 19),
    ),
  );
}

enum PillTone { neutral, amber, strong, green, warn, red }

/// A small rounded label. Colour carries tone, the word carries meaning.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = PillTone.neutral, this.onTap});

  final String text;
  final PillTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (fill, border, ink) = switch (tone) {
      PillTone.neutral => (
        AppColors.paper,
        AppColors.hairline,
        AppColors.muted,
      ),
      PillTone.amber => (
        AppColors.amberSoft,
        AppColors.amberBorder,
        AppColors.ink,
      ),
      PillTone.strong => (AppColors.amber, AppColors.amberDark, AppColors.ink),
      PillTone.green => (AppColors.surface, AppColors.green, AppColors.green),
      PillTone.warn => (AppColors.warnSoft, AppColors.warn, AppColors.warn),
      PillTone.red => (AppColors.redSoft, AppColors.red, AppColors.red),
    };
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: border,
          width: tone == PillTone.strong ? 2 : 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(widthFactor: 1, child: pill),
      ),
    );
  }
}

/// An amber note with an icon: what happened, said plainly.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.text,
    this.icon = Icons.bolt_outlined,
    this.child,
  });

  final String text;
  final IconData icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.amberSoft,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      border: Border.all(color: AppColors.amberBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: AppColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        ?child,
      ],
    ),
  );
}

/// A tinted, bordered card — the frame for every row a person decides on.
class ToneCard extends StatelessWidget {
  const ToneCard({
    super.key,
    required this.fill,
    required this.border,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Color fill;
  final Color border;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      border: Border.all(color: border, width: 2),
    ),
    child: child,
  );
}
