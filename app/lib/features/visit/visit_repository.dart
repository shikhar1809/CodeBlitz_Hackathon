import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'visit.dart';

/// The in-progress visit, kept on the device between every capture.
class VisitRepository {
  VisitRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _draft = 'visit_draft';

  static Future<VisitRepository> load() async =>
      VisitRepository(await SharedPreferences.getInstance());

  Visit? loadDraft() {
    final raw = _prefs.getString(_draft);
    if (raw == null) return null;
    try {
      return Visit.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      // A draft from an older build that no longer parses is not worth a
      // crash on launch. Start a fresh one.
      return null;
    }
  }

  Future<void> save(Visit visit) =>
      _prefs.setString(_draft, jsonEncode(visit.toJson()));

  Future<void> clear() => _prefs.remove(_draft);
}
