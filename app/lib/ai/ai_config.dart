import 'dart:async';

import 'package:http/http.dart' as http;

/// Keys and switches for the one cloud call.
///
/// The key arrives by `--dart-define` (tools/run.ps1 reads it from the
/// gitignored keys.local.ps1). Such a key is still embedded in the APK and can
/// be pulled out of it: it is a key to rotate after the event. The real fix —
/// proxying through Firebase AI Logic with App Check — is not hackathon work.
abstract final class AiConfig {
  static const geminiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasGeminiKey => geminiKey.isNotEmpty;

  /// Reads handwriting on the prescription photo.
  static const handwritingModel = 'gemini-3.8-flash';

  /// Reads loose speech. Kept for when dictation is not enough.
  static const audioModel = 'gemini-3.5-flash-lite';

  /// A hard cap per visit, so a loop cannot run up a bill.
  static const callsPerVisit = 4;

  static const timeout = Duration(seconds: 45);

  static const endpoint = 'https://generativelanguage.googleapis.com';

  /// Whether the Gemini endpoint answers at all, right now. The online card is
  /// only offered when it does: a button that cannot work is worse than none.
  static Future<bool> reachable({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final r = await c
          .head(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 4));
      return r.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }
}
