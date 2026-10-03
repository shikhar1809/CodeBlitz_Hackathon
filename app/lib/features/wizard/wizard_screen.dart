import 'package:flutter/material.dart';

import '../../core/feedback/haptics.dart';
import '../../core/feedback/pressable.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/voice/voice_prompt.dart';
import '../../domain/mention.dart';
import '../../domain/scheduled_medicine.dart';
import '../../platform/dictation.dart';
import '../../platform/gallery_scanner.dart';
import '../recording/clip_player.dart';
import '../visit/capture_tools.dart';
import '../visit/consent_sheet.dart';
import 'steps/doctor_verify_step.dart';
import 'steps/medicines_step.dart';
import 'steps/photos_step.dart';
import 'steps/placement_step.dart';
import 'steps/processing_step.dart';
import 'steps/takeaways_step.dart';
import 'steps/words_step.dart';
import 'wizard_controller.dart';
import 'wizard_models.dart';

/// Adding a prescription, in eight steps.
///
/// Every step shows where it is, a Back, a Next, and — only where it is
/// honest to — a Skip.
class WizardScreen extends StatefulWidget {
  const WizardScreen({
    super.key,
    required this.controller,
    this.dictation,
    this.audio,
    this.player,
    this.photos,
    this.scanner,
    this.consent = askConsent,
    this.onApproved,
    this.onlineCard,
  });

  final VisitWizardController controller;
  final Dictation? dictation;
  final AudioCapture? audio;

  /// Plays a kept recording back.
  final ClipPlayer? player;
  final PhotoCapture? photos;
  final GalleryScanner? scanner;
  final Future<bool> Function(BuildContext) consent;

  /// Called after approval, with what went onto the schedule.
  final void Function(List<ScheduledMedicine>)? onApproved;

  /// The consent-gated "read the handwriting online" card, when available.
  final Widget Function(VisitWizardController)? onlineCard;

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  late final Dictation _dictation = widget.dictation ?? Dictation();
  late final AudioCapture _audio = widget.audio ?? AudioCapture();
  late final ClipPlayer _player = widget.player ?? ClipPlayer();
  late final PhotoCapture _photos = widget.photos ?? PhotoCapture();
  late final GalleryScanner _scanner = widget.scanner ?? GalleryScanner();
  bool _approving = false;
  bool _asked = false;

  VisitWizardController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    // Consent is a gate: asked once, before anything is captured.
    WidgetsBinding.instance.addPostFrameCallback((_) => _askConsent());
  }

  Future<void> _askConsent() async {
    if (c.visit.consent || _asked || !mounted) return;
    _asked = true;
    final ok = await widget.consent(context);
    if (!mounted) return;
    if (!ok) {
      Navigator.of(context).maybePop();
      return;
    }
    c.visit.consent = true;
    await c.repository.save(c.visit);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    c.removeListener(_changed);
    _audio.dispose();
    if (widget.player == null) _player.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _approving = true);
    final approved = await c.approve();
    if (!mounted) return;
    widget.onApproved?.call(approved);
    final s = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(approved);
    // Two notices, because they are two different facts: the prescription is
    // kept, and the daily schedule changed.
    messenger
      ..showSnackBar(SnackBar(content: Text(s.prescriptionSaved)))
      ..showSnackBar(SnackBar(content: Text(s.scheduleUpdated)));
  }

  String _title(AppStrings s) => switch (c.step) {
    WizardStep.doctorWords => s.doctorWordsTitle,
    WizardStep.doctorTakeaways => s.takeawaysTitle,
    WizardStep.photos => s.photosTitle,
    WizardStep.pharmacyWords => s.pharmacyTitle,
    WizardStep.chemistTakeaways => s.chemistTakeawaysTitle,
    WizardStep.processing => s.processingTitle,
    WizardStep.medicines => s.medicinesTitle,
    WizardStep.placement => s.placementTitle,
  };

  Widget _body() => switch (c.step) {
    WizardStep.doctorWords => WordsStep(
      key: const ValueKey('doctor'),
      controller: c,
      who: SourceKind.doctor,
      dictation: _dictation,
      audio: _audio,
      player: _player,
    ),
    WizardStep.doctorTakeaways => DoctorVerifyStep(
      controller: c,
      dictation: _dictation,
    ),
    WizardStep.photos => PhotosStep(
      controller: c,
      photos: _photos,
      scanner: _scanner,
    ),
    WizardStep.pharmacyWords => WordsStep(
      key: const ValueKey('chemist'),
      controller: c,
      who: SourceKind.chemist,
      dictation: _dictation,
      audio: _audio,
      player: _player,
    ),
    WizardStep.chemistTakeaways => TakeawaysStep(
      controller: c,
      who: SourceKind.chemist,
    ),
    WizardStep.processing => ProcessingStep(
      controller: c,
      online: widget.onlineCard?.call(c),
    ),
    WizardStep.medicines => MedicinesStep(controller: c),
    WizardStep.placement => PlacementStep(controller: c),
  };

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final last = c.step == WizardStep.placement;

    return PopScope(
      canPop: !c.canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.back();
      },
      child: VoicePrompt(
        key: ValueKey(c.step),
        text: _title(s),
        child: Scaffold(
          appBar: AppBar(
            title: Text(_title(s)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(34),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Progress(
                      at: c.stepNumber,
                      of: VisitWizardController.stepCount,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.stepOf(c.stepNumber, VisitWizardController.stepCount),
                      style: text.labelMedium?.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // Nothing is blocked: the session is saved, and syncs later.
              if (c.offline) _OfflineBanner(text: s.offlineSaved),
              Expanded(child: _body()),
            ],
          ),
          bottomNavigationBar: _BottomBar(
            wide: last,
            left: c.canSkip
                ? TextButton(onPressed: c.skip, child: Text(s.skip))
                : c.canGoBack
                ? TextButton(onPressed: c.back, child: Text(s.back))
                : null,
            right: Pressable(
              enabled: c.canGoNext && !_approving,
              child: FilledButton(
                onPressed: !c.canGoNext || _approving
                    ? null
                    : last
                    ? Haptics.on(_approve, HapticKind.confirm)
                    : Haptics.on(c.next),
                child: _approving
                    ? const SizedBox.square(
                        dimension: 26,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Text(last ? s.approve : s.next),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.at, required this.of});

  final int at;
  final int of;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= of; i++) ...[
        if (i > 1) const SizedBox(width: 5),
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: i <= at ? AppColors.amber : AppColors.hairline,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ],
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.right, this.left, this.wide = false});

  final Widget? left;
  final Widget right;

  /// Give the main button more room — "Approve and add" is three words.
  final bool wide;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.paper,
      border: Border(top: BorderSide(color: AppColors.hairline)),
    ),
    padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            flex: wide ? 2 : 1,
            // heightFactor 1: a bottom bar gets the whole screen's height as a
            // loose limit, and a plain Align would take all of it.
            child: Align(
              alignment: Alignment.centerLeft,
              heightFactor: 1,
              child: left,
            ),
          ),
          Expanded(flex: wide ? 3 : 1, child: right),
        ],
      ),
    ),
  );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
    color: AppColors.amberSoft,
    child: Row(
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.amberDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
