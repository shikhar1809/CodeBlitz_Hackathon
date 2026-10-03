import 'mention.dart';
import 'name_matcher.dart';
import 'sig.dart';

/// All agree / needs a look / the sources disagree.
enum Verdict { green, amber, red }

/// Why a row is amber rather than green.
enum AmberReason {
  /// Only one source mentions it.
  singleSource,

  /// Nobody said when to take it.
  noTiming,

  /// The parser met words it could not place.
  unresolved,

  /// A reader flagged its own reading as unsure.
  uncertain,

  /// One source listed it twice. Kept apart, because merging would hide it.
  sameSourceTwice,
}

enum ConflictField {
  strength,
  timing,
  food,
  interval,
  asNeeded,

  /// Sold at the counter, but no doctor and no prescription mentions it.
  notPrescribed,
}

/// Two or more sources that disagree about one thing. Every side is kept.
class Conflict {
  const Conflict(this.field, this.sides);

  final ConflictField field;
  final List<Mention> sides;
}

/// One medicine, with every piece of evidence behind it.
class MergedMedicine {
  const MergedMedicine({
    required this.id,
    required this.name,
    required this.sig,
    required this.evidence,
    required this.verdict,
    this.strength,
    this.conflicts = const [],
    this.reasons = const {},
    this.purpose,
  });

  final String id;
  final String name;
  final String? strength;

  /// What the evidence proposes. On a red row a person picks between sides.
  final Sig sig;
  final List<Mention> evidence;
  final Verdict verdict;
  final List<Conflict> conflicts;
  final Set<AmberReason> reasons;

  /// Only ever the doctor's own words.
  final String? purpose;

  Set<SourceKind> get sources => {for (final m in evidence) m.source};

  static String idFor(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

/// Cross-checks the sources. Plain Dart: deterministic, inspectable, identical
/// every run. This decides what reaches a patient's schedule, so no model sits
/// between the evidence and the plan — and where sources disagree, both are
/// kept and a person decides.
abstract final class MergeEngine {
  /// Who decides *what* the medicine is. A printed bill reads at over 99%.
  static const identityOrder = [
    SourceKind.bill,
    SourceKind.strip,
    SourceKind.doctor,
    SourceKind.prescription,
    SourceKind.chemist,
  ];

  /// Who decides *when* to take it. The bill carries no timing at all.
  static const timingOrder = [
    SourceKind.doctor,
    SourceKind.prescription,
    SourceKind.chemist,
    SourceKind.strip,
    SourceKind.bill,
  ];

  static List<MergedMedicine> merge(Iterable<Mention> mentions) {
    final clusters = <List<Mention>>[];
    final twice = <int>{};

    for (final m in mentions) {
      var placed = false;
      var sameSourceMatch = -1;
      for (var i = 0; i < clusters.length; i++) {
        final c = clusters[i];
        if (!c.any((x) => NameMatcher.same(x.name, m.name))) continue;
        if (c.any((x) => x.source == m.source)) {
          // A bill can list a brand twice. Merging would hide the duplicate.
          sameSourceMatch = i;
          continue;
        }
        c.add(m);
        placed = true;
        break;
      }
      if (!placed) {
        clusters.add([m]);
        if (sameSourceMatch >= 0) {
          twice
            ..add(sameSourceMatch)
            ..add(clusters.length - 1);
        }
      }
    }

    final used = <String>{};
    return [
      for (var i = 0; i < clusters.length; i++)
        _judge(clusters[i], twice.contains(i), used),
    ];
  }

  static MergedMedicine _judge(
    List<Mention> group,
    bool sameSourceTwice,
    Set<String> usedIds,
  ) {
    int rank(List<SourceKind> order, Mention m) => order.indexOf(m.source);

    // Identity: the most trusted source that gave a strength, else the most
    // trusted source.
    final byIdentity = [...group]
      ..sort((a, b) => rank(identityOrder, a) - rank(identityOrder, b));
    final named = byIdentity.firstWhere(
      (m) => m.strength != null,
      orElse: () => byIdentity.first,
    );

    // Timing: the most trusted source that said when, gaps filled from the
    // rest in order.
    final byTiming = [...group]
      ..sort((a, b) => rank(timingOrder, a) - rank(timingOrder, b));
    final timed = byTiming.where((m) => m.sig.hasTiming).toList();
    final ordered = [...timed, ...byTiming.where((m) => !m.sig.hasTiming)];
    Sig clean(Mention m) => m.sig.copyWith(unresolved: const []);
    var sig = clean(ordered.first);
    for (final m in ordered.skip(1)) {
      sig = sig.fillFrom(clean(m));
    }
    final unresolved = [for (final m in group) ...m.sig.unresolved];
    sig = sig.copyWith(unresolved: unresolved);

    final conflicts = _conflicts(group, timed);

    final reasons = <AmberReason>{
      if ({for (final m in group) m.source}.length < 2)
        AmberReason.singleSource,
      if (!sig.hasTiming) AmberReason.noTiming,
      if (unresolved.isNotEmpty) AmberReason.unresolved,
      if (group.any((m) => m.uncertain)) AmberReason.uncertain,
      if (sameSourceTwice) AmberReason.sameSourceTwice,
    };

    final verdict = conflicts.isNotEmpty
        ? Verdict.red
        : reasons.isNotEmpty
        ? Verdict.amber
        : Verdict.green;

    final doctorPurpose = group
        .where((m) => m.source == SourceKind.doctor && m.purpose != null)
        .map((m) => m.purpose)
        .firstOrNull;

    var id = MergedMedicine.idFor(named.name);
    for (var n = 2; usedIds.contains(id); n++) {
      id = '${MergedMedicine.idFor(named.name)}-$n';
    }
    usedIds.add(id);

    return MergedMedicine(
      id: id,
      name: named.name,
      strength: named.strength,
      sig: sig,
      evidence: byIdentity,
      verdict: verdict,
      conflicts: conflicts,
      reasons: reasons,
      purpose: doctorPurpose,
    );
  }

  static List<Conflict> _conflicts(List<Mention> group, List<Mention> timed) {
    final out = <Conflict>[];

    // On the bill or a strip, but nobody who can prescribe mentioned it.
    const prescribers = {SourceKind.doctor, SourceKind.prescription};
    if (group.every((m) => !prescribers.contains(m.source)) &&
        group.any(
          (m) => m.source == SourceKind.bill || m.source == SourceKind.strip,
        )) {
      out.add(Conflict(ConflictField.notPrescribed, group));
    }

    final strengths = [
      for (final m in group)
        if (NameMatcher.parse(m.name).strength != null) m,
    ];
    if (_anyPair(
      strengths,
      (a, b) => NameMatcher.strengthsDiffer(a.name, b.name),
    )) {
      out.add(Conflict(ConflictField.strength, strengths));
    }

    final sos = timed.where((m) => m.sig.sos).toList();
    final scheduled = timed.where((m) => m.sig.slots.isNotEmpty).toList();
    if (sos.isNotEmpty && scheduled.isNotEmpty) {
      out.add(Conflict(ConflictField.asNeeded, [...sos, ...scheduled]));
    }

    if (_anyPair(scheduled, (a, b) => !_sameSlots(a.sig, b.sig))) {
      out.add(Conflict(ConflictField.timing, scheduled));
    }

    final fed = timed.where((m) => m.sig.food != FoodTiming.unspecified);
    if (_anyPair(fed.toList(), (a, b) => a.sig.food != b.sig.food)) {
      out.add(Conflict(ConflictField.food, fed.toList()));
    }

    // Duration differences are not a conflict: a doctor saying "for a month"
    // and a bill covering ten days is how pharmacies work.
    if (_anyPair(scheduled, (a, b) => a.sig.everyNDays != b.sig.everyNDays)) {
      out.add(Conflict(ConflictField.interval, scheduled));
    }
    return out;
  }

  static bool _sameSlots(Sig a, Sig b) =>
      a.slots.length == b.slots.length && a.slots.every(b.slots.contains);

  static bool _anyPair(List<Mention> ms, bool Function(Mention, Mention) f) {
    for (var i = 0; i < ms.length; i++) {
      for (var j = i + 1; j < ms.length; j++) {
        if (f(ms[i], ms[j])) return true;
      }
    }
    return false;
  }
}
