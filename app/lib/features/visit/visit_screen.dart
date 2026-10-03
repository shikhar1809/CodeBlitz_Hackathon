import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import 'capture_tools.dart';
import 'consent_sheet.dart';
import 'media_store.dart';
import 'visit.dart';
import 'visit_repository.dart';

/// The four captures of a visit, on one screen.
///
/// Local-first and consent-gated: the first tap asks for consent; every
/// capture is saved to the draft the moment it lands; the prescription photo
/// is the only thing required.
class VisitScreen extends StatefulWidget {
  const VisitScreen({
    super.key,
    required this.repository,
    this.media,
    this.photos,
    this.audio,
    this.consent = askConsent,
    this.onBuildPlan,
  });

  final VisitRepository repository;
  final MediaStore? media;
  final PhotoCapture? photos;
  final AudioCapture? audio;
  final Future<bool> Function(BuildContext) consent;
  final ValueChanged<Visit>? onBuildPlan;

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  late final Visit _visit = widget.repository.loadDraft() ?? Visit.start();
  late final MediaStore _media = widget.media ?? MediaStore();
  late final PhotoCapture _photos = widget.photos ?? PhotoCapture();
  late final AudioCapture _audio = widget.audio ?? AudioCapture();
  late final _doctor = TextEditingController(text: _visit.doctorName);

  @override
  void dispose() {
    _doctor.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _save() => widget.repository.save(_visit);

  Future<bool> _ensureConsent() async {
    if (_visit.consent) return true;
    final ok = await widget.consent(context);
    if (!ok) return false;
    _visit.consent = true;
    await _save();
    return true;
  }

  Future<void> _addPhoto(PhotoLabel label) async {
    if (!await _ensureConsent() || !mounted) return;
    final s = L10n.of(context);
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.paper,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: AppTheme.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(s.takePhoto),
                onPressed: () => Navigator.pop(sheet, 'camera'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(s.chooseFromGallery),
                onPressed: () => Navigator.pop(sheet, 'gallery'),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final file = source == 'camera'
        ? await _photos.camera()
        : await _photos.gallery();
    if (file == null) {
      _say(s.cameraUnavailable);
      return;
    }
    await _keepPhoto(file, label);
  }

  Future<void> _keepPhoto(XFile file, PhotoLabel label) async {
    final n = _visit.photos.length + 1;
    final path = await _media.keep(_visit.id, file, name: '${label.name}_$n');
    setState(() => _visit.photos.add(VisitPhoto(path: path, label: label)));
    await _save();
  }

  Future<void> _recordVoice(CaptureKind kind) async {
    if (!await _ensureConsent() || !mounted) return;
    final s = L10n.of(context);
    if (!await _audio.start()) {
      _say(s.micUnavailable);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.paper,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: AppTheme.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mic_rounded, size: 56, color: AppColors.red),
              const SizedBox(height: 8),
              Text(
                s.recording,
                textAlign: TextAlign.center,
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.stop_rounded),
                label: Text(s.stopRecording),
                onPressed: () => Navigator.pop(sheet),
              ),
            ],
          ),
        ),
      ),
    );
    final file = await _audio.stop();
    if (file == null) return;
    final name = kind == CaptureKind.doctorVoice ? 'doctor' : 'chemist';
    final path = await _media.keep(_visit.id, file, name: name);
    setState(() {
      if (kind == CaptureKind.doctorVoice) {
        _visit.doctorAudioPath = path;
      } else {
        _visit.chemistAudioPath = path;
      }
    });
    await _save();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final prescriptions = _visit.photosOf(PhotoLabel.prescription).length;

    return VoicePrompt(
      text: '${s.newVisit}. ${s.visitIntro}',
      child: Scaffold(
        appBar: AppBar(title: Text(s.newVisit)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(s.visitIntro, style: text.bodySmall?.copyWith(fontSize: 20)),
            const SizedBox(height: 16),
            TextField(
              controller: _doctor,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(hintText: s.doctorNameHint),
              onChanged: (v) {
                _visit.doctorName = v.trim().isEmpty ? null : v.trim();
                _save();
              },
            ),
            const SizedBox(height: 14),
            CaptureTile(
              icon: Icons.photo_camera_outlined,
              title: prescriptions > 0
                  ? s.prescriptionPhoto
                  : s.photoN(prescriptions + 1),
              subtitle: s.prescriptionPhotoWhy,
              tag: s.required,
              tagStrong: true,
              done: prescriptions > 0,
              doneLabel: prescriptions > 1
                  ? '${s.added} ×$prescriptions'
                  : s.added,
              onTap: () => _addPhoto(PhotoLabel.prescription),
            ),
            const SizedBox(height: 14),
            CaptureTile(
              icon: Icons.mic_none_rounded,
              title: s.doctorVoice,
              subtitle: s.doctorVoiceWhy,
              tag: s.optional,
              done: _visit.has(CaptureKind.doctorVoice),
              doneLabel: s.added,
              onTap: () => _recordVoice(CaptureKind.doctorVoice),
            ),
            const SizedBox(height: 14),
            CaptureTile(
              icon: Icons.receipt_long_outlined,
              title: s.pharmacyBill,
              subtitle: s.pharmacyBillWhy,
              tag: s.recommended,
              done: _visit.hasBill,
              doneLabel: s.added,
              onTap: () => _addPhoto(PhotoLabel.bill),
            ),
            const SizedBox(height: 14),
            CaptureTile(
              icon: Icons.record_voice_over_outlined,
              title: s.chemistVoice,
              subtitle: s.chemistVoiceWhy,
              tag: s.optional,
              done: _visit.has(CaptureKind.chemistVoice),
              doneLabel: s.added,
              onTap: () => _recordVoice(CaptureKind.chemistVoice),
            ),
            if (!_media.persistent) ...[
              const SizedBox(height: 16),
              WarnNote(text: s.browserPreview),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(s.buildPlan),
              onPressed: _visit.hasPrescription && widget.onBuildPlan != null
                  ? () => widget.onBuildPlan!(_visit)
                  : null,
            ),
            if (!_visit.hasPrescription) ...[
              const SizedBox(height: 10),
              Text(
                s.addPrescriptionFirst,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A capture row: icon, title with a tag, one line of why.
class CaptureTile extends StatelessWidget {
  const CaptureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    this.tagStrong = false,
    this.done = false,
    this.doneLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final bool tagStrong;
  final bool done;
  final String? doneLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: done ? AppColors.greenSoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(
          color: done ? AppColors.green : AppColors.hairline,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle_rounded : icon,
                  size: 36,
                  color: done ? AppColors.green : AppColors.muted,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Tag(
                            text: done ? (doneLabel ?? tag) : tag,
                            strong: tagStrong && !done,
                            green: done,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.text,
    this.strong = false,
    this.green = false,
  });

  final String text;
  final bool strong;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final fill = green
        ? AppColors.green
        : strong
        ? AppColors.amber
        : AppColors.amberSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: green ? AppColors.green : AppColors.amberBorder,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: green ? Colors.white : AppColors.ink,
        ),
      ),
    );
  }
}

/// An orange-bordered caution: something the user should know before relying
/// on this screen.
class WarnNote extends StatelessWidget {
  const WarnNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.warn),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warn,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.warn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
