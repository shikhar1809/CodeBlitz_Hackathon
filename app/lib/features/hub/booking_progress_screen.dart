import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/feedback/haptics.dart';
import '../../core/feedback/pressable.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_hub.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import 'hub_client.dart';

/// Follows one booking job on the Hub, live.
///
/// Polls every two seconds while the screen is open, and stops for good on
/// done, failed or cancelled. Two moments need the person: the clinic's OTP
/// (needs_input), and the filled form before it is submitted
/// (needs_approval). The second is the safety gate of the whole feature — the
/// agent never books on its own, and this screen never says yes for anyone:
/// approve is only ever sent from a tap on "Yes, book it".
class BookingProgressScreen extends StatefulWidget {
  const BookingProgressScreen({
    super.key,
    required this.client,
    required this.jobId,
    this.pollEvery = const Duration(seconds: 2),
  });

  final HubClient client;
  final String jobId;
  final Duration pollEvery;

  @override
  State<BookingProgressScreen> createState() => _BookingProgressScreenState();
}

class _BookingProgressScreenState extends State<BookingProgressScreen> {
  final _answer = TextEditingController();
  Timer? _timer;
  HubJob? _job;

  /// A poll in flight: a slow Hub must not get a queue of them.
  bool _polling = false;

  /// The last poll got no answer. Shown, and polling carries on.
  bool _unreachable = false;

  /// This phone was removed on the Hub. Nothing more can be done here.
  bool _unlinked = false;

  /// An answer, approval or stop on its way: the buttons wait for it.
  bool _sending = false;

  /// The question already answered, so the box does not come back while the
  /// Hub is still typing the OTP in.
  String? _answered;

  HubClient get _hub => widget.client;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(widget.pollEvery, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_polling || _unlinked) return;
    _polling = true;
    try {
      final job = await _hub.job(widget.jobId);
      if (!mounted) return;
      final was = _job?.status;
      setState(() {
        _job = job;
        _unreachable = false;
      });
      if (job.status.isFinal) {
        _timer?.cancel();
        if (was != job.status) {
          job.status == HubJobStatus.done ? Haptics.confirm() : Haptics.error();
        }
      } else if (was != job.status &&
          (job.status == HubJobStatus.needsInput ||
              job.status == HubJobStatus.needsApproval)) {
        // The person is needed: a buzz, like a dose alarm's first tap.
        Haptics.tap();
      }
    } on HubException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.problem == HubProblem.unlinked) {
          _unlinked = true;
          _timer?.cancel();
        } else {
          _unreachable = true;
        }
      });
    } finally {
      _polling = false;
    }
  }

  /// Send something to the Hub, then look again at once rather than in two
  /// seconds.
  Future<void> _act(Future<void> Function() call) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await call();
    } on HubException catch (e) {
      if (mounted) {
        if (e.problem == HubProblem.unlinked) setState(() => _unlinked = true);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(L10n.of(context).hubProblem(e.problem))),
          );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    await _refresh();
  }

  void _sendAnswer() {
    final text = _answer.text.trim();
    final question = _job?.question;
    if (text.isEmpty) return;
    Haptics.tap();
    _act(() async {
      await _hub.answer(widget.jobId, text);
      _answered = question;
      _answer.clear();
    });
  }

  void _decide(bool yes) {
    Haptics.tap();
    _act(() => _hub.approve(widget.jobId, approve: yes));
  }

  void _stop() {
    Haptics.tap();
    _act(() => _hub.cancel(widget.jobId));
  }

  String _voice(AppStrings s) {
    final job = _job;
    if (_unlinked) return s.hubProblem(HubProblem.unlinked);
    if (job == null) return s.bookingQueued;
    return switch (job.status) {
      HubJobStatus.queued => s.bookingQueued,
      HubJobStatus.running => s.bookingRunning,
      HubJobStatus.needsInput => '${s.hubAsks}. ${job.question ?? ''}',
      HubJobStatus.needsApproval =>
        '${s.approveTitle}. ${job.approval?.summary ?? ''} ${s.approveWhy}',
      HubJobStatus.done => '${s.bookedTitle}. ${job.result ?? ''}',
      HubJobStatus.failed => s.bookingFailedTitle,
      HubJobStatus.cancelled => s.bookingStoppedTitle,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final job = _job;
    final finished = _unlinked || (job?.status.isFinal ?? false);
    return VoicePrompt(
      text: _voice(s),
      child: Scaffold(
        appBar: AppBar(title: Text(s.bookingTitle)),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (_unlinked)
                _StatusCard.red(
                  icon: Icons.link_off_rounded,
                  title: s.hubProblem(HubProblem.unlinked),
                )
              else
                ..._status(s, job),
              if (_unreachable && !finished) ...[
                const SizedBox(height: 12),
                Text(
                  s.stillTrying,
                  style: const TextStyle(
                    fontSize: 20,
                    color: AppColors.warn,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (job != null && job.steps.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  s.whatHubDid,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final step in job.steps) _StepLine(step),
              ],
              const SizedBox(height: 24),
              if (!finished)
                Pressable(
                  enabled: !_sending,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: AppColors.red, width: 2),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(s.stopBooking),
                    onPressed: _sending ? null : _stop,
                  ),
                )
              else if (job?.status != HubJobStatus.failed)
                Pressable(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(s.finished),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _status(AppStrings s, HubJob? job) {
    final text = Theme.of(context).textTheme;
    if (job == null) return [_Working(s.bookingQueued)];
    switch (job.status) {
      case HubJobStatus.queued:
        return [_Working(s.bookingQueued)];
      case HubJobStatus.running:
        return [_Working(s.bookingRunning)];

      case HubJobStatus.needsInput:
        final waiting = _answered != null && _answered == job.question;
        return [
          _StatusCard.amber(
            icon: Icons.sms_outlined,
            title: s.hubAsks,
            children: [
              Text(job.question ?? '', style: text.bodyLarge),
              const SizedBox(height: 14),
              if (waiting)
                Text(s.sentWaiting, style: text.bodyMedium)
              else ...[
                BigTextField(
                  controller: _answer,
                  hint: s.answerHint,
                  autofocus: true,
                  onSubmitted: (_) => _sendAnswer(),
                ),
                const SizedBox(height: 12),
                Pressable(
                  enabled: !_sending,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.send_rounded),
                    label: Text(s.send),
                    onPressed: _sending ? null : _sendAnswer,
                  ),
                ),
              ],
            ],
          ),
        ];

      case HubJobStatus.needsApproval:
        final a = job.approval;
        return [
          _StatusCard.amber(
            icon: Icons.fact_check_outlined,
            title: s.approveTitle,
            children: [
              Text(
                s.approveWhy,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (a != null && a.summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(a.summary, style: text.bodyLarge),
              ],
              for (final f
                  in a?.fields ?? const <({String label, String value})>[])
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.label, style: text.labelMedium),
                      Text(
                        f.value,
                        style: text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Pressable(
                enabled: !_sending,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(s.yesBookIt),
                  onPressed: _sending ? null : () => _decide(true),
                ),
              ),
              const SizedBox(height: 12),
              Pressable(
                enabled: !_sending,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(s.noStop),
                  onPressed: _sending ? null : () => _decide(false),
                ),
              ),
            ],
          ),
        ];

      case HubJobStatus.done:
        return [
          _StatusCard.green(
            icon: Icons.event_available_rounded,
            title: s.bookedTitle,
            children: [
              if (job.result != null) Text(job.result!, style: text.bodyLarge),
            ],
          ),
        ];

      case HubJobStatus.failed:
        return [
          _StatusCard.red(
            icon: Icons.error_rounded,
            title: s.bookingFailedTitle,
            children: [
              if (job.error != null) Text(job.error!, style: text.bodyLarge),
              const SizedBox(height: 16),
              Pressable(
                child: FilledButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(s.hubTryAgain),
                  // Back to the form, still filled in.
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ];

      case HubJobStatus.cancelled:
        return [
          _StatusCard(
            fill: AppColors.surface,
            border: AppColors.hairline,
            iconColor: AppColors.muted,
            icon: Icons.stop_circle_outlined,
            title: s.bookingStoppedTitle,
            children: [Text(s.bookingStoppedWhy, style: text.bodyMedium)],
          ),
        ];
    }
  }
}

/// A spinner and what the Hub is doing.
class _Working extends StatelessWidget {
  const _Working(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.hairline, width: 2),
      ),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppColors.amberDark,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

/// A coloured card: an icon and a title, then whatever the state needs.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.fill,
    required this.border,
    required this.iconColor,
    required this.icon,
    required this.title,
    this.children = const [],
  });

  const _StatusCard.green({
    required this.icon,
    required this.title,
    this.children = const [],
  }) : fill = AppColors.greenSoft,
       border = AppColors.green,
       iconColor = AppColors.green;

  const _StatusCard.amber({
    required this.icon,
    required this.title,
    this.children = const [],
  }) : fill = AppColors.amberSoft,
       border = AppColors.amberBorder,
       iconColor = AppColors.amberDark;

  const _StatusCard.red({
    required this.icon,
    required this.title,
    this.children = const [],
  }) : fill = AppColors.redSoft,
       border = AppColors.red,
       iconColor = AppColors.red;

  final Color fill;
  final Color border;
  final Color iconColor;
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine(this.step);

  final HubStep step;

  @override
  Widget build(BuildContext context) {
    final t = step.at;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_rounded, size: 24, color: AppColors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(time, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
