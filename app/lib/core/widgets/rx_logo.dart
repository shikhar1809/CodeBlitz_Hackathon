import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The R-star mark, on its amber rounded square.
class RxLogo extends StatelessWidget {
  const RxLogo({super.key, this.size = 72});

  final double size;

  static const asset = 'assets/images/logo_mark.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'RapidRX',
      image: true,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _Fallback(size: size),
      ),
    );
  }
}

/// Drawn stand-in, so a missing asset never leaves a hole where the brand goes.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.amber,
        borderRadius: BorderRadius.circular(size * .2),
        border: Border.all(color: AppColors.ink, width: size * .03),
      ),
      child: Text(
        'R',
        style: TextStyle(
          fontSize: size * .55,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// The mark with the product name beside it, and optionally the tagline.
class RxWordmark extends StatelessWidget {
  const RxWordmark({super.key, this.tagline, this.markSize = 48});

  final String? tagline;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RxLogo(size: markSize),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('RapidRX', style: text.titleLarge?.copyWith(height: 1.1)),
            if (tagline != null)
              Text(
                tagline!,
                style: text.labelMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
