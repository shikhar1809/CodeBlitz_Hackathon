import 'content_gate.dart';
import 'mention.dart';
import 'sig.dart';
import 'sig_parser.dart';

/// A line on a photo that looks like a medicine but gave none — a smudged
/// name beside a clear `TAB` and `1-0-1`.
class UnreadLine {
  const UnreadLine(this.source, this.text, this.signals);

  final SourceKind source;

  /// The line exactly as it was read.
  final String text;

  /// Why it looks medical — the words the content gate recognised.
  final List<String> signals;
}

/// Mentions of medicines, plus the advice that is not about a medicine.
class Extraction {
  const Extraction(this.mentions, this.notes, [this.unreadable = const []]);

  final List<Mention> mentions;

  /// "Come back after ten days for review". Shown to a person, never turned
  /// into a dose.
  final List<String> notes;

  /// Photo lines that look medical but could not be turned into a medicine.
  /// Never dropped quietly: a person is asked what each one is.
  final List<UnreadLine> unreadable;
}

/// Turns one source's text into mentions of medicines.
///
/// Photos arrive as OCR lines; speech arrives as one run-on sentence. Both are
/// cut into segments, and each segment is either a new medicine (it has a
/// name that looks like one), more instruction for the medicine before it — a
/// handwritten prescription usually puts "1-0-1 x 5 days" on the next line —
/// or, when it opens with an advice word, a note.
abstract final class MentionExtractor {
  static List<Mention> extract(String text, SourceKind source) =>
      extractWithNotes(text, source).mentions;

  /// Words that open advice rather than a medicine. A sentence starting with
  /// one is a note, and is never attached to the medicine above it: "come
  /// back after ten days" must not become a ten-day course.
  static const adviceWords = {
    'come',
    'review',
    'follow',
    'visit',
    'check',
    'test',
    'tests',
    'get',
    'avoid',
    'walk',
    'drink',
    'eat',
    'exercise',
    'sleep',
    'rest',
    'reduce',
    'stop',
    'dobara',
    'wapas',
    'aaiye',
    'aana',
    'milna',
    'miliye',
    'jaanch',
    'karwa',
    'karwaiye',
    'parhez',
    'mat',
    'bachein',
    'bachiye',
    'kam',
    'paani',
    'pani',
    'namak',
    'cheeni',
    'report',
    'x-ray',
    'xray',
    'blood',
  };

  static Extraction extractWithNotes(String text, SourceKind source) {
    final speech = _isSpeech(source);
    final segments = _segments(text, speech: speech);
    final mentions = <Mention>[];
    final notes = <String>[];
    final unreadable = <UnreadLine>[];
    Mention? current;

    for (final seg in segments) {
      final first = SigParser.normalise(seg).split(' ').first;
      if (adviceWords.contains(first)) {
        if (speech) notes.add(seg.trim());
        continue;
      }

      final line = SigParser.parseLine(seg, printed: _isPrinted(source));
      if (line.name != null) {
        final evidence = _hasEvidence(line);
        if (evidence || speech) {
          if (current != null) mentions.add(current);
          current = Mention(
            source: source,
            name: line.name!,
            strength: line.strength,
            sig: line.sig,
            raw: seg.trim(),
            purpose: line.purpose,
            needsCorroboration: !evidence,
            packQuantity: line.packQuantity,
          );
          continue;
        }
      }

      // A line that opens with a dosage form but has no readable name is a
      // new medicine nobody could read — "Tab ~~~~ 0-0-1". Its "0-0-1" is not
      // more instruction for the medicine above, and neither is what follows.
      final signals = speech
          ? const <String>[]
          : ContentGate.strongSignals(seg);
      if (line.name == null && line.form != null && signals.isNotEmpty) {
        if (current != null) mentions.add(current);
        current = null;
        unreadable.add(UnreadLine(source, seg.trim(), signals));
        continue;
      }

      // No name: instruction for the medicine above, if it carries any.
      final sig = SigParser.parseSig(seg);
      final carries =
          sig.hasTiming ||
          sig.food != FoodTiming.unspecified ||
          sig.durationDays != null ||
          sig.everyNDays != null;
      if (current != null && (carries || line.purpose != null)) {
        current = current.copyWith(
          sig: current.sig.fillFrom(sig),
          raw: '${current.raw}  ${seg.trim()}',
          purpose: current.purpose ?? line.purpose,
          // "Telma, subah ek": the instruction that follows is the evidence.
          needsCorroboration: current.needsCorroboration && !carries,
          packQuantity: current.packQuantity ?? line.packQuantity,
        );
      } else if (speech && seg.trim().split(' ').length > 2) {
        notes.add(seg.trim());
      } else if (signals.isNotEmpty) {
        // Looks medical, belongs to nothing: asked about, never dropped.
        unreadable.add(UnreadLine(source, seg.trim(), signals));
      }
    }
    if (current != null) mentions.add(current);
    return Extraction(mentions, notes, unreadable);
  }

  static bool _isPrinted(SourceKind s) =>
      s == SourceKind.bill || s == SourceKind.strip;

  static bool _isSpeech(SourceKind s) =>
      s == SourceKind.doctor || s == SourceKind.chemist;

  /// Photos: one segment per line. Speech: also split at pauses and at "and
  /// then", because a dictated visit is one long sentence.
  static List<String> _segments(String text, {required bool speech}) {
    var lines = text.split(RegExp(r'[\r\n]+'));
    if (speech) {
      lines = [
        for (final l in lines)
          ...l.split(
            RegExp(
              r'[.;।]|,(?!\s*\d)'
              r'|\b(?:and then|aur phir|aur fir|then|phir|uske baad)\b',
              caseSensitive: false,
            ),
          ),
      ];
    }
    return [
      for (final l in lines)
        if (l.trim().isNotEmpty) l.trim(),
    ];
  }

  /// A name alone is not enough: "Dr Sharma" and "Patient Ramesh" have names.
  /// A medicine line has a dosage form, a strength, or an instruction — and a
  /// duration alone is not an instruction.
  static bool _hasEvidence(ParsedLine line) =>
      line.form != null ||
      line.strength != null ||
      line.sig.hasTiming ||
      line.sig.food != FoodTiming.unspecified;
}
