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

/// One medicine as it was approved on one visit: what the history of past
/// prescriptions remembers. A snapshot, never edited afterwards — the
/// schedule may change, the record of what was prescribed does not.
class RecordedMedicine {
  const RecordedMedicine({required this.name, this.strength, this.sig});

  final String name;
  final String? strength;

  /// Null on records written before instructions were kept.
  final Sig? sig;

  factory RecordedMedicine.of(ScheduledMedicine m) =>
      RecordedMedicine(name: m.name, strength: m.strength, sig: m.sig);

  Map<String, Object?> toJson() => {
    'name': name,
    if (strength != null) 'strength': strength,
    if (sig != null) 'sig': sig!.toJson(),
  };

  factory RecordedMedicine.fromJson(Map<String, Object?> j) =>
      RecordedMedicine(
        name: j['name']! as String,
        strength: j['strength'] as String?,
        sig: j['sig'] == null
            ? null
            : Sig.fromJson((j['sig']! as Map).cast<String, Object?>()),
      );
}

/// One approved visit, as the "My prescriptions" list shows it.
class PrescriptionRecord {
  const PrescriptionRecord({
    required this.id,
    required this.addedAt,
    required this.medicineNames,
    this.medicines = const [],
    this.doctor,
    this.evidence = const [],
    this.caretakerNote,
    this.notePriority = 'low',
    this.onlineReading,
  });

  final String id;
  final DateTime addedAt;
  final List<String> medicineNames;

  /// Name, strength and instruction of each approved medicine. Empty on
  /// records from before this was kept; [medicineNames] still has the names.
  final List<RecordedMedicine> medicines;

  /// The doctor's name, when the visit recorded one.
  final String? doctor;

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
    medicines: medicines,
    doctor: doctor,
    evidence: evidence,
    caretakerNote: caretakerNote,
    notePriority: notePriority,
    onlineReading: json,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'addedAt': addedAt.toIso8601String(),
    'medicineNames': medicineNames,
    if (medicines.isNotEmpty)
      'medicines': [for (final m in medicines) m.toJson()],
    if (doctor != null) 'doctor': doctor,
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
    medicines: [
      for (final m in j['medicines'] as List? ?? const [])
        RecordedMedicine.fromJson((m as Map).cast<String, Object?>()),
    ],
    doctor: j['doctor'] as String?,
    evidence: [for (final e in j['evidence'] as List? ?? const []) e as String],
    caretakerNote: j['caretakerNote'] as String?,
    notePriority: j['notePriority'] as String? ?? 'low',
    onlineReading: j['onlineReading'] as String?,
  );
}

/// Midnight of [d]. Every comparison of days goes through here.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
