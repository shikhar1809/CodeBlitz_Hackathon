import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Constrains the app to a portrait phone frame on desktop and web.
///
/// The Android APK is the product. Windows and the browser exist so a laptop
/// demo shows exactly what the phone shows — so rather than designing a second,
/// wide layout nobody will use, every target renders the same portrait screen.
class PhoneShell extends StatelessWidget {
  const PhoneShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitsAPhone = constraints.maxWidth <= AppTheme.phoneWidth + 40;
        if (fitsAPhone) return child;

        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight.clamp(0.0, AppTheme.phoneHeight)
            : AppTheme.phoneHeight;

        return ColoredBox(
          color: const Color(0xFFEDE7D6),
          child: Center(
            child: Container(
              width: AppTheme.phoneWidth,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.hairline, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 32,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(size: Size(AppTheme.phoneWidth, height)),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
