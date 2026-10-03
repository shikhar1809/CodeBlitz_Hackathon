import 'sig_parser.dart';

enum ContentKind { prescription, bill, medicineStrip, medicalOther, notMedical }

/// What the gate decided, and the words that decided it.
class ContentVerdict {
  const ContentVerdict(this.kind, this.evidence);

  final ContentKind kind;

  /// Shown on screen, so a person can see why — and overrule it.
  final List<String> evidence;

  bool get medical => kind != ContentKind.notMedical;
}

/// A guardrail on every input: is this a prescription, a bill, a strip —
/// or a holiday photo?
///
/// Never silent, never final. The words behind the verdict come back with it,
/// and every rejection offers "use it anyway": a gate that quietly discarded
/// a real prescription would be worse than no gate.
///
/// Two tiers. Strong signals can carry a verdict: dosage forms, shorthand,
/// dose patterns, strengths. Weak ones only support it: a brand-like word with
/// a number, a store header. The first version counted TOTAL and "night" as
/// medical evidence and matched word-plus-number on its own, so a café
/// receipt, a cricket conversation and "beach 2024" all got through.
abstract final class ContentGate {
  static final _form = RegExp(
    r'\b(?:tab|tabs|tablet|tablets|cap|caps|capsule|capsules|syp|syrup|susp|inj|'
    r'injection|drops?|oint|ointment|cream|gel|sachet|inhaler)\b',
  );
  static final _shorthand = RegExp(
    r'\b(?:od|bd|bid|tds|tid|qid|qds|hs|nocte|sos|prn|stat)\b|\b[ap]/c\b'
    r'|(?<![\d.])(?:\d|0\.5)-(?:\d|0\.5)-(?:\d|0\.5)(?![\d.])',
  );
  static final _strength = RegExp(r'\b\d+(?:\.\d+)?\s?(?:mg|mcg|ml|gm|iu)\b');
  static final _brandNumber = RegExp(r'\b[a-z]{4,}\s\d{1,4}\b');

  /// Words only a bill has. "Batch", "exp" and "store" are on every strip
  /// too, so they cannot tell the two apart.
  static const _billWords = {
    'gstin',
    'gst',
    'mrp',
    'qty',
    'nos',
    'invoice',
    'inv',
    'rate',
    'amount',
    'hsn',
    'dl',
    'pharmacy',
    'medical',
    'medicals',
    'chemist',
    'chemists',
  };
  static const _rxWords = {
    'rx',
    'dr',
    'mbbs',
    'md',
    'clinic',
    'hospital',
    'patient',
    'age',
    'sex',
    'diagnosis',
    'dx',
    'c/o',
    'advice',
    'review',
    'reg',
  };
  static const _stripWords = {
    'mfg',
    'mfd',
    'exp',
    'batch',
    'b.no',
    'contains',
    'store',
    'below',
    'schedule',
    'manufactured',
    'marketed',
    'protect',
    'light',
    'moisture',
    'ip',
    'usp',
    'bp',
  };

  /// Hindi times of day. With a number in the same sentence they are rarely
  /// anything but a dose. The English ones are not enough on their own:
  /// "we batted till night, he scored forty" is not a prescription.
  static const _hindiSlots = {'subah', 'raat', 'shaam', 'sham', 'dopahar'};

  /// A count of tablets said against a time, or an explicit dosing phrase.
  static final _dosing = RegExp(
    r'\b(?:[1-4]|0\.5)\s+(?:in\s+the\s+)?(?:morning|afternoon|evening|night)\b'
    r'|\b(?:morning|night|subah|raat|shaam)\s+(?:[1-4]|0\.5)\b'
    r'|\b(?:before|after)\s+(?:food|meals?|breakfast|dinner)\b'
    r'|\bkhane\s+(?:ke|se)\s+(?:baad|pehle|pahle)\b'
    r'|\b(?:goli|tablets?)\b|\btimes\s+a\s+day\b|\b\d\s+baar\b',
  );

  /// A photo's text. The bar is several signals, at least one of them strong.
  static ContentVerdict judgeText(String text) {
    final s = ' ${SigParser.normalise(text)} ';
    final tokens = s.trim().split(' ').toSet();

    final strong = <String>[
      ..._hits(_form, s),
      ..._hits(_shorthand, s),
      ..._hits(_strength, s),
    ];
    final weak = <String>[
      ..._hits(_brandNumber, s).where((h) => !strong.contains(h)),
    ];
    final bill = tokens.intersection(_billWords).toList();
    final rx = tokens.intersection(_rxWords).toList();
    final strip = tokens.intersection(_stripWords).toList();

    final evidence = _unique([
      ...strong,
      ...weak.take(2),
      ...bill.take(2),
      ...rx.take(2),
    ]).take(6).toList();

    // Weak signals and headers never make a medical verdict on their own,
    // however many there are: a café receipt has plenty of word-and-number.
    if (strong.isEmpty) {
      return ContentVerdict(ContentKind.notMedical, evidence);
    }
    final signals = strong.length + weak.length + bill.length + rx.length;
    if (signals < 2) return ContentVerdict(ContentKind.medicalOther, evidence);

    if (bill.length >= 2 && bill.length >= rx.length) {
      return ContentVerdict(ContentKind.bill, evidence);
    }
    if (rx.isNotEmpty || _shorthand.hasMatch(s)) {
      return ContentVerdict(ContentKind.prescription, evidence);
    }
    if (strip.length >= 2) {
      return ContentVerdict(ContentKind.medicineStrip, evidence);
    }
    if (bill.isNotEmpty) return ContentVerdict(ContentKind.bill, evidence);
    return ContentVerdict(ContentKind.medicalOther, evidence);
  }

  /// Spoken words. The bar is deliberately lower than for photos: "Telma
  /// forty, one in the morning" is one short sentence, and demanding several
  /// signals would reject real instructions all day.
  static ContentVerdict judgeSpeech(String text) {
    final s = ' ${SigParser.normalise(text)} ';
    final tokens = s.trim().split(' ').toSet();
    final strong = <String>[
      ..._hits(_form, s),
      ..._hits(_shorthand, s),
      ..._hits(_strength, s),
    ];
    final dosing = _hits(_dosing, s).toList();
    final hindi = tokens.intersection(_hindiSlots).toList();
    final numbers = RegExp(r'\b\d+(?:\.\d+)?\b').allMatches(s).length;
    final evidence = _unique([...strong, ...dosing, ...hindi]).take(6).toList();

    if (strong.isNotEmpty || dosing.isNotEmpty) {
      return ContentVerdict(ContentKind.prescription, evidence);
    }
    // "Telma 40 subah".
    if (hindi.isNotEmpty && numbers > 0) {
      return ContentVerdict(ContentKind.prescription, evidence);
    }
    return ContentVerdict(ContentKind.notMedical, evidence);
  }

  /// The strong signals in one line — a dosage form, shorthand, a strength.
  /// A line that has one but gave no medicine is a line nobody could read,
  /// and a person is asked about it rather than it being dropped.
  static List<String> strongSignals(String line) {
    final s = ' ${SigParser.normalise(line)} ';
    return _unique([
      ..._hits(_form, s),
      ..._hits(_shorthand, s),
      ..._hits(_strength, s),
    ]);
  }

  static Iterable<String> _hits(RegExp re, String s) =>
      re.allMatches(s).map((m) => m[0]!.trim());

  static List<String> _unique(Iterable<String> xs) {
    final seen = <String>{};
    return [
      for (final x in xs)
        if (seen.add(x)) x,
    ];
  }
}
