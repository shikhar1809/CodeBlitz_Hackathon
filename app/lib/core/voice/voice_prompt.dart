import 'dart:async';

import 'package:flutter/widgets.dart';

import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import 'voice_guide.dart';

/// Reads a screen's question and its reason aloud, and repeats it every ten
/// seconds until the screen goes.
///
/// Put it around any screen that asks something. It claims the voice when it
/// appears and releases it when it leaves.
class VoicePrompt extends StatefulWidget {
  const VoicePrompt({
    super.key,
    required this.text,
    required this.child,
    this.repeatEvery = const Duration(seconds: 10),
    this.language,
  });

  final String text;

  /// Speak in this language regardless of the app's. The language screen
  /// needs it: the user has not chosen yet.
  final AppLanguage? language;
  final Widget child;
  final Duration repeatEvery;

  @override
  State<VoicePrompt> createState() => _VoicePromptState();
}

class _VoicePromptState extends State<VoicePrompt> {
  // Cached here: reading an inherited widget in dispose() throws "looking up
  // a deactivated widget's ancestor is unsafe".
  VoiceGuide? _guide;
  Timer? _repeat;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _guide = VoiceScope.maybeOf(context);
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _say());
      _repeat = Timer.periodic(widget.repeatEvery, (_) => _say());
    }
  }

  @override
  void didUpdateWidget(VoicePrompt old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _say();
  }

  void _say() {
    if (!mounted) return;
    _guide?.speak(
      this,
      widget.text,
      widget.language ?? L10n.languageOf(context),
    );
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _guide?.stopIfSpeaking(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    // Off in tests and release builds: the screen is exactly its child.
    if (guide == null || !VoiceStatusLine.visible) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned(
          left: 4,
          right: 4,
          bottom: 4,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: VoiceStatusLine(guide: guide),
          ),
        ),
      ],
    );
  }
}
