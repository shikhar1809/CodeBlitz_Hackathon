import 'sig.dart';

/// A medicine a person approved, now on the daily schedule.
class ScheduledMedicine {
  const ScheduledMedicine({
    required this.id,
    required this.name,
    required this.sig,
    required this.startDate,
    this.strength,
    this.active = true,
    this.purpose,
    this.imagePath,
  });

  final String id;

  /// English letters, exactly as printed.
  final String name;
  final String? strength;
  final Sig sig;

  /// Midnight of the day it starts.
  final DateTime startDate;
  final bool active;

  /// Quoted from the doctor, never inferred.
  final String? purpose;

  /// A photo of this medicine's strip, when one was kept. Nothing stores one
  /// yet; the alarm screen shows it when present and a form pictogram when
  /// not.
  final String? imagePath;

  ScheduledMedicine copyWith({Sig? sig, bool? active, DateTime? startDate}) =>
      ScheduledMedicine(
        id: id,
        name: name,
        strength: strength,
        sig: sig ?? this.sig,
        startDate: startDate ?? this.startDate,
        active: active ?? this.active,
        purpose: purpose,
        imagePath: imagePath,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (strength != null) 'strength': strength,
    'sig': sig.toJson(),
    'startDate': startDate.toIso8601String(),
    'active': active,
    if (purpose != null) 'purpose': purpose,
    if (imagePath != null) 'imagePath': imagePath,
  };

  factory ScheduledMedicine.fromJson(Map<String, Object?> j) =>
      ScheduledMedicine(
        id: j['id']! as String,
        name: j['name']! as String,
        strength: j['strength'] as String?,
        sig: Sig.fromJson((j['sig']! as Map).cast<String, Object?>()),
        startDate: DateTime.parse(j['startDate']! as String),
        active: j['active'] as bool? ?? true,
        purpose: j['purpose'] as String?,
        imagePath: j['imagePath'] as String?,
      );
}

/// One approved visit, as the "My prescriptions" list shows it.
class PrescriptionRecord {
  const PrescriptionRecord({
    required this.id,
    required this.addedAt,
    required this.medicineNames,
    this.evidence = const [],
    this.caretakerNote,
    this.notePriority = 'low',
    this.onlineReading,
  });

  final String id;
  final DateTime addedAt;
  final List<String> medicineNames;

  /// What the visit was built from: doctor, prescription, bill, chemist.
  final List<String> evidence;

  /// The note for the caretaker, and its priority: low, medium or high.
  final String? caretakerNote;
  final String notePriority;

  /// A handwriting reading that finished after approval, as JSON. Kept for a
  /// person to review; it never changes the schedule on its own.
  final String? onlineReading;

  PrescriptionRecord withOnlineReading(String json) => PrescriptionRecord(
    id: id,
    addedAt: addedAt,
    medicineNames: medicineNames,
    evidence: evidence,
    caretakerNote: caretakerNote,
    notePriority: notePriority,
    onlineReading: json,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'addedAt': addedAt.toIso8601String(),
    'medicineNames': medicineNames,
    if (evidence.isNotEmpty) 'evidence': evidence,
    if (caretakerNote != null && caretakerNote!.isNotEmpty) ...{
      'caretakerNote': caretakerNote,
      'notePriority': notePriority,
    },
    if (onlineReading != null) 'onlineReading': onlineReading,
  };

  factory PrescriptionRecord.fromJson(
    Map<String, Object?> j,
  ) => PrescriptionRecord(
    id: j['id']! as String,
    addedAt: DateTime.parse(j['addedAt']! as String),
    medicineNames: [for (final n in j['medicineNames']! as List) n as String],
    evidence: [for (final e in j['evidence'] as List? ?? const []) e as String],
    caretakerNote: j['caretakerNote'] as String?,
    notePriority: j['notePriority'] as String? ?? 'low',
    onlineReading: j['onlineReading'] as String?,
  );
}

/// Midnight of [d]. Every comparison of days goes through here.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
