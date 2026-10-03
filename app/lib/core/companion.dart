/// Offline call script: what "Riya" says when the live agent is unreachable.
///
/// Turn-taking is driven by a loudness meter: she speaks, then goes quiet,
/// then Riya answers with the next line. Two silent turns in a row raise a
/// check-in. After the script runs out Riya says "still here" every 15 s.
class CompanionScript {
  static const hello = 'Hey! Finally you called. Where are you right now?';
  static const lines = [
    'Okay, okay. Are you walking or in an auto?',
    'Haha, I knew it. Is it busy around there?',
    'Keep me on the line till you reach, alright?',
    'Mom was asking about you today, by the way.',
    'How far are you now? Five minutes? Ten?',
    'Tell me something nice that happened today.',
  ];
  static const stillHere = [
    "I'm still here, take your time.",
    'Still with you. Just keep walking.',
    "Hmm, I'm here, tell me when you reach.",
  ];
  static const routeCues = {
    'offRoute': 'Wait, that does not sound like your usual way. All okay?',
    'stopped': 'You went quiet and stopped. Everything fine?',
    'late': 'You are taking longer than usual. Should I worry?',
  };

  static const stillHereEvery = Duration(seconds: 15);

  int _next = 0;
  int _silentTurns = 0;
  int _still = 0;
  DateTime? _lastSpoke;

  /// Line to say right now, or null to keep listening.
  ///
  /// [herTurnEnded] is true when she spoke and then fell quiet.
  /// [heardHer] is false when the whole turn passed in silence.
  String? next(DateTime now, {bool herTurnEnded = false, bool heardHer = true}) {
    if (_lastSpoke == null) {
      _lastSpoke = now;
      return hello;
    }
    if (herTurnEnded) {
      _silentTurns = heardHer ? 0 : _silentTurns + 1;
      if (_next < lines.length) {
        _lastSpoke = now;
        return lines[_next++];
      }
    }
    if (now.difference(_lastSpoke!) >= stillHereEvery) {
      _lastSpoke = now;
      return stillHere[_still++ % stillHere.length];
    }
    return null;
  }

  /// Two silent turns in a row: Winger should ask if she is okay.
  bool get wantsCheckIn => _silentTurns >= 2;
}

/// Turns raw loudness samples into speech turns.
class LoudnessMeter {
  final double speechLevel;
  final Duration endOfTurn;
  DateTime? _lastLoud;
  bool _speaking = false;

  LoudnessMeter({
    this.speechLevel = 0.08,
    this.endOfTurn = const Duration(milliseconds: 900),
  });

  /// Feed a level 0..1; returns true once when her turn has just ended.
  bool feed(double level, DateTime now) {
    if (level >= speechLevel) {
      _speaking = true;
      _lastLoud = now;
      return false;
    }
    if (_speaking && now.difference(_lastLoud!) >= endOfTurn) {
      _speaking = false;
      return true;
    }
    return false;
  }

  bool get speaking => _speaking;
}
