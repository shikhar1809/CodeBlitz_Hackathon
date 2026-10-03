import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'dose_log_store.dart';

/// The month at a glance: green taken, red missed, hollow still to come,
/// faint for a day with nothing due.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({super.key, required this.month, required this.markOf});

  /// Any day in the month to show.
  final DateTime month;
  final DayMark Function(DateTime day) markOf;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.hairline, width: 2),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              const perRow = 10;
              final cell = box.maxWidth / perRow;
              return Wrap(
                children: [
                  for (var d = 1; d <= days; d++)
                    SizedBox(
                      width: cell,
                      height: cell,
                      child: Center(
                        child: _Day(
                          day: d,
                          mark: markOf(DateTime(month.year, month.month, d)),
                          size: cell * .72,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _Legend(color: AppColors.green, label: s.legendTaken),
            _Legend(color: AppColors.red, label: s.legendMissed),
            _Legend(
              color: AppColors.surface,
              border: AppColors.hairline,
              label: s.legendNothingDue,
            ),
          ],
        ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.day, required this.mark, required this.size});

  final int day;
  final DayMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (fill, border, ink) = switch (mark) {
      DayMark.taken => (AppColors.green, AppColors.green, Colors.white),
      DayMark.missed => (AppColors.red, AppColors.red, Colors.white),
      DayMark.pending => (AppColors.surface, AppColors.amber, AppColors.ink),
      DayMark.nothingDue => (
        AppColors.surface,
        AppColors.hairline,
        AppColors.muted,
      ),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      child: Text(
        '$day',
        style: TextStyle(
          fontSize: size * .42,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: border ?? color, width: 2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    ],
  );
}
