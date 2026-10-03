import 'dart:convert';
import 'dart:math' as math;

import 'name_matcher.dart';

/// How a name found its catalogue entry.
enum MatchKind {
  /// Letter for letter, after the usual clean-up: `Tab. Telma-40` is TELMA.
  exact,

  /// Close letters — OCR noise, a slip of the pen: TELNA for TELMA.
  fuzzy,

  /// Close sounds — what speech-to-text writes for a spoken brand:
  /// "Glycomate" for GLYCOMET, "Thairo norm" for THYRONORM.
  phonetic,
}

/// One strength a product is sold in.
///
/// [label] is the number printed after the name — `40` in TELMA 40, `1` in
/// GLYCOMET GP 1. [dose] is what is inside, salt by salt, when known: for a
/// single-salt product it is simply `{salt: label}`; for a combination it is
/// only ever what the catalogue file says, never worked out.
class CatalogStrength {
  const CatalogStrength(this.label, this.dose);

  final String label;
  final Map<String, String> dose;

  double? get value => double.tryParse(label);
}

/// One medicine the catalogue knows: a brand, or a generic by its salts.
class CatalogEntry {
  CatalogEntry({
    required this.name,
    required this.salts,
    required this.forms,
    required this.isBrand,
    required this.source,
    this.unit = 'mg',
    this.refs = const [],
  }) : _parsed = CatalogKey.of(name);

  /// Upper case, as on the pack: `GLYCOMET GP`, `TELMISARTAN`.
  final String name;

  /// Lower-case salt names, normalised at build time (`metformin`, not
  /// `metformin hydrochloride`). Two products with the same set are the same
  /// medicine under different names.
  final List<String> salts;

  /// Dosage form → strengths sold in that form. An empty list means "sold,
  /// strengths not recorded" — then no strength is ever called unusual.
  final Map<String, List<CatalogStrength>> forms;

  /// A brand (TELMA) or a generic (TELMISARTAN).
  final bool isBrand;

  /// `curated` — typed in by hand, see SOURCES.md — or `government`.
  final String source;

  /// The unit the labels are in: `mg`, `mcg`, `IU`.
  final String unit;

  /// Which source lists named it: `janaushadhi`, `nlem2022`, `nppa2022`.
  final List<String> refs;

  final CatalogKey _parsed;

  String get brandKey => _parsed.brand;
  Set<String> get variants => _parsed.variants;
  bool get isCurated => source == 'curated';

  /// Every strength across every form, in number order, each label once.
  List<CatalogStrength> get strengths {
    final seen = <String>{};
    final out = [
      for (final list in forms.values)
        for (final s in list)
          if (seen.add(_canonical(s.label))) s,
    ];
    out.sort((a, b) => (a.value ?? 0).compareTo(b.value ?? 0));
    return out;
  }

  /// Whether strengths are recorded at all — only then can one be unusual.
  bool get hasStrengths => forms.values.any((l) => l.isNotEmpty);

  CatalogStrength? strength(String label) {
    final want = _canonical(label);
    for (final s in strengths) {
      if (_canonical(s.label) == want) return s;
    }
    return null;
  }

  factory CatalogEntry.fromJson(Map<String, Object?> j) {
    final salts = [for (final s in j['salts']! as List) s as String];
    CatalogStrength strengthOf(Object? raw) {
      if (raw is Map) {
        final label = raw['label']! as String;
        final dose = (raw['dose'] as Map?)?.cast<String, String>();
        return CatalogStrength(
          label,
          dose ?? (salts.length == 1 ? {salts.single: label} : const {}),
        );
      }
      final label = '$raw';
      return CatalogStrength(
        label,
        salts.length == 1 ? {salts.single: label} : const {},
      );
    }

    return CatalogEntry(
      name: j['name']! as String,
      salts: salts,
      forms: {
        for (final e in ((j['forms'] as Map?) ?? const {}).entries)
          e.key as String: [for (final s in e.value as List) strengthOf(s)],
      },
      isBrand: j['kind'] == 'brand',
      source: j['source'] as String? ?? 'government',
      unit: j['unit'] as String? ?? 'mg',
      refs: [for (final r in j['refs'] as List? ?? const []) r as String],
    );
  }

  @override
  String toString() => 'CatalogEntry($name)';
}

/// A name read from a source, placed in the catalogue.
class CatalogMatch {
  const CatalogMatch({
    required this.entry,
    required this.kind,
    required this.score,
    required this.query,
    this.strength,
  });

  final CatalogEntry entry;
  final MatchKind kind;

  /// Jaro-Winkler on the brand letters; 1 for an exact match.
  final double score;

  /// The name as it was read.
  final String query;

  /// The strength that came with the reading, if any.
  final String? strength;

  bool get exact => kind == MatchKind.exact;

  /// What a person would be asked: "did you mean TELMA 40?". Only the
  /// reading's own strength is carried over, never one picked for it.
  String get proposal =>
      strength == null ? entry.name : '${entry.name} $strength';

  @override
  String toString() => 'CatalogMatch(${kind.name}: $query → $proposal)';
}

/// Two brands that look or sound alike and are not the same medicine.
class LookAlikePair {
  const LookAlikePair(this.a, this.b, this.why);

  final String a;
  final String b;

  /// Why the pair is on the list, for the person reading the card.
  final String why;

  factory LookAlikePair.fromJson(Map<String, Object?> j) => LookAlikePair(
    (j['a']! as String).toUpperCase(),
    (j['b']! as String).toUpperCase(),
    j['why'] as String? ?? '',
  );
}

/// The brand letters and variant suffixes of a name, the way the catalogue
/// indexes it.
///
/// [NameMatcher.parse] with one addition: a variant written with its number
/// stuck on — `GP1`, `GP2` — is the variant `gp` with strength `1`. GLYCOMET
/// GP 1 and GLYCOMET GP1 are the same tablet.
class CatalogKey {
  const CatalogKey(this.brand, this.variants, this.strength);

  final String brand;
  final Set<String> variants;
  final String? strength;

  String get key => '$brand|${(variants.toList()..sort()).join(',')}';

  static CatalogKey of(String name) {
    // `Tab.` is a dosage form; only a dot between digits is a decimal.
    final p = NameMatcher.parse(name.replaceAll(RegExp(r'\.(?!\d)'), ' '));
    var strength = p.strength;
    final variants = <String>{};
    for (final v in p.variants) {
      final m = RegExp(r'^([a-z]+)(\d+(?:\.\d+)?)$').firstMatch(v);
      if (m == null) {
        variants.add(v);
      } else {
        variants.add(m[1]!);
        strength ??= m[2];
      }
    }
    return CatalogKey(p.brand, variants, strength);
  }
}

/// The medicines that exist in India, as far as open government lists and a
/// small hand-checked seed of brands know.
///
/// Before this, the merge could only compare sources with each other: TELNA
/// on a prescription and TELMA on a bill lined up, but nothing knew TELNA is
/// not a medicine, that TELMA comes in 20, 40 and 80, or that TELMIKIND is the
/// same telmisartan. The catalogue knows — and only ever *proposes*. A name is
/// never changed because the catalogue said so; a person is asked.
///
/// Pure Dart and synchronous once built. The Flutter side loads the JSON from
/// the asset bundle (`CatalogLoader`) and hands the string here.
///
/// Lookup is exact first, then fuzzy on a trigram index, then phonetic. The
/// trigram index keeps the fuzzy step to a few dozen Jaro-Winkler calls
/// whatever the size of the list — ten thousand entries read in well under a
/// millisecond per name.
class MedicineCatalog {
  MedicineCatalog(
    Iterable<CatalogEntry> entries, {
    Iterable<LookAlikePair> lookAlikes = const [],
  }) : entries = List.unmodifiable(entries),
       lookAlikes = List.unmodifiable(lookAlikes) {
    for (var i = 0; i < this.entries.length; i++) {
      final e = this.entries[i];
      if (e.brandKey.isEmpty) continue;
      _byKey.putIfAbsent(CatalogKey(e.brandKey, e.variants, null).key, () => i);
      for (final g in trigrams(e.brandKey)) {
        (_byTrigram[g] ??= []).add(i);
      }
      (_byPhonetic[phoneticKey(e.brandKey)] ??= []).add(i);
      for (final s in e.salts) {
        (_bySalt[s] ??= []).add(i);
      }
    }
  }

  /// `assets/catalog/medicines.json`, and optionally `lookalikes.json`.
  factory MedicineCatalog.fromJson(String medicines, {String? lookAlikes}) {
    final root = jsonDecode(medicines) as Map<String, Object?>;
    final pairs = lookAlikes == null
        ? const <LookAlikePair>[]
        : [
            for (final p
                in (jsonDecode(lookAlikes) as Map<String, Object?>)['pairs']!
                    as List)
              LookAlikePair.fromJson((p as Map).cast<String, Object?>()),
          ];
    return MedicineCatalog(
      [
        for (final e in root['entries']! as List)
          CatalogEntry.fromJson((e as Map).cast<String, Object?>()),
      ],
      lookAlikes: pairs,
    );
  }

  static final empty = MedicineCatalog(const []);

  final List<CatalogEntry> entries;
  final List<LookAlikePair> lookAlikes;

  final _byKey = <String, int>{};
  final _byTrigram = <String, List<int>>{};
  final _byPhonetic = <String, List<int>>{};
  final _bySalt = <String, List<int>>{};

  int get length => entries.length;

  /// Same bar as [NameMatcher]: close enough that two sources are taken to
  /// mean the same medicine is close enough to propose a catalogue name.
  static const threshold = NameMatcher.threshold;

  /// A spoken name may be spelt far from the pack — "Glycomate" — so a
  /// matching sound is enough at a lower letter score.
  static const phoneticFloor = 0.78;

  /// Below this many letters a sound is too common to mean anything: PAN and
  /// PEN, DOLO and DILO.
  static const phoneticMinLength = 5;

  /// Where [name] sits in the catalogue, or null when nothing is close.
  CatalogMatch? lookup(String name) {
    final q = CatalogKey.of(name);
    if (q.brand.isEmpty) return null;

    final exact = _byKey[q.key];
    if (exact != null) {
      return CatalogMatch(
        entry: entries[exact],
        kind: MatchKind.exact,
        score: 1,
        query: name,
        strength: q.strength,
      );
    }

    CatalogMatch? best;
    void consider(int i, MatchKind kind) {
      final e = entries[i];
      if (!_sameSet(e.variants, q.variants)) return;
      final shorter = math.min(e.brandKey.length, q.brand.length);
      final longer = math.max(e.brandKey.length, q.brand.length);
      if (shorter / longer < .75) return;
      final jw = NameMatcher.jaroWinkler(q.brand, e.brandKey);
      final double score;
      if (kind == MatchKind.phonetic) {
        if (jw < phoneticFloor) return;
        score = math.max(jw, threshold);
      } else {
        if (jw < threshold) return;
        score = jw;
      }
      if (best != null && best!.score >= score) return;
      best = CatalogMatch(
        entry: e,
        kind: kind,
        score: score,
        query: name,
        strength: q.strength,
      );
    }

    for (final i in _candidates(q.brand)) {
      consider(i, MatchKind.fuzzy);
    }
    if (q.brand.length >= phoneticMinLength) {
      for (final i in _byPhonetic[phoneticKey(q.brand)] ?? const <int>[]) {
        if (best?.entry == entries[i]) continue;
        consider(i, MatchKind.phonetic);
      }
    }
    return best;
  }

  bool isKnown(String name) => lookup(name) != null;

  /// The strengths [brand] is sold in, smallest first. Empty when the brand
  /// is unknown or its strengths were not recorded.
  List<String> strengthsFor(String brand) => [
    for (final s in lookup(brand)?.entry.strengths ?? const <CatalogStrength>[])
      s.label,
  ];

  /// Whether [name]'s own strength is one the product is sold in. Null when
  /// that cannot be said: no strength read, an unknown name, no strengths on
  /// record, or a combination generic whose label is several numbers.
  bool? sellsStrength(String name) {
    final m = lookup(name);
    if (m == null || m.strength == null || !m.entry.hasStrengths) return null;
    if (!m.entry.isBrand && m.entry.salts.length > 1) return null;
    return m.entry.strength(m.strength!) != null;
  }

  /// The salts in [brand], or null when it is unknown.
  List<String>? saltOf(String brand) => lookup(brand)?.entry.salts;

  /// The same salts — TELMA and TELMIKIND, TELMA and TELMISARTAN. Strength
  /// is not compared; see [sameSaltAndStrength].
  bool sameSalt(String a, String b) {
    final x = saltOf(a), y = saltOf(b);
    return x != null && y != null && _sameSet(x.toSet(), y.toSet());
  }

  /// What is inside one tablet of [name], salt → amount. Null unless the
  /// reading has a strength the catalogue lists with its contents.
  Map<String, double>? doseOf(String name) {
    final m = lookup(name);
    final s = m?.strength == null ? null : m!.entry.strength(m.strength!);
    if (s == null || s.dose.isEmpty) return null;
    final out = <String, double>{};
    for (final e in s.dose.entries) {
      final v = double.tryParse(e.value);
      if (v == null) return null;
      out[e.key] = v;
    }
    return out;
  }

  /// The same salts *and* the same amount of each: TELMA 40 and TELMIKIND 40.
  /// False whenever either side cannot be pinned down.
  bool sameSaltAndStrength(String a, String b) {
    final x = doseOf(a), y = doseOf(b);
    if (x == null || y == null || x.length != y.length) return false;
    return x.entries.every((e) => y[e.key] == e.value);
  }

  /// Everything containing [salt]: the generic, every brand, and every
  /// combination it is part of.
  List<CatalogEntry> withSalt(String salt) => [
    for (final i in _bySalt[salt.toLowerCase()] ?? const <int>[]) entries[i],
  ];

  /// The look-alike pair [entryName] is on, if any.
  LookAlikePair? lookAlikeOf(String entryName) {
    final n = entryName.toUpperCase();
    for (final p in lookAlikes) {
      if (p.a == n || p.b == n) return p;
    }
    return null;
  }

  // ── Index ────────────────────────────────────────────────────────────────

  /// The entries sharing the most trigrams with [brand]; at most [limit].
  Iterable<int> _candidates(String brand, {int limit = 40}) {
    final grams = trigrams(brand);
    final counts = <int, int>{};
    for (final g in grams) {
      for (final i in _byTrigram[g] ?? const <int>[]) {
        counts[i] = (counts[i] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const [];
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value - a.value;
        return c != 0 ? c : a.key - b.key;
      });
    return ranked.take(limit).map((e) => e.key);
  }

  /// `^te`, `tel`, `elm`, `lma`, `ma$` — the ends padded so a short brand
  /// still has three, and a first letter weighs more.
  static Set<String> trigrams(String s) {
    final p = '^$s\$';
    return {for (var i = 0; i + 3 <= p.length; i++) p.substring(i, i + 3)};
  }

  /// A rough sound of a brand as Indian English speech-to-text spells it.
  ///
  /// Letters that sound alike fold together (`ph`→f, `c`→k or s, `z`→s,
  /// `w`→v, `y`→i), `h` drops, doubled letters collapse, and every vowel but
  /// a leading one goes — vowels are what speech gets wrong most:
  /// GLYCOMET and "Glycomate" are both `glkmt`; THYRONORM and "Thairo norm"
  /// are both `trnrm`.
  static String phoneticKey(String letters) {
    var s = letters.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    s = s
        .replaceAll('ph', 'f')
        .replaceAll('ck', 'k')
        .replaceAll(RegExp('c(?=[eiy])'), 's')
        .replaceAll('c', 'k')
        .replaceAll('q', 'k')
        .replaceAll('x', 'ks')
        .replaceAll('z', 's')
        .replaceAll('w', 'v')
        .replaceAll('y', 'i')
        .replaceAll('h', '');
    if (s.isEmpty) return s;
    final out = StringBuffer();
    String? last;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      final vowel = 'aeiou'.contains(c);
      if (vowel) {
        if (i == 0) out.write('a');
        last = c;
        continue;
      }
      if (c != last) out.write(c);
      last = c;
    }
    return out.toString();
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

/// `40`, `40.0` and `40.00` are one strength.
String _canonical(String label) {
  final v = double.tryParse(label);
  if (v == null) return label.trim().toLowerCase();
  return v == v.roundToDouble() ? '${v.round()}' : '$v';
}
