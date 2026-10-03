import 'mention.dart';
import 'mention_extractor.dart';
import 'merge_engine.dart';
import 'name_matcher.dart';
import 'sig_parser.dart';

/// What the counter can get wrong, and what a person is asked about the
/// moment it is found.
enum PharmacyIssueKind {
  /// A different brand or generic handed over in place of the prescribed one.
  substitution,

  /// Two sources give the same medicine different strengths.
  strength,

  /// On the bill or a strip, but nobody who can prescribe mentioned it.
  notPrescribed,

  /// The bill's count of tablets does not fit the course.
  quantity,

  /// A photo line that looks like a medicine, but gave none.
  unreadable,
}

/// One question for a person, with both readings and where each came from.
class PharmacyIssue {
  const PharmacyIssue({
    required this.kind,
    required this.medicineId,
    this.otherId,
    this.a,
    this.b,
    this.line,
    this.needed,
    this.sold,
    this.courseDays,
    this.billDays,
  });

  final PharmacyIssueKind kind;

  /// The card this is about. For an unreadable line, a `line-…` id.
  final String medicineId;

  /// A second card the same answer settles: the bill's own row when the
  /// substitute was printed on it.
  final String? otherId;

  /// Reading A — what was prescribed, or the course.
  final Mention? a;

  /// Reading B — what was sold. Null where the other side is silent: nobody
  /// prescribed a medicine that is only on the bill.
  final Mention? b;

  /// The line nobody could read.
  final UnreadLine? line;

  /// Quantity only: tablets the course needs and tablets on the bill, and how
  /// many days each lasts.
  final int? needed;
  final int? sold;
  final int? courseDays;
  final int? billDays;

  /// One question per kind per card. Answers are matched back by this.
  String get key => keyOf(kind, medicineId);

  static String keyOf(PharmacyIssueKind kind, String medicineId) =>
      '${kind.name}:$medicineId';

  @override
  String toString() => 'PharmacyIssue($key)';
}

/// Finds the pharmacy-side questions in a merged visit. Plain Dart, like the
/// merge engine: the same evidence always raises the same questions, and it
/// never answers one.
abstract final class PharmacyCheck {
  /// A course is fine when the bill covers it with less than one strip to
  /// spare. Strips come in tens and fifteens; the chemist cannot sell 14.
  static const spareStrip = 15;

  /// Two names share this many brand letters before a bill-only medicine is
  /// taken to be a stand-in for a prescribed one: TELMA and TELMISARTAN.
  static const sharedPrefix = 4;

  static const _prescribers = {SourceKind.doctor, SourceKind.prescription};
  static const _printed = {SourceKind.bill, SourceKind.strip};

  static List<PharmacyIssue> find({
    required List<MergedMedicine> rows,
    String chemistWords = '',
    List<UnreadLine> unreadable = const [],
  }) {
    final issues = <PharmacyIssue>[];
    final paired = <String>{};

    // 1. The chemist said so: "Telma ki jagah Telmisartan de diya".
    for (final said in _saidSubstitutions(chemistWords)) {
      final from = _rowNaming(rows, said.from, preferPrescribed: true);
      final to = _rowNaming(rows, said.to, except: from);
      if (from == null && to == null) continue;
      final a = from == null
          ? _spoken(said.from, said.raw)
          : _prescribedSide(from);
      final b = to == null ? _spoken(said.to, said.raw) : _soldSide(to);
      final issue = PharmacyIssue(
        kind: PharmacyIssueKind.substitution,
        medicineId: (from ?? to)!.id,
        otherId: from == null ? null : to?.id,
        a: a,
        b: b,
      );
      if (issues.any((i) => i.key == issue.key)) continue;
      issues.add(issue);
      paired.addAll([?from?.id, ?to?.id]);
    }

    // 2. The bill says so: a medicine nobody prescribed, and a prescribed one
    // missing from the bill, with the same brand letters — or the only one of
    // each, at the same strength.
    final billRead = rows.any(
      (r) => r.evidence.any((m) => _printed.contains(m.source)),
    );
    final soldOnly = [
      for (final r in rows)
        if (!paired.contains(r.id) && _has(r, ConflictField.notPrescribed)) r,
    ];
    final unbought = [
      for (final r in rows)
        if (billRead &&
            !paired.contains(r.id) &&
            r.evidence.any((m) => _prescribers.contains(m.source)) &&
            !r.evidence.any((m) => _printed.contains(m.source)))
          r,
    ];
    for (final s in soldOnly) {
      final byLetters = unbought
          .where((u) => !paired.contains(u.id) && _sharePrefix(u.name, s.name))
          .toList();
      MergedMedicine? u;
      if (byLetters.length == 1) {
        u = byLetters.single;
      } else if (byLetters.isEmpty &&
          soldOnly.length == 1 &&
          unbought.length == 1 &&
          s.strength != null &&
          !NameMatcher.strengthsDiffer(unbought.single.name, s.name) &&
          NameMatcher.parse(unbought.single.name).strength != null) {
        u = unbought.single;
      }
      if (u == null) continue;
      issues.add(
        PharmacyIssue(
          kind: PharmacyIssueKind.substitution,
          medicineId: u.id,
          otherId: s.id,
          a: _prescribedSide(u),
          b: _soldSide(s),
        ),
      );
      paired.addAll([u.id, s.id]);
    }

    for (final r in rows) {
      // 3. Strength.
      final strength = r.conflicts
          .where((c) => c.field == ConflictField.strength)
          .firstOrNull;
      if (strength != null) {
        final sides = _strengthSides(strength.sides);
        if (sides != null) {
          issues.add(
            PharmacyIssue(
              kind: PharmacyIssueKind.strength,
              medicineId: r.id,
              a: sides.$1,
              b: sides.$2,
            ),
          );
        }
      }

      // 4. Sold, nobody prescribed it — unless it was the stand-in above.
      if (!paired.contains(r.id) && _has(r, ConflictField.notPrescribed)) {
        issues.add(
          PharmacyIssue(
            kind: PharmacyIssueKind.notPrescribed,
            medicineId: r.id,
            a: _soldSide(r),
          ),
        );
      }

      // 5. Quantity.
      final q = _quantity(r);
      if (q != null) issues.add(q);
    }

    // 6. Lines nobody could read.
    final lineIds = <String>{};
    for (final l in unreadable) {
      var id = 'line-${MergedMedicine.idFor(l.text)}';
      for (var n = 2; lineIds.contains(id); n++) {
        id = 'line-${MergedMedicine.idFor(l.text)}-$n';
      }
      lineIds.add(id);
      issues.add(
        PharmacyIssue(
          kind: PharmacyIssueKind.unreadable,
          medicineId: id,
          line: l,
        ),
      );
    }

    // In card order, then by kind; lines last.
    final order = {for (var i = 0; i < rows.length; i++) rows[i].id: i};
    issues.sort((x, y) {
      final ox = order[x.medicineId] ?? rows.length;
      final oy = order[y.medicineId] ?? rows.length;
      if (ox != oy) return ox - oy;
      return x.kind.index - y.kind.index;
    });
    return issues;
  }

  // ── Substitution ────────────────────────────────────────────────────────

  static final _name = r'([a-z][a-z0-9\-]*)(?:\s+(\d+(?:\.\d+)?)(?:mg|mcg)?)?';

  /// "X ki jagah Y", "X ke badle Y" — Y was given for X.
  static final _hindi = RegExp(
    '$_name\\s+(?:ki|ke)\\s+(?:jagah|jageh|jagha|badle|badley|bajaye)'
    '\\s+$_name',
  );

  /// "Y instead of X", "Y in place of X".
  static final _english = RegExp(
    '$_name\\s+(?:instead\\s+of|in\\s+place\\s+of)\\s+$_name',
  );

  /// Words that sit where a name would, and are not one.
  static const _notNames = {
    'dusri',
    'doosri',
    'dusra',
    'doosra',
    'koi',
    'generic',
    'ye',
    'yeh',
    'wo',
    'woh',
    'it',
    'this',
    'that',
    'the',
    'one',
    'gave',
    'given',
    'diya',
    'di',
    'de',
    'dawai',
    'dawa',
    'medicine',
    'tablet',
    'tab',
  };

  static List<({String from, String to, String raw})> _saidSubstitutions(
    String words,
  ) {
    final out = <({String from, String to, String raw})>[];
    for (final sentence in words.split(RegExp(r'[.;।\n]'))) {
      if (sentence.trim().isEmpty) continue;
      final s = SigParser.normalise(sentence);
      String nameOf(String? w, String? n) =>
          [w!.toUpperCase(), ?n?.replaceAll(RegExp(r'[a-z]+$'), '')].join(' ');
      bool ok(String? w) =>
          w != null && w.length >= 3 && !_notNames.contains(w);
      for (final m in _hindi.allMatches(s)) {
        if (!ok(m[1]) || !ok(m[3])) continue;
        out.add((
          from: nameOf(m[1], m[2]),
          to: nameOf(m[3], m[4]),
          raw: sentence.trim(),
        ));
      }
      for (final m in _english.allMatches(s)) {
        if (!ok(m[1]) || !ok(m[3])) continue;
        out.add((
          from: nameOf(m[3], m[4]),
          to: nameOf(m[1], m[2]),
          raw: sentence.trim(),
        ));
      }
    }
    return out;
  }

  static MergedMedicine? _rowNaming(
    List<MergedMedicine> rows,
    String name, {
    MergedMedicine? except,
    bool preferPrescribed = false,
  }) {
    final hits = [
      for (final r in rows)
        if (r != except &&
            r.evidence.any((m) => NameMatcher.same(m.name, name)))
          r,
    ];
    if (hits.isEmpty) return null;
    if (preferPrescribed) {
      final prescribed = hits.where(
        (r) => r.evidence.any((m) => _prescribers.contains(m.source)),
      );
      if (prescribed.isNotEmpty) return prescribed.first;
    }
    return hits.first;
  }

  /// What was prescribed: the prescription, then the doctor, then whatever
  /// else named it — never the chemist's own sentence when anything else did.
  static Mention _prescribedSide(MergedMedicine r) {
    for (final s in const [
      SourceKind.prescription,
      SourceKind.doctor,
      SourceKind.bill,
      SourceKind.strip,
    ]) {
      final m = r.evidence.where((m) => m.source == s).firstOrNull;
      if (m != null) return m;
    }
    return r.evidence.first;
  }

  /// What was sold: the bill, then a strip, then the chemist.
  static Mention _soldSide(MergedMedicine r) {
    for (final s in const [
      SourceKind.bill,
      SourceKind.strip,
      SourceKind.chemist,
    ]) {
      final m = r.evidence.where((m) => m.source == s).firstOrNull;
      if (m != null) return m;
    }
    return r.evidence.first;
  }

  /// A name only the chemist said. Quoted in their words, never promoted.
  static Mention _spoken(String name, String raw) {
    final parsed = NameMatcher.parse(name);
    return Mention(
      source: SourceKind.chemist,
      name: name,
      strength: parsed.strength,
      raw: raw,
    );
  }

  static bool _sharePrefix(String x, String y) {
    final a = NameMatcher.parse(x).brand, b = NameMatcher.parse(y).brand;
    if (a.length < sharedPrefix || b.length < sharedPrefix) return false;
    return a.substring(0, sharedPrefix) == b.substring(0, sharedPrefix);
  }

  // ── Strength ────────────────────────────────────────────────────────────

  /// The prescribed strength against the sold one, where both exist.
  static (Mention, Mention)? _strengthSides(List<Mention> sides) {
    int rank(Mention m, List<SourceKind> order) => order.indexOf(m.source);
    const prescribedFirst = [
      SourceKind.prescription,
      SourceKind.doctor,
      SourceKind.bill,
      SourceKind.strip,
      SourceKind.chemist,
    ];
    const soldFirst = [
      SourceKind.bill,
      SourceKind.strip,
      SourceKind.chemist,
      SourceKind.doctor,
      SourceKind.prescription,
    ];
    final a =
        ([...sides]..sort(
              (x, y) => rank(x, prescribedFirst) - rank(y, prescribedFirst),
            ))
            .first;
    final b =
        ([...sides]..sort((x, y) => rank(x, soldFirst) - rank(y, soldFirst)))
            .where((m) => NameMatcher.strengthsDiffer(a.name, m.name))
            .firstOrNull;
    return b == null ? null : (a, b);
  }

  // ── Quantity ────────────────────────────────────────────────────────────

  /// Only when the course is fully known: slots, an amount and a duration.
  /// A course nobody gave is never computed — that would be inventing one.
  static PharmacyIssue? _quantity(MergedMedicine r) {
    final bill = r.evidence
        .where((m) => _printed.contains(m.source) && m.packQuantity != null)
        .firstOrNull;
    final sig = r.sig;
    if (bill == null ||
        sig.sos ||
        sig.slots.isEmpty ||
        sig.durationDays == null) {
      return null;
    }
    final course = r.evidence
        .where((m) => m.sig.durationDays != null)
        .firstWhere(
          (m) => _prescribers.contains(m.source),
          orElse: () =>
              r.evidence.firstWhere((m) => m.sig.durationDays != null),
        );
    final every = sig.everyNDays ?? 1;
    final perDoseDay = sig.slots.length * sig.unitsPerDose;
    final doseDays = (sig.durationDays! / every).ceil();
    final needed = (doseDays * perDoseDay).ceil();
    final sold = bill.packQuantity!;
    if (sold >= needed && sold < needed + spareStrip) return null;
    return PharmacyIssue(
      kind: PharmacyIssueKind.quantity,
      medicineId: r.id,
      a: course,
      b: bill,
      needed: needed,
      sold: sold,
      courseDays: sig.durationDays,
      billDays: (sold / perDoseDay).floor() * every,
    );
  }

  static bool _has(MergedMedicine r, ConflictField f) =>
      r.conflicts.any((c) => c.field == f);
}

/// A person's answer to one pharmacy question.
enum PharmacyChoice {
  /// Reading A is right.
  a,

  /// Reading B is right.
  b,

  /// Neither — with an explanation. Context, not a resolution.
  neither,

  /// Not sure — ask the chemist later. The card stays red.
  notSure,
}

enum AnsweredBy { patient, caretaker, doctor }

/// Every answer, kept on the visit: what was asked, what was said, by whom
/// and when. Only A or B settles a question; the rest is context.
class PharmacyResolution {
  const PharmacyResolution({
    required this.kind,
    required this.medicineId,
    required this.choice,
    required this.answeredBy,
    required this.answeredAt,
    this.explanation = '',
    this.voiceNotePath,
  });

  final PharmacyIssueKind kind;
  final String medicineId;
  final PharmacyChoice choice;
  final String explanation;
  final String? voiceNotePath;
  final AnsweredBy answeredBy;
  final DateTime answeredAt;

  bool get settles => choice == PharmacyChoice.a || choice == PharmacyChoice.b;

  String get key => PharmacyIssue.keyOf(kind, medicineId);

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'medicineId': medicineId,
    'choice': choice.name,
    if (explanation.isNotEmpty) 'explanation': explanation,
    if (voiceNotePath != null) 'voiceNotePath': voiceNotePath,
    'answeredBy': answeredBy.name,
    'answeredAt': answeredAt.toIso8601String(),
  };

  factory PharmacyResolution.fromJson(Map<String, Object?> j) =>
      PharmacyResolution(
        kind: PharmacyIssueKind.values.byName(j['kind']! as String),
        medicineId: j['medicineId']! as String,
        choice: PharmacyChoice.values.byName(j['choice']! as String),
        explanation: j['explanation'] as String? ?? '',
        voiceNotePath: j['voiceNotePath'] as String?,
        answeredBy: AnsweredBy.values.byName(j['answeredBy']! as String),
        answeredAt: DateTime.parse(j['answeredAt']! as String),
      );
}
