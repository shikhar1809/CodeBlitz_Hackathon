/// Why an engine did not speak a sentence.
enum SpeechMiss {
  /// Live Kokoro missed its deadline. The fetch carries on in the background
  /// and warms the cache for next time; it is never played late.
  timeout,

  /// Live Kokoro has missed a deadline this session and has not since been
  /// fast, so it was not waited for. The fetch still warms the cache.
  slow,

  /// The Space answered with an error status, or an empty file.
  httpError,

  /// The Space answered, but not with anything that leads to audio.
  malformedResponse,

  /// No network: DNS, connection or socket failure.
  offline,

  /// The Space already failed this session (ADR-32); not asked again.
  unreachable,

  /// Audio arrived but the player could not play it.
  playbackError,

  /// The device has no voice for this language.
  noVoice,

  /// Anything else that went wrong.
  error,

  /// The voice was stopped or claimed by another screen while this sentence
  /// was loading (ADR-15). Nothing further in the chain should speak it.
  superseded,
}

/// What happened when a sentence was handed to an engine.
class SpeakResult {
  const SpeakResult._(this.spokenBy, this.misses);

  const SpeakResult.spoke(
    String engine, [
    Map<String, SpeechMiss> misses = const {},
  ]) : this._(engine, misses);

  SpeakResult.missed(String engine, SpeechMiss miss)
    : this._(null, {engine: miss});

  const SpeakResult.silent(Map<String, SpeechMiss> misses)
    : this._(null, misses);

  /// The engine that spoke, or null when nothing did and the screen's text is
  /// all the user has.
  final String? spokenBy;

  /// Every engine that was tried and did not speak, with why.
  final Map<String, SpeechMiss> misses;

  bool get spoke => spokenBy != null;

  bool get superseded => misses.values.contains(SpeechMiss.superseded);

  @override
  String toString() {
    final why = misses.entries.map((e) => '${e.key}: ${e.value.name}');
    final who = spokenBy ?? 'none (text only)';
    return why.isEmpty ? who : '$who (${why.join(', ')})';
  }
}
