import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../platform/gallery_scanner.dart';
import '../../../platform/photo_thumb.dart';
import '../../visit/capture_tools.dart';
import '../../visit/visit.dart';
import '../wizard_controller.dart';
import '../wizard_models.dart';
import '../wizard_widgets.dart';

/// Step 3: the prescription, the bill and the strips, together.
///
/// Three ways in, one list out. Each photo is read on the phone and labelled,
/// with the words that decided the label shown underneath; a person checks the
/// labels. A photo that does not look medical arrives unticked with its reason
/// — never hidden — and can be used anyway.
class PhotosStep extends StatefulWidget {
  const PhotosStep({
    super.key,
    required this.controller,
    required this.photos,
    required this.scanner,
  });

  final VisitWizardController controller;
  final PhotoCapture photos;
  final GalleryScanner scanner;

  @override
  State<PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends State<PhotosStep> {
  bool _scanning = false;
  String? _scanNote;

  VisitWizardController get c => widget.controller;

  Future<void> _scan() async {
    final s = L10n.of(context);
    setState(() {
      _scanning = true;
      _scanNote = null;
    });
    final outcome = await widget.scanner.recent();
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _scanNote = switch (outcome.status) {
        ScanStatus.unsupported => s.scanUnsupported,
        ScanStatus.denied => s.scanDenied,
        ScanStatus.nothing => s.scanNothing,
        ScanStatus.found => null,
      };
    });
    if (outcome.status == ScanStatus.found) {
      final known = c.candidates.map((x) => x.path).toSet();
      await c.addPhotos([
        for (final p in outcome.paths)
          if (!known.contains(p)) XFile(p),
      ]);
    }
  }

  Future<void> _pick({required bool camera}) async {
    final files = camera
        ? [?(await widget.photos.camera())]
        : await widget.photos.galleryMany();
    if (files.isEmpty) return;
    await c.addPhotos(files);
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        StepIntro(s.photosWhy),
        FilledButton.icon(
          icon: _scanning
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome, size: 28),
          label: Text(s.findRecent),
          onPressed: _scanning ? null : _scan,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(s.camera),
                onPressed: () => _pick(camera: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(s.gallery),
                onPressed: () => _pick(camera: false),
              ),
            ),
          ],
        ),
        if (_scanNote != null) ...[
          const SizedBox(height: 12),
          InfoCard(text: _scanNote!, icon: Icons.info_outline),
        ],
        if (c.candidates.isNotEmpty) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Text(s.areTheseRight, style: text.titleLarge)),
              Text(
                s.nSelected(c.selectedCount),
                style: text.labelMedium?.copyWith(fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final cand in c.candidates) ...[
            _CandidateCard(
              candidate: cand,
              onLabel: (l) => c.setLabel(cand, l),
              onToggle: () => c.toggleSelected(cand),
            ),
            const SizedBox(height: 14),
          ],
        ],
        if (!c.photosReady && c.candidates.isNotEmpty)
          Text(
            s.needPrescription,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.onLabel,
    required this.onToggle,
  });

  final PhotoCandidate candidate;
  final ValueChanged<PhotoLabel> onLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final turnedAway = candidate.reason != null && !candidate.selected;
    final fill = candidate.selected ? AppColors.greenSoft : AppColors.surface;
    final border = candidate.selected
        ? AppColors.green
        : turnedAway
        ? AppColors.warn
        : AppColors.hairline;

    return ToneCard(
      fill: fill,
      border: border,
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          photoThumb(candidate.path, size: 80),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final (label, word) in _labels(s))
                      Pill(
                        word,
                        tone: candidate.label == label && !turnedAway
                            ? PillTone.strong
                            : PillTone.neutral,
                        onTap: () => onLabel(label),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _detail(context, s, turnedAway),
              ],
            ),
          ),
          Checkbox(
            value: candidate.selected,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.green,
          ),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, AppStrings s, bool turnedAway) {
    const small = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
      height: 1.25,
    );
    if (candidate.reading) {
      return Text(s.reading, style: small);
    }
    if (candidate.unreadable) {
      return Text(s.couldNotRead, style: small);
    }
    if (turnedAway) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.notMedicalReason,
            style: small.copyWith(color: AppColors.warn),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.warn,
            ),
            onPressed: onToggle,
            child: Text(s.useAnyway),
          ),
        ],
      );
    }
    if (candidate.evidence.isEmpty) return const SizedBox.shrink();
    return Text(candidate.evidence.join(' · '), style: small);
  }

  static List<(PhotoLabel, String)> _labels(AppStrings s) => [
    (PhotoLabel.prescription, s.labelPrescription),
    (PhotoLabel.bill, s.labelBill),
    (PhotoLabel.strip, s.labelStrip),
  ];
}
