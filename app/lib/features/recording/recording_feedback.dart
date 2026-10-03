import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_recording.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'recording_controller.dart';

/// The answer to "did it record?", under every microphone in the app.
///
/// While recording: a pulsing red dot, the time, and a level meter that moves
/// with the voice. After: a green tick and "Recorded 0:42" with play, record again
/// and delete — or an amber "Nothing heard, try again". Idle and deleted
/// draw nothing.
///
/// The clock is a [Ticker]: it drives [RecordingController.tick] from frame
/// time, which a widget test advances with `pump(duration)` — no real timer
/// to hang a test.
class RecordingFeedback extends StatefulWidget {
  const RecordingFeedback({
    super.key,
    required this.controller,
    required this.liveLabel,
    this.onPlay,
    this.onRedo,
    this.onDelete,
    this.onRetry,
    this.margin = const EdgeInsets.only(top: 12),
  });

  final RecordingController controller;

  /// "Recording" or "Listening".
  final String liveLabel;

  /// Null when there is nothing to play — dictation keeps words, not audio.
  final VoidCallback? onPlay;
  final VoidCallback? onRedo;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;

  /// Around the panel, only when there is a panel.
  final EdgeInsetsGeometry margin;

  @override
  State<RecordingFeedback> createState() => _RecordingFeedbackState();
}

class _RecordingFeedbackState extends State<RecordingFeedback>
    with TickerProviderStateMixin {
  late final Ticker _clock = createTicker((t) => widget.controller.tick(t));
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(RecordingFeedback old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  /// Run the clock and the pulse exactly while the mic is open.
  void _sync() {
    final on = widget.controller.isRecording;
    if (on && !_clock.isActive) {
      _clock.start();
      _pulse.repeat(reverse: true);
    } else if (!on && _clock.isActive) {
      _clock.stop();
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _clock.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final panel = switch (c.phase) {
        RecordingPhase.idle || RecordingPhase.deleted => null,
        RecordingPhase.recording => _live(context, c),
        RecordingPhase.recorded => _kept(context, c),
        RecordingPhase.tooShort ||
        RecordingPhase.silent => _nothing(context, c),
      };
      if (panel == null) return const SizedBox.shrink();
      return Padding(
        padding: widget.margin,
        child: Semantics(container: true, liveRegion: true, child: panel),
      );
    },
  );

  Widget _live(BuildContext context, RecordingController c) {
    final s = L10n.of(context);
    return _Panel(
      fill: AppColors.redSoft,
      border: AppColors.red,
      child: Row(
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: .25).animate(_pulse),
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.liveLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.red,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            RecordingController.clock(c.elapsed),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: s.soundLevel,
            value: '${(c.level * 100).round()}%',
            child: _LevelMeter(levels: c.history),
          ),
        ],
      ),
    );
  }

  Widget _kept(BuildContext context, RecordingController c) {
    final s = L10n.of(context);
    final length = c.length == null
        ? null
        : RecordingController.clock(c.length!);
    return _Panel(
      fill: AppColors.greenSoft,
      border: AppColors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.green,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.recordedFor(length),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              if (widget.onPlay != null)
                _Action(
                  icon: Icons.play_arrow_rounded,
                  label: s.playRecording,
                  onTap: widget.onPlay!,
                ),
              if (widget.onRedo != null)
                _Action(
                  icon: Icons.replay_rounded,
                  label: s.recordAgain,
                  onTap: widget.onRedo!,
                ),
              if (widget.onDelete != null)
                _Action(
                  icon: Icons.delete_outline_rounded,
                  label: s.deleteRecording,
                  onTap: widget.onDelete!,
                  color: AppColors.red,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nothing(BuildContext context, RecordingController c) {
    final s = L10n.of(context);
    return _Panel(
      fill: AppColors.warnSoft,
      border: AppColors.warn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hearing_disabled_rounded,
                color: AppColors.warn,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.nothingHeard,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            c.phase == RecordingPhase.tooShort ? s.tooShortWhy : s.silentWhy,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              height: 1.25,
            ),
          ),
          if (widget.onRetry != null) ...[
            const SizedBox(height: 4),
            _Action(
              icon: Icons.mic_rounded,
              label: s.tryAgain,
              onTap: widget.onRetry!,
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.fill, required this.border, required this.child});

  final Color fill;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: AppTheme.tapTarget),
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(AppTheme.radius * .8),
      border: Border.all(color: border, width: 2),
    ),
    alignment: Alignment.centerLeft,
    child: child,
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontFamilyFallback: AppTheme.fontFamilyFallback,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    icon: Icon(icon, size: 26),
    label: Text(label),
    onPressed: onTap,
  );
}

/// Recent loudness as bars, newest on the right.
class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.levels});

  final List<double> levels;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final v in levels) ...[
          Container(
            width: 4,
            height: 4 + v * 30,
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 3),
        ],
      ],
    ),
  );
}
