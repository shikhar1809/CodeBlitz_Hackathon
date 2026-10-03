/// Matching of heard words against her safe phrases and cries for help.
library;

const cryForHelpPhrases = [
  'help me',
  'somebody help',
  'someone help',
  'leave me alone',
  'let me go',
  'bachao',
  'chhodo',
  'chodo',
  'please stop',
];

List<String> words(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// True when every word of [phrase] appears in [heard] in order, allowing
/// one missed word for phrases of four words or more.
bool containsPhrase(String heard, String phrase) {
  final h = words(heard), p = words(phrase);
  if (p.isEmpty) return false;
  var i = 0, missed = 0;
  for (final w in p) {
    final at = h.indexOf(w, i);
    if (at < 0) {
      missed++;
      continue;
    }
    i = at + 1;
  }
  return missed == 0 || (p.length >= 4 && missed == 1);
}

/// The first safe phrase heard in [heard], or null.
String? matchPhrase(String heard, List<String> phrases) {
  for (final p in phrases) {
    if (containsPhrase(heard, p)) return p;
  }
  return null;
}

bool isCryForHelp(String heard) =>
    cryForHelpPhrases.any((p) => containsPhrase(heard, p));

/// Rules for a new safe phrase: English, three words or more.
String? phraseProblem(String phrase, List<String> existing) {
  final w = words(phrase);
  if (RegExp(r'[^\x00-\x7F]').hasMatch(phrase)) return 'Use English words.';
  if (w.length < 3) return 'Use at least three words.';
  if (existing.length >= 5) return 'Up to five phrases.';
  if (existing.any((e) => words(e).join(' ') == w.join(' '))) {
    return 'You already have this phrase.';
  }
  if (isCryForHelp(phrase)) return 'Pick something that sounds ordinary.';
  return null;
}
