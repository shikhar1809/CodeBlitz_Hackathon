import 'package:flutter/material.dart';

import '../../domain/medicine_form.dart';
import '../../domain/sig.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_alarm.dart';
import '../theme/app_colors.dart';

/// The slot's picture: a sunrise, a high sun, a sunset, a moon.
IconData slotIcon(DoseSlot s) => switch (s) {
  DoseSlot.morning => Icons.wb_twilight_rounded,
  DoseSlot.afternoon => Icons.wb_sunny_outlined,
  DoseSlot.evening => Icons.nights_stay_outlined,
  DoseSlot.night => Icons.bedtime_outlined,
};

/// Food timing as a picture with its words — never the picture alone.
class FoodPictogram extends StatelessWidget {
  const FoodPictogram({super.key, required this.food, required this.strings});

  final FoodTiming food;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    if (food == FoodTiming.unspecified) return const SizedBox.shrink();
    final before = food == FoodTiming.before;
    return _Chip(
      children: [
        Icon(
          before ? Icons.no_meals_rounded : Icons.restaurant_rounded,
          size: 22,
          color: AppColors.inkSoft,
        ),
        const SizedBox(width: 8),
        Text(
          before ? strings.beforeFood : strings.afterFood,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// One dot per tablet; a half-filled dot for half a tablet.
class DoseDots extends StatelessWidget {
  const DoseDots({super.key, required this.units, required this.strings});

  final double units;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final whole = units.floor();
    final half = units - whole >= .5;
    return Semantics(
      label: units == .5
          ? strings.halfTablet
          : strings.tablets(
              units == units.roundToDouble() ? units.round() : units,
            ),
      child: _Chip(
        children: [
          for (var i = 0; i < whole; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            const _Dot(),
          ],
          if (half) ...[
            if (whole > 0) const SizedBox(width: 6),
            const _Dot(half: true),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.half = false});

  final bool half;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 12,
    height: 12,
    child: half
        ? const Icon(Icons.contrast_rounded, size: 12, color: AppColors.ink)
        : const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
          ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.amberSoft.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.hairline, width: 2),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

/// The form's picture, for a medicine with no strip photo yet.
IconData formIcon(MedicineForm f) => switch (f) {
  MedicineForm.tablet => Icons.medication_rounded,
  MedicineForm.capsule => Icons.medication_outlined,
  MedicineForm.syrup => Icons.medication_liquid_rounded,
  MedicineForm.drops => Icons.water_drop_outlined,
  MedicineForm.injection => Icons.vaccines_outlined,
  MedicineForm.cream => Icons.sanitizer_outlined,
};

/// A large square with the form's picture and its word — never the picture
/// alone. Stands in for the strip photo.
class FormPictogram extends StatelessWidget {
  const FormPictogram({
    super.key,
    required this.form,
    required this.strings,
    this.size = 96,
  });

  final MedicineForm form;
  final AppStrings strings;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.amberSoft,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.amberBorder, width: 2),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(formIcon(form), size: size * .5, color: AppColors.inkSoft),
        const SizedBox(height: 2),
        Text(
          strings.formName(form),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
