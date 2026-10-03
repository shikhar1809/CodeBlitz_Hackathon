import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/rx_logo.dart';
import 'splash_screen.dart';

/// Three seconds of "saving your preference", already in the chosen language.
///
/// The whole app switches language behind this screen, so the pause is a
/// visible confirmation that the choice was heard rather than dead time.
class SavingScreen extends StatefulWidget {
  const SavingScreen({
    super.key,
    required this.onDone,
    this.duration = const Duration(seconds: 3),
  });

  final VoidCallback onDone;
  final Duration duration;

  @override
  State<SavingScreen> createState() => _SavingScreenState();
}

class _SavingScreenState extends State<SavingScreen> {
  Timer? _done;

  @override
  void initState() {
    super.initState();
    _done = Timer(widget.duration, widget.onDone);
  }

  @override
  void dispose() {
    _done?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RxLogo(size: 88),
            const SizedBox(height: 40),
            const LoadingBar(width: 180),
            const SizedBox(height: 24),
            Text(
              s.savingPreference,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
