import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/geo.dart';

/// Winger's Firebase backend (Cloud Function `api`). Gives guardians a live
/// tracking link and powers the dead-man switch: if heartbeats stop, the
/// server marks the session dark and tells guardians.
///
/// Optional: every call fails quietly and the app carries on offline.
class CloudService {
  static const base = String.fromEnvironment('WINGER_CLOUD_URL',
      defaultValue: 'https://wingercodeblitz.web.app');
  static const _timeout = Duration(seconds: 8);

  final bool enabled;
  CloudService({bool? enabled}) : enabled = enabled ?? base.isNotEmpty;

  String? id;
  String? _key;
  String? trackUrl;

  bool get live => id != null;

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    if (!enabled) return null;
    try {
      final r = await http
          .post(Uri.parse('$base/api$path'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(_timeout);
      if (r.statusCode != 200) return null;
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Opens a cloud session. Returns the guardian tracking link, or null.
  Future<String?> start({required String name, required String kind, required List<String> guardians}) async {
    final r = await _post('/session/start', {'name': name, 'kind': kind, 'guardians': guardians});
    if (r == null) return null;
    id = r['id'] as String?;
    _key = r['key'] as String?;
    trackUrl = r['trackUrl'] as String?;
    return trackUrl;
  }

  Future<bool> beat({LatLon? at, required String status, String? note}) async {
    if (!live) return false;
    final r = await _post('/session/beat', {
      'id': id,
      'key': _key,
      'lat': ?at?.lat,
      'lon': ?at?.lon,
      'status': status,
      'note': ?note,
    });
    return r != null;
  }

  Future<void> end(String reason) async {
    if (!live) return;
    await _post('/session/end', {'id': id, 'key': _key, 'reason': reason});
    id = null;
    _key = null;
    trackUrl = null;
  }
}
