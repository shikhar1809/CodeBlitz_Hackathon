import 'dart:convert';

class Helpline {
  final String name;
  final String number;
  const Helpline(this.name, this.number);
}

class Guide {
  final String id;
  final String title;
  final List<String> keywords;
  final List<String> steps;
  final List<Helpline> helplines;
  const Guide(this.id, this.title, this.keywords, this.steps, this.helplines);

  factory Guide.fromJson(Map<String, dynamic> j) => Guide(
        j['id'] as String,
        j['title'] as String,
        (j['keywords'] as List).cast<String>(),
        (j['steps'] as List).cast<String>(),
        [
          for (final h in j['helplines'] as List)
            Helpline(h['name'] as String, h['number'] as String)
        ],
      );
}

/// Matches a message to the best step-by-step guide, entirely on the phone.
class HelpGuide {
  final List<Guide> guides;
  HelpGuide(this.guides);

  factory HelpGuide.parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    return HelpGuide([
      for (final g in j['guides'] as List) Guide.fromJson(g as Map<String, dynamic>)
    ]);
  }

  static final _urgent = RegExp(
      r'\b(right now|now|currently|happening|following me|outside my|help me|emergency|hurt|bleeding)\b');

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s']"), ' ');

  /// True for "right now"-type messages, which should lead with "call 112".
  static bool isUrgent(String message) => _urgent.hasMatch(_norm(message));

  /// True when the message is mostly ASCII (treated as English).
  static bool isEnglish(String message) {
    final letters = message.runes.where((r) => r > 64).length;
    if (letters == 0) return true;
    final ascii = message.runes.where((r) => r > 64 && r < 128).length;
    return ascii / letters > 0.9;
  }

  Guide? match(String message) {
    final text = ' ${_norm(message)} ';
    Guide? best;
    var bestScore = 0;
    for (final g in guides) {
      var score = 0;
      for (final k in g.keywords) {
        if (text.contains(' ${k.toLowerCase()}')) score += k.contains(' ') ? 3 : 2;
      }
      if (score > bestScore) {
        bestScore = score;
        best = g;
      }
    }
    return bestScore >= 2 ? best : null;
  }
}
