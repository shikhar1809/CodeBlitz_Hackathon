import 'dart:math';

enum Verdict { calm, ask, alert, silentAlert }

/// Turns heard sounds and phrases into a fading risk score.
///
/// Evidence adds to the score, which halves every [halfLife]. A score of
/// [askAt] or more asks "Are you okay?"; [alertAt] or more alerts guardians.
/// Her safe phrase is a silent alert at once.
class ThreatJudge {
  static const soundWeights = <String, double>{
    'Screaming': 1.0,
    'Gunshot, gunfire': 1.0,
    'Shout': 0.6,
    'Yell': 0.6,
    'Crying, sobbing': 0.5,
    'Slap, smack': 0.5,
    'Glass': 0.4,
    'Shatter': 0.4,
    'Smash, crash': 0.4,
  };

  final Duration halfLife;
  final double askAt;
  final double alertAt;
  double _score = 0;
  DateTime? _at;

  ThreatJudge({
    this.halfLife = const Duration(seconds: 20),
    this.askAt = 0.6,
    this.alertAt = 1.6,
  });

  double score(DateTime now) {
    if (_at == null) return 0;
    final dt = now.difference(_at!).inMilliseconds / halfLife.inMilliseconds;
    return _score * pow(0.5, dt);
  }

  Verdict _add(double w, DateTime now) {
    _score = score(now) + w;
    _at = now;
    if (_score >= alertAt) return Verdict.alert;
    if (_score >= askAt) return Verdict.ask;
    return Verdict.calm;
  }

  /// Context bonus: night +0.25, journey trouble +0.5, call cut +0.25.
  static double context(
          {bool night = false,
          bool journeyTrouble = false,
          bool callCut = false}) =>
      (night ? 0.25 : 0) + (journeyTrouble ? 0.5 : 0) + (callCut ? 0.25 : 0);

  Verdict hearSound(String label, double confidence, DateTime now,
      {double bonus = 0}) {
    final w = soundWeights[label];
    if (w == null || confidence < 0.3) return Verdict.calm;
    return _add(w * confidence + bonus, now);
  }

  Verdict hearCryForHelp(DateTime now, {double bonus = 0}) =>
      _add(1.0 + bonus, now);

  Verdict hearSafePhrase() => Verdict.silentAlert;

  void reset() {
    _score = 0;
    _at = null;
  }
}
