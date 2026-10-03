import 'name_matcher.dart';
import 'scheduled_medicine.dart';
import 'sig.dart';

/// One medicine on one approved visit.
class RxSighting {
  const RxSighting({
    required this.visitId,
    required this.seenAt,
    required this.name,
    this.strength,
    this.sig,
    this.doctor,
  });

  final String visitId;
  final DateTime seenAt;
  final String name;

  /// As recorded, or read from the name (`TELMA 40`) on older records.
  final String? strength;
  final Sig? sig;
  final String? doctor;
}

/// Everything the history knows about one medicine: every visit it was on.
class RxPrior {
  RxPrior._(this.sightings, this.now);

  /// Oldest first; never empty.
  final List<RxSighting> sightings;

  /// The history's clock when this was asked.
  final DateTime now;

  /// The most recent spelling.
  String get name => sightings.last.name;

  /// How many approved visits had it.
  int get visits => {for (final s in sightings) s.visitId}.length;

  DateTime get firstSeen => sightings.first.seenAt;
  DateTime get lastSeen => sightings.last.seenAt;
  int get daysSinceLast => dayOf(now).difference(dayOf(lastSeen)).inDays;

  /// The strength on the most recent visit that gave one.
  String? get lastStrength =>
      sightings.reversed.map((s) => s.strength).nonNulls.firstOrNull;

  Sig? get lastSig => sightings.reversed.map((s) => s.sig).nonNulls.firstOrNull;
  String? get lastDoctor =>
      sightings.reversed.map((s) => s.doctor).nonNulls.firstOrNull;

  /// Taken for the long term, as far as the record shows: prescribed on two
  /// visits at least [RxHistory.chronicSpanDays] apart, or once for a course
  /// of [RxHistory.chronicCourseDays] days or more. Nothing else counts —
  /// a missing duration is unknown, not "for ever".
  bool get chronic {
    final span = dayOf(lastSeen).difference(dayOf(firstSeen)).inDays;
    if (visits >= 2 && span >= RxHistory.chronicSpanDays) return true;
    return sightings.any(
      (s) => (s.sig?.durationDays ?? 0) >= RxHistory.chronicCourseDays,
    );
  }

  @override
  String toString() =>
      'RxPrior($name ×$visits, last ${lastSeen.toIso8601String()})';
}

/// The patient's past prescriptions, as approved on this phone.
///
/// The merge reads the visit in front of it; this remembers the ones before.
/// It answers three questions, and only ever as a reason for a person to
/// look — never as a correction:
///
/// * has this medicine been prescribed before, how often, how recently
///   ([priorFor]) — a first-time brand that looks like a familiar one is
///   worth a second look;
/// * at what strength last time ([lastStrength]) — TELMA 40 for a year and
///   TELMA 80 today may be a deliberate step up, or a misread;
/// * which long-term medicines are missing from today's visit
///   ([missingSince]) — a doctor stopping one is a decision the patient
///   should hear about, not discover.
///
/// Medicines are told apart by [NameMatcher], the same rule the merge uses:
/// the brand letters with OCR slack, variants strict, strength ignored.
class RxHistory {
  RxHistory(
    Iterable<RxSighting> sightings, {
    this.active,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    final sorted = [...sightings]..sort((a, b) => a.seenAt.compareTo(b.seenAt));
    for (final s in sorted) {
      final track = _tracks.where((t) => NameMatcher.same(t.last.name, s.name));
      if (track.isEmpty) {
        _tracks.add([s]);
      } else {
        track.first.add(s);
      }
    }
  }

  /// From [MedicineStore.records] — newest first or not, it does not matter.
  /// Records from before details were kept give names only; the strength is
  /// then read from the name, as printed.
  factory RxHistory.fromRecords(
    Iterable<PrescriptionRecord> records, {
    Iterable<ScheduledMedicine>? active,
    DateTime Function()? clock,
  }) => RxHistory(
    [
      for (final r in records)
        if (r.medicines.isNotEmpty)
          for (final m in r.medicines)
            RxSighting(
              visitId: r.id,
              seenAt: r.addedAt,
              name: m.name,
              strength: m.strength ?? NameMatcher.parse(m.name).strength,
              sig: m.sig,
              doctor: r.doctor,
            )
        else
          for (final n in r.medicineNames)
            RxSighting(
              visitId: r.id,
              seenAt: r.addedAt,
              name: n,
              strength: NameMatcher.parse(n).strength,
              doctor: r.doctor,
            ),
    ],
    active: active?.toList(),
    clock: clock,
  );

  static final empty = RxHistory(const []);

  /// Two visits this many days apart make a medicine long-term.
  static const chronicSpanDays = 14;

  /// A single course this long makes it long-term too.
  static const chronicCourseDays = 28;

  /// What is on the schedule now. Null when unknown: then nothing is
  /// filtered out for having been stopped.
  final List<ScheduledMedicine>? active;

  final DateTime Function() _clock;
  final _tracks = <List<RxSighting>>[];

  bool get isEmpty => _tracks.isEmpty;

  /// Every medicine ever approved, each once.
  List<RxPrior> get all => [
    for (final t in _tracks) RxPrior._(List.unmodifiable(t), _clock()),
  ];

  /// The most recent approved visit.
  DateTime? get lastVisit {
    DateTime? last;
    for (final t in _tracks) {
      if (last == null || t.last.seenAt.isAfter(last)) last = t.last.seenAt;
    }
    return last;
  }

  /// [name]'s past, or null when it was never prescribed here.
  RxPrior? priorFor(String name) {
    for (final t in _tracks) {
      if (t.any((s) => NameMatcher.same(s.name, name))) {
        return RxPrior._(List.unmodifiable(t), _clock());
      }
    }
    return null;
  }

  /// The strength [brand] was last prescribed at, or null.
  String? lastStrength(String brand) => priorFor(brand)?.lastStrength;

  /// Whether [name] was prescribed before at a strength that is not the one
  /// it carries now. False when either side has no strength.
  bool strengthChanged(String name, String? strength) {
    final now = strength ?? NameMatcher.parse(name).strength;
    final before = lastStrength(name);
    if (now == null || before == null) return false;
    return _number(now) != _number(before);
  }

  /// Long-term medicines on the visit of [lastVisit] that [current] does not
  /// name — and that are still on the schedule, when that is known.
  List<RxPrior> missingSince(
    DateTime lastVisit, {
    required Iterable<String> current,
  }) {
    final day = dayOf(lastVisit);
    final now = current.toList();
    return [
      for (final p in all)
        if (p.chronic &&
            p.sightings.any((s) => dayOf(s.seenAt) == day) &&
            !now.any((n) => NameMatcher.same(n, p.name)) &&
            (active == null ||
                active!.any((m) => NameMatcher.same(m.name, p.name))))
          p,
    ];
  }

  /// [missingSince] the most recent visit.
  List<RxPrior> missingNow(Iterable<String> current) {
    final last = lastVisit;
    return last == null ? const [] : missingSince(last, current: current);
  }

  static double? _number(String s) =>
      double.tryParse(RegExp(r'\d+(?:\.\d+)?').firstMatch(s)?[0] ?? '');
}
