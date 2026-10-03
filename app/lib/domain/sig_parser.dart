import 'sig.dart';

/// One line of a prescription, bill, strip or dictation, taken apart.
class ParsedLine {
  const ParsedLine({
    required this.raw,
    this.name,
    this.strength,
    this.form,
    this.sig = Sig.empty,
    this.purpose,
    this.packQuantity,
  });

  final String raw;

  /// Upper case, English letters, as printed — `TELMA 40`. Never translated.
  final String? name;

  /// The number that followed the name, with its unit only if one was written.
  final String? strength;

  /// `tab`, `cap`, `syp`… Recorded, and left out of the name.
  final String? form;
  final Sig sig;

  /// Quoted from the words, never inferred: "for BP" gives `BP`.
  final String? purpose;

  /// How many tablets a bill or strip line says were sold — `30 NOS` is 30,
  /// `1x15` is 15. Never part of the name or the Sig: it is what was handed
  /// over, not how to take it.
  final int? packQuantity;
}

/// Prescription shorthand to structure, in code.
///
/// Deterministic, auditable, no model: `OD`, `BD`, `TDS`, `1-0-1`, `a/c`,
/// `p/c`, `HS`, `SOS`, `STAT`, `x 10 days`, alternate days, and the Hindi and
/// Hinglish a doctor actually says — "subah ek, khane ke baad". Anything it
/// cannot place is returned as `unresolved`, so a person looks at it.
abstract final class SigParser {
  static Sig parseSig(String text) => parseLine(text, expectName: false).sig;

  /// [printed] is true for a bill or a strip: machine-printed text, where a
  /// number after a name is a strength and never a count of tablets.
  static ParsedLine parseLine(
    String text, {
    bool expectName = true,
    bool printed = false,
  }) {
    var s = normalise(text);

    String? name, strength, form;
    if (expectName) {
      final cut = _cutName(s, printed: printed);
      name = cut.name;
      strength = cut.strength;
      form = cut.form;
      s = cut.rest;
    }

    final purposeHit = _purpose(s);
    s = purposeHit.rest;

    final parsed = _parseSig(s);
    return ParsedLine(
      raw: text,
      name: name,
      strength: strength,
      form: form,
      sig: parsed.sig,
      purpose: purposeHit.purpose,
      packQuantity: parsed.pack,
    );
  }

  // ── Normalising ─────────────────────────────────────────────────────────

  /// Lower case, speech numbers as digits, and shorthand in one spelling.
  static String normalise(String text) {
    var s = ' ${text.toLowerCase()} ';
    s = s.replaceAll(RegExp('[‒-―−]'), '-');
    s = s.replaceAll('½', ' 0.5 ');
    // p.c. / a.c. before the full stops go.
    s = s.replaceAllMapped(
      RegExp(r'(?<![a-z])([ap])\s?\.\s?c\s?\.?(?![a-z])'),
      (m) => ' ${m[1]}/c ',
    );
    // Prices: 125.00
    s = s.replaceAll(RegExp(r'(?<![\d.])\d+\.\d\d(?![\d])'), ' ');
    // Full stops and separators, except inside a decimal.
    s = s.replaceAll(RegExp(r'(?<!\d)\.|\.(?!\d)'), ' ');
    // Numbers in words before commas go: a pause ends a number, so
    // "forty, one in the morning" is 40 and then 1, not 41.
    s = _numberWords(s.replaceAllMapped(RegExp(r'[,;:]'), (m) => ' | '));
    s = s.replaceAll(RegExp(r'''[,;:()\[\]{}"'!?*|•#]'''), ' ');
    // 1 - 0 - 1 → 1-0-1
    s = s.replaceAllMapped(
      RegExp(
        r'(?<![\d.])(\d|0\.5)\s*-\s*(\d|0\.5)\s*-\s*(\d|0\.5)'
        r'(?:\s*-\s*(\d|0\.5))?(?![\d.])',
      ),
      (m) => ' ${[m[1], m[2], m[3], ?m[4]].join('-')} ',
    );
    // x10 → x 10, 10days → 10 days, 40 mg → 40mg
    s = s.replaceAllMapped(RegExp(r'\bx(\d)'), (m) => 'x ${m[1]}');
    s = s.replaceAllMapped(
      RegExp(r'(\d)(days?|din|weeks?|months?)\b'),
      (m) => '${m[1]} ${m[2]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'(\d)\s+(mg|mcg|ml|gm|g|iu)\b'),
      (m) => '${m[1]}${m[2]}',
    );
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const _units = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, //
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
    'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
    'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
    'ek': 1, 'teen': 3, 'char': 4, 'chaar': 4, 'paanch': 5, 'panch': 5,
    'das': 10,
  };
  static const _tens = {
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fourty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };
  static const _fractions = {
    'half': '0.5',
    'aadha': '0.5',
    'aadhi': '0.5',
    'adha': '0.5',
    'adhi': '0.5',
    'dedh': '1.5',
  };
  static const _doContext = {
    'goli',
    'golii',
    'tablet',
    'tablets',
    'tab',
    'tabs',
    'baar',
    'bar',
    'capsule',
    'cap',
    'chammach',
    'spoon',
  };
  static const _slotWords = {
    'subah',
    'savere',
    'sawere',
    'dopahar',
    'dopehar',
    'shaam',
    'sham',
    'raat',
  };

  /// "Telma forty" → "telma 40"; "Glycomet five hundred" → "glycomet 500";
  /// "Dolo six fifty" → "dolo 650". "do" is Hindi for two only where it is
  /// counting something, never the English verb.
  static String _numberWords(String s) {
    final tokens = s.split(' ');
    final out = <String>[];
    var i = 0;
    while (i < tokens.length) {
      final t = tokens[i];
      if (_fractions.containsKey(t)) {
        out.add(_fractions[t]!);
        i++;
        continue;
      }
      if (t == 'do') {
        final next = i + 1 < tokens.length ? tokens[i + 1] : '';
        final prev = out.isNotEmpty ? out.last : '';
        out.add(
          _doContext.contains(next) || _slotWords.contains(prev) ? '2' : t,
        );
        i++;
        continue;
      }
      if (!_units.containsKey(t) && !_tens.containsKey(t)) {
        out.add(t);
        i++;
        continue;
      }
      // A run of number words.
      var total = 0, current = 0, j = i;
      var sawHundred = false;
      while (j < tokens.length) {
        final w = tokens[j];
        if (_units.containsKey(w)) {
          // "six fifty": a unit followed by a ten, with no "hundred" between.
          if (current > 0 && current < 10 && !sawHundred) break;
          current += _units[w]!;
        } else if (_tens.containsKey(w)) {
          if (current > 0 && current < 10 && !sawHundred) {
            current = current * 100 + _tens[w]!;
          } else {
            current += _tens[w]!;
          }
        } else if (w == 'hundred' && current > 0) {
          current *= 100;
          sawHundred = true;
        } else if (w == 'thousand' && current > 0) {
          total += current * 1000;
          current = 0;
        } else {
          break;
        }
        j++;
      }
      out.add('${total + current}');
      i = j;
    }
    return out.join(' ');
  }

  // ── The name ────────────────────────────────────────────────────────────

  static const forms = {
    'tab',
    'tabs',
    'tablet',
    'tablets',
    'cap',
    'caps',
    'capsule',
    'capsules',
    'syp',
    'syrup',
    'susp',
    'suspension',
    'inj',
    'injection',
    'drop',
    'drops',
    'oint',
    'ointment',
    'cream',
    'gel',
    'lotion',
    'sachet',
    'powder',
    'inh',
    'inhaler',
    'spray',
    'soln',
    'solution',
    'tb',
    't',
    'c',
  };

  /// Suffixes that make a different product. GLYCOMET is not GLYCOMET GP.
  static const variants = {
    'sr',
    'xr',
    'er',
    'mr',
    'cr',
    'gp',
    'gp1',
    'gp2',
    'm',
    'h',
    'am',
    'ct',
    'ln',
    'trio',
    'plus',
    'forte',
    'ds',
    'dsr',
    'd',
    'mt',
    'xl',
    'ls',
  };

  /// Words that open a line that is not a medicine.
  static const stopwords = {
    'total',
    'subtotal',
    'amount',
    'amt',
    'gst',
    'cgst',
    'sgst',
    'igst',
    'date',
    'invoice',
    'bill',
    'patient',
    'name',
    'age',
    'sex',
    'dr',
    'doctor',
    'mbbs',
    'md',
    'qty',
    'quantity',
    'rate',
    'mrp',
    'batch',
    'exp',
    'expiry',
    'discount',
    'disc',
    'net',
    'grand',
    'cash',
    'phone',
    'mobile',
    'mob',
    'address',
    'pharmacy',
    'medical',
    'medicals',
    'store',
    'stores',
    'chemist',
    'hospital',
    'clinic',
    'reg',
    'regd',
    'signature',
    'sign',
    'thank',
    'thanks',
    'rs',
    'inr',
    'gstin',
    'dl',
    'hsn',
    'pack',
    'paid',
    'balance',
    'round',
    'off',
    'counter',
    'time',
    'weight',
    'bp',
    'pulse',
    'temp',
    'diagnosis',
    'dx',
    'advice',
    'adv',
    'review',
    'follow',
    'next',
    'visit',
    'c/o',
    'complaints',
    'sr',
    'item',
    'items',
    'particulars',
    'description',
    'product',
    'mfg',
    'mfr',
    'no',
    'sl',
    's',
  };

  static final _strengthRe = RegExp(r'^\d+(?:\.\d+)?(?:mg|mcg|ml|gm|g|iu|%)?$');

  static ({String? name, String? strength, String? form, String rest}) _cutName(
    String s, {
    required bool printed,
  }) {
    final tokens = s.split(' ').where((t) => t.isNotEmpty).toList();
    var i = 0;
    String? form;

    // Leading numbering, "rx", and filler.
    while (i < tokens.length) {
      final t = tokens[i];
      final numbering =
          RegExp(r'^\d{1,2}$').hasMatch(t) &&
          i + 1 < tokens.length &&
          (forms.contains(tokens[i + 1]) || _isNameWord(tokens[i + 1]));
      if (numbering || t == 'rx' || _lead.contains(t)) {
        i++;
      } else {
        break;
      }
    }
    if (i < tokens.length && forms.contains(tokens[i])) {
      form = tokens[i];
      i++;
    }

    final nameWords = <String>[];
    while (i < tokens.length && _isNameWord(tokens[i])) {
      if (nameWords.isEmpty && stopwords.contains(tokens[i])) break;
      nameWords.add(tokens[i]);
      i++;
    }
    if (nameWords.isEmpty) {
      return (name: null, strength: null, form: form, rest: tokens.join(' '));
    }

    String? strength;
    if (i < tokens.length && _strengthRe.hasMatch(tokens[i])) {
      final t = tokens[i];
      final next = i + 1 < tokens.length ? tokens[i + 1] : '';
      final singleDigit = RegExp(r'^\d$').hasMatch(t);
      // Said aloud, "Crocin 2 tab" is two tablets. Printed, "AMLONG 5 TAB" is
      // always a strength — reading it as a count once dropped the medicine
      // from the bill altogether, because the line was left with no strength
      // and no dosage form to show it was a medicine at all.
      final isCount =
          !printed &&
          singleDigit &&
          (forms.contains(next) || _doContext.contains(next));
      if (!isCount) {
        strength = t;
        i++;
      } else if (forms.contains(next)) {
        // Still a dosage form, still evidence; the count stays for the sig.
        form = next;
      }
    }
    final variant = <String>[];
    // "OD" is never a variant here: as a frequency it is far more common.
    while (i < tokens.length && variants.contains(tokens[i])) {
      variant.add(tokens[i]);
      i++;
    }
    if (i < tokens.length && forms.contains(tokens[i])) {
      form ??= tokens[i];
      i++;
    }

    final name = [
      ...nameWords,
      ?strength?.replaceAll(RegExp(r'(mg|mcg|ml|gm|g|iu|%)$'), ''),
      ...variant,
    ].join(' ').toUpperCase();
    return (
      name: name,
      strength: strength,
      form: form,
      rest: tokens.sublist(i).join(' '),
    );
  }

  static const _lead = {
    'take',
    'lena',
    'lein',
    'lijiye',
    'le',
    'lo',
    'doctor',
    'ne',
    'kaha',
    'bola',
    'said',
    'the',
    'aur',
    'and',
    'then',
    'phir',
    'fir',
    'also',
    'bhi',
    'please',
    'ji',
    'sir',
    'medicine',
    'dawai',
    'dawa',
    'ek',
    'a',
    'give',
    'dijiye',
    'diya',
    'next',
    'with',
    'uske',
    'baad',
    'saath',
  };

  static bool _isNameWord(String t) {
    if (!RegExp(r'^[a-z][a-z0-9\-+/]*$').hasMatch(t)) return false;
    if (t.length < 2) return false;
    if (RegExp(r'^[ap]/c$').hasMatch(t)) return false;
    return !_sigVocabulary.contains(t) &&
        !_ignorable.contains(t) &&
        !forms.contains(t);
  }

  // ── Purpose ─────────────────────────────────────────────────────────────

  static ({String? purpose, String rest}) _purpose(String s) {
    // Durations first, so "for 10 days" is never a purpose.
    final guarded = s.replaceAllMapped(
      RegExp(r'\bfor\s+(?=\d|a\s+(?:week|month)|one\s+(?:week|month))'),
      (m) => '§for ',
    );
    String? purpose;
    var rest = guarded;
    // A purpose takes only its own words. It once swallowed the word before
    // "ke liye", and "after food BP ke liye" lost its "after food".
    final forHit = RegExp(r'(?<!§)\bfor\s+([a-z]+)(?:\s+([a-z]+))?\b')
        .firstMatch(rest);
    final keLiye = RegExp(r'\b([a-z]+)\s+(?:ke|ki)\s+liye\b').firstMatch(rest);
    if (forHit != null && !_timingWord(forHit[1]!)) {
      final second = forHit[2];
      // "for blood pressure" keeps both words; "for sugar subah" keeps
      // "sugar" and leaves "subah" for the timing.
      final two =
          second != null &&
          !_timingWord(second) &&
          !_ignorable.contains(second);
      purpose = _purposeText(two ? '${forHit[1]} $second' : forHit[1]!);
      final end = two
          ? forHit.end
          : forHit.start + forHit[0]!.indexOf(forHit[1]!) + forHit[1]!.length;
      rest = rest.replaceRange(forHit.start, end, ' ');
    } else if (keLiye != null && !_timingWord(keLiye[1]!)) {
      // "bp ke liye" → BP; "sugar ke liye" → Sugar.
      purpose = _purposeText(keLiye[1]!);
      rest = rest.replaceRange(keLiye.start, keLiye.end, ' ');
    }
    return (purpose: purpose, rest: rest.replaceAll('§', ''));
  }

  static bool _timingWord(String w) =>
      w.split(' ').any((t) => _sigVocabulary.contains(t)) ||
      RegExp(r'^(days?|weeks?|months?)$').hasMatch(w);

  static String _purposeText(String w) {
    final t = w.trim();
    if (t.length <= 4 && !t.contains(' ')) return t.toUpperCase();
    return t[0].toUpperCase() + t.substring(1);
  }

  // ── The instruction ─────────────────────────────────────────────────────

  static const _sigVocabulary = {
    'od',
    'qd',
    'bd',
    'bid',
    'tds',
    'tid',
    'qid',
    'qds',
    'hs',
    'nocte',
    'sos',
    'prn',
    'stat',
    'ac',
    'pc',
    'daily',
    'morning',
    'afternoon',
    'evening',
    'night',
    'noon',
    'bedtime',
    'subah',
    'savere',
    'sawere',
    'dopahar',
    'dopehar',
    'shaam',
    'sham',
    'raat',
    'nashte',
    'nashta',
    'breakfast',
    'lunch',
    'dinner',
    'khane',
    'khana',
    'baad',
    'pehle',
    'pahle',
    'before',
    'after',
    'food',
    'meal',
    'meals',
    'empty',
    'stomach',
    'khali',
    'pet',
    'alternate',
    'alt',
    'days',
    'day',
    'din',
    'week',
    'weeks',
    'month',
    'months',
    'mahina',
    'mahine',
    'hafta',
    'hafte',
    'x',
    'once',
    'twice',
    'thrice',
    'times',
    'baar',
    'weekly',
    'needed',
    'required',
    'sote',
    'samay',
    'sone',
    'jarurat',
    'zarurat',
    'zaroorat',
  };

  /// Connectors and filler that carry no instruction. Leaving "aur" out of
  /// this list once flagged every clean "subah aur raat" row for a check.
  static const _ignorable = {
    'aur',
    'and',
    'ke',
    'ki',
    'ka',
    'se',
    'me',
    'mein',
    'mai',
    'ko',
    'ne',
    'the',
    'a',
    'an',
    'to',
    'of',
    'in',
    'on',
    'at',
    'with',
    'take',
    'lena',
    'lein',
    'le',
    'lo',
    'lijiye',
    'khaye',
    'khaiye',
    'khani',
    'khaani',
    'goli',
    'golii',
    'tikiya',
    'tablet',
    'tablets',
    'tab',
    'tabs',
    'cap',
    'caps',
    'capsule',
    'capsules',
    'dose',
    'doses',
    'roz',
    'rozana',
    'roj',
    'har',
    'every',
    'per',
    'dawai',
    'dawa',
    'medicine',
    'then',
    'phir',
    'fir',
    'also',
    'bhi',
    'hai',
    'hain',
    'h',
    'chalu',
    'rakhiye',
    'rakhna',
    'rakhe',
    'continue',
    'jaari',
    'same',
    'as',
    'is',
    'it',
    'this',
    'yeh',
    'ye',
    'wo',
    'woh',
    'please',
    'sir',
    'madam',
    'ji',
    'dijiye',
    'diya',
    'de',
    'di',
    'do',
    'kaha',
    'bola',
    'said',
    'doctor',
    'one',
    'spoon',
    'spoons',
    'chammach',
    'ml',
    'hi',
    'ho',
    'tak',
    'till',
    'until',
    'upto',
    'for',
    'time',
    'ek',
    'wala',
    'wali',
    'waali',
    'uske',
    'saath',
    'or',
    'if',
    'when',
    'jab',
    'par',
    'padne',
    'hone',
    'you',
    'your',
    'apni',
    'apna',
    'should',
    'must',
    'can',
    'will',
    'need',
    'nos',
    'no',
    'n',
    'strip',
    'strips',
    'daily',
    // "Only" narrows; it never changes the time that follows it.
    'sirf',
    'only',
    'just',
  };

  static final _phrases = <(RegExp, void Function(_SigBuilder, Match))>[
    // Interval — before duration, or "every 3 days" reads as a 3-day course.
    (
      RegExp(
        r'\b(?:alternate|alt)\s+days?\b|\bevery\s+other\s+day\b'
        r'|\b(?:1\s+)?din\s+chhod\s*(?:ke|kar|kr)?\b',
      ),
      (b, m) => b.every = 2,
    ),
    (
      RegExp(r'\b(?:every|har)\s+(\d+)(?:st|nd|rd|th)?\s+(?:days?|din)\b'),
      (b, m) => b.every = int.parse(m[1]!),
    ),
    (
      RegExp(
        r'\bweekly\b|\bonce\s+a\s+week\b|\bhafte\s+(?:me|mein)\s+1\s+baar\b',
      ),
      (b, m) => b.every = 7,
    ),
    // Duration.
    (
      RegExp(r'(?:\bx|\bfor|×)?\s*\b(\d+)\s+(?:days?|din|d)\b'),
      (b, m) => b.duration = int.parse(m[1]!),
    ),
    (
      RegExp(r'(?:\bx|\bfor)?\s*\b(\d+)\s+(?:weeks?|wks?|hafte|hafta)\b'),
      (b, m) => b.duration = int.parse(m[1]!) * 7,
    ),
    (
      RegExp(r'(?:\bx|\bfor)?\s*\b(\d+)\s+(?:months?|mahine|mahina)\b'),
      (b, m) => b.duration = int.parse(m[1]!) * 30,
    ),
    (
      RegExp(r'\b(?:for\s+)?(?:a|one|1|ek)\s+(?:week|hafta|hafte)\b'),
      (b, m) => b.duration = 7,
    ),
    (
      RegExp(r'\b(?:for\s+)?(?:a|one|1|ek)\s+(?:month|mahina|mahine)\b'),
      (b, m) => b.duration = 30,
    ),
    // As needed, and now.
    (
      RegExp(
        r'\bsos\b|\bprn\b|\bas\s+(?:needed|required)\b|\b(?:when|if)\s+needed\b'
        r'|\b(?:jarurat|zarurat|zaroorat)\s+(?:padne\s+)?par\b'
        r'|\bdard\s+hone\s+par\b',
      ),
      (b, m) => b.sos = true,
    ),
    (
      RegExp(r'\bstat\b|\bimmediately\b|\babhi\s+turant\b'),
      (b, m) => b.stat = true,
    ),
    // Positional: 1-0-1, 1-1-1, 0-0-1, 1-0-0-1.
    (
      RegExp(
        r'(?<![\d.])(\d|0\.5)-(\d|0\.5)-(\d|0\.5)(?:-(\d|0\.5))?(?![\d.])',
      ),
      (b, m) => b.positional([m[1]!, m[2]!, m[3]!, ?m[4]]),
    ),
    // Food. Checked before slot words: "before breakfast" is both.
    (
      RegExp(
        r'\ba/c\b|\bac\b|\bbefore\s+(?:food|meals?)\b|\bempty\s+stomach\b'
        r'|\bkhali\s+pet\b|\b(?:khana\s+)?khane\s+se\s+(?:pehle|pahle)\b',
      ),
      (b, m) => b.food = FoodTiming.before,
    ),
    (
      RegExp(r'\bbefore\s+breakfast\b|\bnashte\s+se\s+(?:pehle|pahle)\b'),
      (b, m) => b
        ..food = FoodTiming.before
        ..addSlot(DoseSlot.morning),
    ),
    (
      RegExp(r'\bbefore\s+(?:dinner|bed)\b'),
      (b, m) => b
        ..food = FoodTiming.before
        ..addSlot(DoseSlot.night),
    ),
    (
      RegExp(
        r'\bp/c\b|\bpc\b|\bafter\s+(?:food|meals?)\b|\bwith\s+(?:food|meals?)\b'
        r'|\b(?:khana\s+)?khane\s+ke\s+(?:baad|bad|saath)\b',
      ),
      (b, m) => b.food = FoodTiming.after,
    ),
    (
      RegExp(r'\bafter\s+breakfast\b|\bnashte\s+ke\s+(?:baad|bad)\b'),
      (b, m) => b
        ..food = FoodTiming.after
        ..addSlot(DoseSlot.morning),
    ),
    (
      RegExp(r'\bafter\s+lunch\b'),
      (b, m) => b
        ..food = FoodTiming.after
        ..addSlot(DoseSlot.afternoon),
    ),
    (
      RegExp(r'\bafter\s+dinner\b'),
      (b, m) => b
        ..food = FoodTiming.after
        ..addSlot(DoseSlot.night),
    ),
    // Frequency.
    (
      RegExp(
        r'\bqid\b|\bqds\b|\b(?:four|4)\s+times\s+(?:a|per)\s+day\b'
        r'|\b(?:char|4)\s+baar\b',
      ),
      (b, m) => b.frequency(const [
        DoseSlot.morning,
        DoseSlot.afternoon,
        DoseSlot.evening,
        DoseSlot.night,
      ]),
    ),
    (
      RegExp(
        r'\btds\b|\btid\b|\bthrice\s+(?:daily|a\s+day)\b'
        r'|\b(?:three|3)\s+times\s+(?:a|per)\s+day\b'
        r'|\b(?:din\s+(?:me|mein)\s+)?(?:teen|3)\s+baar\b',
      ),
      (b, m) => b.frequency(const [
        DoseSlot.morning,
        DoseSlot.afternoon,
        DoseSlot.night,
      ]),
    ),
    (
      RegExp(
        r'\bbd\b|\bbid\b|\btwice\s+(?:daily|a\s+day)\b'
        r'|\b(?:two|2)\s+times\s+(?:a|per)\s+day\b'
        r'|\b(?:din\s+(?:me|mein)\s+)?2\s+baar\b',
      ),
      (b, m) => b.frequency(const [DoseSlot.morning, DoseSlot.night]),
    ),
    (
      RegExp(
        r'\bod\b|\bqd\b|\bonce\s+(?:daily|a\s+day)\b|\bdaily\s+once\b'
        r'|\b(?:din\s+(?:me|mein)\s+)?1\s+baar\b',
      ),
      (b, m) => b.frequency(const [DoseSlot.morning]),
    ),
    // Slot words.
    (
      RegExp(
        r'\bhs\b|\bnocte\b|\b(?:at\s+)?bedtime\b|\bsote\s+samay\b'
        r'|\bsone\s+se\s+(?:pehle|pahle)\b|\b(?:at|in\s+the)\s+night\b'
        r'|\bnight\b|\braat\b|\bdinner\b',
      ),
      (b, m) => b.addSlot(DoseSlot.night),
    ),
    (
      RegExp(
        r'\b(?:in\s+the\s+)?morning\b|\bsubah\b|\bsa[vw]ere\b|\bbreakfast\b|\bnashte\b',
      ),
      (b, m) => b.addSlot(DoseSlot.morning),
    ),
    (
      RegExp(
        r'\b(?:in\s+the\s+)?afternoon\b|\bnoon\b|\bdop[ae]har\b|\blunch\b',
      ),
      (b, m) => b.addSlot(DoseSlot.afternoon),
    ),
    (
      RegExp(r'\b(?:in\s+the\s+)?evening\b|\bsh?aam\b|\bsham\b'),
      (b, m) => b.addSlot(DoseSlot.evening),
    ),
    // Pack quantities on bills and strips: "30 nos", "1x10", "10's". Taken
    // out of the instruction exactly as before, and kept as a count of what
    // was sold where the count is unambiguous: "10's" is a strip size, and
    // "12 strips" says nothing about how many tablets are in one.
    (
      RegExp(
        r"\b(\d{2,})\s*(nos?|n|tabs?|tablets?|caps?|capsules?|strips?|s)\b"
        r"|\b(\d+)\s*x\s*(\d{2,})\b|\b\d+'s\b",
      ),
      (b, m) {
        if (m[1] != null && !const {'strip', 'strips', 's'}.contains(m[2])) {
          b.pack ??= int.parse(m[1]!);
        } else if (m[3] != null) {
          b.pack ??= int.parse(m[3]!) * int.parse(m[4]!);
        }
      },
    ),
  ];

  static ({Sig sig, int? pack}) _parseSig(String text) {
    final b = _SigBuilder();
    var s = ' $text ';
    for (final (re, apply) in _phrases) {
      s = s.replaceAllMapped(re, (m) {
        apply(b, m);
        return ' ';
      });
    }

    for (final t in s.split(' ').where((t) => t.isNotEmpty)) {
      final n = double.tryParse(t);
      if (n != null) {
        // Only a single digit, or a half, can be a count of tablets. A
        // "TELMA 40 TAB" once became forty tablets a dose.
        if (n > 0 && n < 10) {
          b.units ??= n;
        } else {
          b.unresolved.add(t);
        }
        continue;
      }
      if (_ignorable.contains(t) || _sigVocabulary.contains(t)) continue;
      if (forms.contains(t)) continue;
      b.unresolved.add(t);
    }
    return (sig: b.build(), pack: b.pack);
  }
}

class _SigBuilder {
  final _slots = <DoseSlot>{};
  bool _positional = false;
  FoodTiming food = FoodTiming.unspecified;
  int? every;
  bool sos = false;
  bool stat = false;
  int? duration;
  double? units;
  int? pack;
  final unresolved = <String>[];

  void addSlot(DoseSlot s) => _slots.add(s);

  /// A named frequency only sets the slots if nothing more specific did.
  void frequency(List<DoseSlot> slots) {
    if (_positional) return;
    if (_slots.isEmpty) _slots.addAll(slots);
  }

  void positional(List<String> parts) {
    const three = [DoseSlot.morning, DoseSlot.afternoon, DoseSlot.night];
    const four = DoseSlot.values;
    final order = parts.length == 4 ? four : three;
    _positional = true;
    _slots.clear();
    final amounts = <double>{};
    for (var i = 0; i < parts.length; i++) {
      final v = double.parse(parts[i]);
      if (v > 0) {
        _slots.add(order[i]);
        amounts.add(v);
      }
    }
    if (amounts.length == 1) {
      units = amounts.first;
    } else if (amounts.length > 1) {
      // 1-0-2: a different amount at night. One number cannot carry that,
      // so a person decides.
      units = amounts.first;
      unresolved.add(parts.join('-'));
    }
  }

  Sig build() {
    final ordered = [
      for (final s in DoseSlot.values)
        if (_slots.contains(s)) s,
    ];
    return Sig(
      slots: sos ? const [] : ordered,
      food: food,
      everyNDays: every,
      sos: sos,
      stat: stat,
      durationDays: duration,
      unitsPerDose: units ?? 1,
      unresolved: List.unmodifiable(unresolved),
    );
  }
}
