import '../../domain/pharmacy_check.dart';

/// Who checked what the phone understood from the doctor's words.
enum Verifier { doctor, me }

enum NotePriority { low, medium, high }

/// What a photo turned out to be.
enum PhotoLabel { prescription, bill, strip, medicalOther, notMedical }

/// The four things a visit can carry. Only the prescription is required.
enum CaptureKind { prescriptionPhoto, doctorVoice, bill, chemistVoice }

/// One photo in a visit, with the text read from it on the device.
class VisitPhoto {
  VisitPhoto({
    required this.path,
    required this.label,
    this.ocrText,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  final String path;
  PhotoLabel label;

  /// Read once, while labelling, and reused by extraction. Never read twice.
  String? ocrText;
  final DateTime addedAt;

  Map<String, Object?> toJson() => {
    'path': path,
    'label': label.name,
    if (ocrText != null) 'ocrText': ocrText,
    'addedAt': addedAt.toIso8601String(),
  };

  factory VisitPhoto.fromJson(Map<String, Object?> j) => VisitPhoto(
    path: j['path']! as String,
    label: PhotoLabel.values.byName(j['label']! as String),
    ocrText: j['ocrText'] as String?,
    addedAt: DateTime.parse(j['addedAt']! as String),
  );
}

/// One trip to the doctor and the chemist.
///
/// Saved after every single capture (ADR-20), so an app killed mid-visit —
/// a phone call, a flat battery — loses nothing. Photos and audio are files;
/// only their paths live here.
class Visit {
  Visit({
    required this.id,
    DateTime? createdAt,
    this.doctorName,
    this.consent = false,
    this.doctorWords = '',
    this.chemistWords = '',
    this.doctorAudioPath,
    this.chemistAudioPath,
    List<VisitPhoto>? photos,
    this.verifiedBy,
    this.caretakerNote = '',
    this.notePriority = NotePriority.low,
    List<String>? notProvided,
    List<PharmacyResolution>? pharmacyResolutions,
  }) : createdAt = createdAt ?? DateTime.now(),
       photos = photos ?? [],
       notProvided = notProvided ?? [],
       pharmacyResolutions = pharmacyResolutions ?? [];

  factory Visit.start() =>
      Visit(id: 'v${DateTime.now().millisecondsSinceEpoch}');

  final String id;
  final DateTime createdAt;
  String? doctorName;

  /// Consent is a gate, not a checkbox (ADR-21): nothing is captured before it.
  bool consent;

  /// What the doctor said, as text — dictated or written.
  String doctorWords;

  /// What the chemist said, as text.
  String chemistWords;

  String? doctorAudioPath;
  String? chemistAudioPath;
  final List<VisitPhoto> photos;

  Iterable<VisitPhoto> photosOf(PhotoLabel label) =>
      photos.where((p) => p.label == label);

  bool get hasPrescription => photosOf(PhotoLabel.prescription).isNotEmpty;
  bool get hasBill => photosOf(PhotoLabel.bill).isNotEmpty;

  bool has(CaptureKind kind) => switch (kind) {
    CaptureKind.prescriptionPhoto => hasPrescription,
    CaptureKind.bill => hasBill,
    CaptureKind.doctorVoice =>
      doctorAudioPath != null || doctorWords.trim().isNotEmpty,
    CaptureKind.chemistVoice =>
      chemistAudioPath != null || chemistWords.trim().isNotEmpty,
  };

  /// Who ran the doctor verification.
  Verifier? verifiedBy;

  /// A note for the caretaker, and how much it matters.
  String caretakerNote;
  NotePriority notePriority;

  /// Steps a person skipped. Recorded as "not provided" — never blank,
  /// never guessed.
  final List<String> notProvided;

  /// Every answer to a pharmacy question, oldest first — the latest one for
  /// a question is the one that counts. Kept whole: "not sure" and an
  /// explanation are part of the record, even though they settle nothing.
  final List<PharmacyResolution> pharmacyResolutions;

  Map<String, Object?> toJson() => {
    'id': id,
    if (verifiedBy != null) 'verifiedBy': verifiedBy!.name,
    if (caretakerNote.isNotEmpty) 'caretakerNote': caretakerNote,
    'notePriority': notePriority.name,
    if (notProvided.isNotEmpty) 'notProvided': notProvided,
    if (pharmacyResolutions.isNotEmpty)
      'pharmacyResolutions': [for (final r in pharmacyResolutions) r.toJson()],
    'createdAt': createdAt.toIso8601String(),
    if (doctorName != null) 'doctorName': doctorName,
    'consent': consent,
    'doctorWords': doctorWords,
    'chemistWords': chemistWords,
    if (doctorAudioPath != null) 'doctorAudioPath': doctorAudioPath,
    if (chemistAudioPath != null) 'chemistAudioPath': chemistAudioPath,
    'photos': [for (final p in photos) p.toJson()],
  };

  factory Visit.fromJson(Map<String, Object?> j) => Visit(
    verifiedBy: switch (j['verifiedBy']) {
      final String v => Verifier.values.byName(v),
      _ => null,
    },
    caretakerNote: j['caretakerNote'] as String? ?? '',
    notePriority: NotePriority.values.byName(
      j['notePriority'] as String? ?? 'low',
    ),
    notProvided: [
      for (final n in j['notProvided'] as List? ?? const []) n as String,
    ],
    pharmacyResolutions: [
      for (final r in j['pharmacyResolutions'] as List? ?? const [])
        PharmacyResolution.fromJson((r as Map).cast<String, Object?>()),
    ],
    id: j['id']! as String,
    createdAt: DateTime.parse(j['createdAt']! as String),
    doctorName: j['doctorName'] as String?,
    consent: j['consent'] as bool? ?? false,
    doctorWords: j['doctorWords'] as String? ?? '',
    chemistWords: j['chemistWords'] as String? ?? '',
    doctorAudioPath: j['doctorAudioPath'] as String?,
    chemistAudioPath: j['chemistAudioPath'] as String?,
    photos: [
      for (final p in (j['photos'] as List? ?? const []))
        VisitPhoto.fromJson((p as Map).cast<String, Object?>()),
    ],
  );
}
