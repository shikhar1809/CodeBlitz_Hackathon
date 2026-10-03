import 'mention.dart';
import 'mention_extractor.dart';
import 'merge_engine.dart';
import 'name_matcher.dart';

/// One source of text for the analyser.
class SourceText {
  const SourceText(this.source, this.text);

  final SourceKind source;
  final String text;
}

/// What the on-device pass did, step by step. Shown on the processing screen
/// so the user sees work happen rather than a spinner.
class AnalysisResult {
  const AnalysisResult({
    required this.rows,
    required this.mentions,
    required this.sourcesRead,
    required this.dropped,
    this.unreadable = const [],
  });

  final List<MergedMedicine> rows;
  final List<Mention> mentions;

  /// Which sources had any text at all.
  final Set<SourceKind> sourcesRead;

  /// Spoken names nothing else backed up — "namaste" is not a medicine.
  final List<Mention> dropped;

  /// Photo lines that look like a medicine but gave none. A person is asked.
  final List<UnreadLine> unreadable;

  int count(Verdict v) => rows.where((r) => r.verdict == v).length;
}

/// The whole on-device pipeline: text from each source, to mentions, to
/// cross-checked rows. No network, no key, no model.
abstract final class OfflineAnalyser {
  static AnalysisResult analyse(
    Iterable<SourceText> texts, {
    Iterable<Mention> extra = const [],
  }) {
    final mentions = <Mention>[];
    final unreadable = <UnreadLine>[];
    final read = <SourceKind>{};
    for (final t in texts) {
      if (t.text.trim().isEmpty) continue;
      read.add(t.source);
      final x = MentionExtractor.extractWithNotes(t.text, t.source);
      mentions.addAll(x.mentions);
      unreadable.addAll(x.unreadable);
    }
    mentions.addAll(extra);

    // A bare spoken name is kept only when another source names it too.
    final dropped = <Mention>[];
    final kept = <Mention>[];
    for (final m in mentions) {
      if (!m.needsCorroboration) {
        kept.add(m);
        continue;
      }
      final backed = mentions.any(
        (o) =>
            o.source != m.source &&
            !o.needsCorroboration &&
            NameMatcher.same(o.name, m.name),
      );
      (backed ? kept : dropped).add(m);
    }

    return AnalysisResult(
      rows: MergeEngine.merge(kept),
      mentions: kept,
      sourcesRead: read,
      dropped: dropped,
      unreadable: unreadable,
    );
  }
}
