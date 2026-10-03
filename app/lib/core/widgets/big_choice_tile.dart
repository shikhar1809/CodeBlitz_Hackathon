import 'package:flutter/material.dart';

import '../feedback/haptics.dart';
import '../feedback/pressable.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A large tile for every either/or question in the app.
///
/// An icon in an amber disc, a bold title, and a line of plain explanation.
/// The icon always means the thing — a person with a stick for the patient,
/// a hand holding a heart for the caregiver — and it never replaces the words.
class BigChoiceTile extends StatelessWidget {
  const BigChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.selected = false,
    this.compact = false,
    this.titleStyle,
    this.plainIcon = false,
    this.iconSize,
    this.padding,
    this.alignTop = false,
    this.minHeight = AppTheme.tapTarget,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;

  /// A shorter row layout, for menus that must fit without scrolling.
  final bool compact;

  final TextStyle? titleStyle;

  /// Draw the icon bare, without the amber disc.
  final bool plainIcon;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;

  /// Pin the content to the top when the tile is taller than it needs to be.
  final bool alignTop;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final border = BorderSide(
      color: selected ? AppColors.amber : AppColors.hairline,
      width: selected ? 3 : 2,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: [title, ?subtitle].join('. '),
      excludeSemantics: true,
      child: Pressable(
        enabled: onTap != null,
        child: Material(
          color: selected ? AppColors.amberSoft : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            side: border,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: Haptics.on(onTap),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: compact
                  ? _row(text)
                  : Align(
                      alignment: alignTop
                          ? Alignment.topCenter
                          : Alignment.center,
                      widthFactor: 1,
                      heightFactor: 1,
                      child: _column(text),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _column(TextTheme text) {
    return Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            plainIcon
                ? Icon(icon, size: iconSize ?? 44, color: AppColors.inkSoft)
                : _IconDisc(icon: icon!, size: iconSize ?? 84),
            SizedBox(height: plainIcon ? 6 : 12),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                titleStyle ??
                text.headlineMedium?.copyWith(fontSize: 28, letterSpacing: .2),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(TextTheme text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            _IconDisc(icon: icon!, size: 64),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: titleStyle ?? text.titleLarge?.copyWith(fontSize: 24),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: text.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 32,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.amber,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * .52, color: AppColors.inkSoft),
    );
  }
}
