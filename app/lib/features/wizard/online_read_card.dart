import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

import '../../ai/ai_config.dart';
import '../../ai/gemini_client.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../visit/visit.dart';
import 'wizard_controller.dart';

enum _State { checking, absent, offered, reading, done, failed }

/// "Read the handwriting online" — the only thing that ever leaves the phone,
/// and only when a person presses Read on a card that says exactly what goes
/// where.
///
/// Offline, or without a key, the card is absent. What it reads joins the
/// same merge, against the same printed sources: a better reader, not a
/// higher authority.
class OnlineReadCard extends StatefulWidget {
  const OnlineReadCard({
    super.key,
    required this.controller,
    required this.client,
    this.reachable,
  });

  final VisitWizardController controller;
  final GeminiClient client;

  /// Injected by tests; defaults to a real check of the endpoint.
  final Future<bool> Function()? reachable;

  @override
  State<OnlineReadCard> createState() => _OnlineReadCardState();
}

class _OnlineReadCardState extends State<OnlineReadCard> {
  _State _state = _State.checking;
  int _added = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final hasPhoto = widget.controller.visit.photos.any(
      (p) => p.label == PhotoLabel.prescription,
    );
    if (!widget.client.configured || !hasPhoto) {
      setState(() => _state = _State.absent);
      return;
    }
    final online = await (widget.reachable ?? AiConfig.reachable)();
    if (!mounted) return;
    setState(() => _state = online ? _State.offered : _State.absent);
  }

  Future<void> _read() async {
    setState(() => _state = _State.reading);
    final c = widget.controller;
    var added = 0;
    try {
      for (final p in c.visit.photosOf(PhotoLabel.prescription)) {
        if (!widget.client.hasBudget) break;
        final bytes = await XFile(p.path).readAsBytes();
        final reading = await widget.client.readPrescription(bytes);
        final mentions = reading.toMentions();
        c.onlineMentions.addAll(mentions);
        added += mentions.length;
      }
      await c.runAnalysis();
      if (mounted) {
        setState(() {
          _added = added;
          _state = _State.done;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _state = _State.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    if (_state == _State.checking || _state == _State.absent) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(s.readOnlineTitle, style: text.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Text(switch (_state) {
            _State.done => s.readOnlineDone(_added),
            _State.failed => s.readOnlineFailed,
            _State.reading => s.readingOnline,
            _ => s.readOnlineBody,
          }, style: text.bodySmall?.copyWith(fontSize: 17)),
          if (_state == _State.offered) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(140, 56)),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(s.readButton),
                onPressed: _read,
              ),
            ),
          ],
          if (_state == _State.reading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
