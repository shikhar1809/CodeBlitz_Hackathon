import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'store.dart';

/// Something worth showing on the Hub's activity feed. Never carries a name,
/// a phone number or a location: the Hub's screen is a household screen.
class HubEvent {
  final DateTime at;
  final String text;
  final bool alert;
  const HubEvent(this.at, this.text, {this.alert = false});
}

/// Winger Hub's HTTP server. Speaks the same API as the Firebase backend, so
/// the Winger app works against either one:
///
///   POST /api/session/start  {name, kind, guardians[]}      -> {id, key, trackUrl}
///   POST /api/session/beat   {id, key, lat, lon, status, note?}
///   POST /api/session/end    {id, key, reason}
///   GET  /api/track/:id      the guardian's live view (unguessable id)
///   GET  /t/:id              the guardian's tracking page
///
/// Hub-only:
///   POST /api/pair           {code, name}                    -> {deviceId, token}
///   GET  /api/health         {ok, version, uptime}
///   GET  /                   a page that says what this is and how to connect
class HubServer {
  static const version = '0.1.0';
  static const darkAfter = Duration(minutes: 3);
  static const expireAfter = Duration(hours: 24);
  static const pairingLife = Duration(minutes: 10);
  static const maxTrail = 300;
  static const maxNotes = 50;
  static const maxBody = 64 * 1024;
  static const statuses = {'watching', 'checking', 'alerting', 'silent', 'safe', 'ended'};

  final HubStore store;
  final String trackPage;
  final DateTime Function() _now;
  final void Function(HubEvent)? onEvent;
  final Random _rng;

  HttpServer? _http;
  Timer? _sweeper;
  DateTime? _startedAt;
  String? _pairingCode;
  DateTime? _pairingUntil;

  /// Requests per client address per window, for the endpoints worth abusing.
  final Map<String, List<DateTime>> _hits = {};

  HubServer({
    required this.store,
    required this.trackPage,
    DateTime Function()? now,
    this.onEvent,
    Random? random,
  })  : _now = now ?? DateTime.now,
        _rng = random ?? Random.secure();

  bool get running => _http != null;
  int? get port => _http?.port;
  DateTime? get startedAt => _startedAt;

  int get liveSessions => store.sessions.values.where((s) => s.active).length;
  int get darkSessions => store.sessions.values.where((s) => s.active && s.dark).length;

  Future<void> start({int? port, InternetAddress? address}) async {
    if (running) return;
    _http = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port ?? store.settings.port);
    _startedAt = _now();
    _http!.listen(_handle, onError: (_) {});
    _sweeper = Timer.periodic(const Duration(seconds: 20), (_) => sweep());
    _emit('Hub started on port ${_http!.port}');
  }

  Future<void> stop() async {
    _sweeper?.cancel();
    _sweeper = null;
    await _http?.close(force: true);
    _http = null;
    _startedAt = null;
    await store.flush();
    _emit('Hub stopped');
  }

  // ---- pairing ------------------------------------------------------------

  /// A fresh 6-digit code a phone types (or scans) once to pair.
  String newPairingCode() {
    _pairingCode = List.generate(6, (_) => _rng.nextInt(10)).join();
    _pairingUntil = _now().add(pairingLife);
    return _pairingCode!;
  }

  String? get pairingCode => _pairingValid ? _pairingCode : null;
  DateTime? get pairingUntil => _pairingValid ? _pairingUntil : null;
  bool get _pairingValid => _pairingCode != null && _now().isBefore(_pairingUntil!);

  void revoke(String deviceId) {
    final d = store.devices.remove(deviceId);
    if (d == null) return;
    store.changed();
    _emit('Removed device "${d.name}"');
  }

  // ---- background job -----------------------------------------------------

  /// The dead-man switch and link expiry. Runs every 20 s; public for tests.
  void sweep() {
    final now = _now();
    final ms = now.millisecondsSinceEpoch;
    var changed = false;
    for (final s in store.sessions.values) {
      if (s.active && !s.dark && ms - s.lastBeat > darkAfter.inMilliseconds) {
        s
          ..dark = true
          ..darkAt = ms
          ..status = 'alerting';
        _note(s, ms, 'Phone went dark');
        changed = true;
        _emit('A live session\'s phone stopped checking in. Its guardians see this on their link.', alert: true);
      }
    }
    final before = store.sessions.length;
    store.sessions.removeWhere((_, s) => !s.active && s.endedAt != null && ms - s.endedAt! > expireAfter.inMilliseconds);
    if (store.sessions.length != before) changed = true;
    if (changed) store.changed();
  }

  // ---- HTTP ---------------------------------------------------------------

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    res.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type, Authorization')
      ..set('X-Content-Type-Options', 'nosniff');
    final path = req.uri.path;
    try {
      if (req.method == 'OPTIONS') return _send(res, 204, null);
      if (req.method == 'GET') {
        if (path == '/' || path == '/index.html') return _html(res, _homePage(req));
        if (RegExp(r'^/t/[A-Za-z0-9_-]+/?$').hasMatch(path)) return _html(res, trackPage);
        if (path == '/api/health') {
          return _json(res, 200, {
            'ok': true,
            'hub': 'winger',
            'version': version,
            'uptime': _startedAt == null ? 0 : _now().difference(_startedAt!).inSeconds,
          });
        }
        final m = RegExp(r'^/api/track/([A-Za-z0-9_-]{1,64})$').firstMatch(path);
        if (m != null) return _track(res, m[1]!);
      }
      if (req.method == 'POST') {
        final body = await _body(req);
        if (body == null) return _json(res, 400, {'error': 'bad body'});
        final ip = req.connectionInfo?.remoteAddress.address ?? '?';
        switch (path) {
          case '/api/session/start':
            if (_limited('start:$ip', 30, const Duration(minutes: 1))) return _json(res, 429, {'error': 'slow down'});
            return _startSession(req, res, body);
          case '/api/session/beat':
            return _beat(res, body);
          case '/api/session/end':
            return _end(res, body);
          case '/api/pair':
            if (_limited('pair:$ip', 10, const Duration(minutes: 10))) return _json(res, 429, {'error': 'slow down'});
            return _pair(res, body);
        }
      }
      return _json(res, 404, {'error': 'no such route'});
    } catch (_) {
      return _json(res, 500, {'error': 'server error'});
    }
  }

  Future<Map<String, dynamic>?> _body(HttpRequest req) async {
    final bytes = <int>[];
    await for (final chunk in req) {
      bytes.addAll(chunk);
      if (bytes.length > maxBody) return null;
    }
    if (bytes.isEmpty) return {};
    try {
      final j = jsonDecode(utf8.decode(bytes));
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  bool _limited(String key, int max, Duration window) {
    final now = _now();
    final list = _hits.putIfAbsent(key, () => [])..removeWhere((t) => now.difference(t) > window);
    if (list.length >= max) return true;
    list.add(now);
    return false;
  }

  DeviceRec? _device(HttpRequest req) {
    final auth = req.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (!auth.startsWith('Bearer ')) return null;
    final h = _sha(auth.substring(7).trim());
    for (final d in store.devices.values) {
      if (d.tokenHash == h) return d;
    }
    return null;
  }

  void _startSession(HttpRequest req, HttpResponse res, Map<String, dynamic> b) {
    final device = _device(req);
    if (device == null && !store.settings.acceptUnpaired) return _json(res, 401, {'error': 'pair this phone first'});
    final ms = _now().millisecondsSinceEpoch;
    device?.lastSeen = ms;
    final id = _token(16);
    final key = _token(24);
    final guardians = b['guardians'] is List
        ? (b['guardians'] as List).take(5).map((g) => _str(g, 20)).where((g) => g.isNotEmpty).toList()
        : <String>[];
    store.sessions[id] = SessionRec(
      id: id,
      keyHash: _sha(key),
      guardians: guardians,
      name: _str(b['name'], 40).isEmpty ? 'Your friend' : _str(b['name'], 40),
      kind: _str(b['kind'], 20).isEmpty ? 'wingman' : _str(b['kind'], 20),
      startedAt: ms,
      lastBeat: ms,
    );
    store.changed();
    _emit('A live session started');
    _json(res, 200, {'id': id, 'key': key, 'trackUrl': '${_base(req)}/t/$id'});
  }

  SessionRec? _authed(Map<String, dynamic> b) {
    final s = store.sessions[_str(b['id'], 64)];
    if (s == null || s.keyHash != _sha('${b['key']}')) return null;
    return s;
  }

  void _beat(HttpResponse res, Map<String, dynamic> b) {
    final s = _authed(b);
    if (s == null) return _json(res, 403, {'error': 'bad key'});
    final ms = _now().millisecondsSinceEpoch;
    if (s.dark) _emit('A phone that went dark is checking in again');
    s
      ..lastBeat = ms
      ..dark = false;
    final lat = _num(b['lat'], -90, 90);
    final lon = _num(b['lon'], -180, 180);
    if (lat != null && lon != null) {
      s.location = Fix(lat, lon, ms);
      s.trail.add(s.location!);
      if (s.trail.length > maxTrail) s.trail.removeRange(0, s.trail.length - maxTrail);
    }
    if (statuses.contains(b['status'])) s.status = b['status'] as String;
    final note = _str(b['note'], 140);
    if (note.isNotEmpty) _note(s, ms, note);
    store.changed();
    _json(res, 200, {'ok': true});
  }

  void _end(HttpResponse res, Map<String, dynamic> b) {
    final s = _authed(b);
    if (s == null) return _json(res, 403, {'error': 'bad key'});
    final ms = _now().millisecondsSinceEpoch;
    final reason = _str(b['reason'], 60);
    final safe = reason == 'safe' || reason == 'arrived';
    s
      ..active = false
      ..status = safe ? 'safe' : 'ended'
      ..endedAt = ms;
    _note(s, ms, reason.isEmpty ? 'ended' : reason);
    store.changed();
    _emit(safe ? 'A live session ended safely' : 'A live session ended');
    _json(res, 200, {'ok': true});
  }

  void _track(HttpResponse res, String id) {
    final s = store.sessions[id];
    if (s == null) return _json(res, 404, {'error': 'not found'});
    res.headers.set('Cache-Control', 'no-store');
    _json(res, 200, {
      'name': s.name,
      'kind': s.kind,
      'status': s.status,
      'active': s.active,
      'dark': s.dark,
      'darkAt': s.darkAt,
      'startedAt': s.startedAt,
      'lastBeat': s.lastBeat,
      'location': s.location?.toJson(),
      'trail': [for (final f in s.trail) f.toJson()],
      'notes': [for (final n in s.notes.skip(max(0, s.notes.length - 20))) n.toJson()],
      'now': _now().millisecondsSinceEpoch,
    });
  }

  void _pair(HttpResponse res, Map<String, dynamic> b) {
    final code = _str(b['code'], 12);
    if (!_pairingValid || code != _pairingCode) return _json(res, 403, {'error': 'wrong or expired code'});
    _pairingCode = null; // one phone per code
    final ms = _now().millisecondsSinceEpoch;
    final token = _token(32);
    final d = DeviceRec(
      id: _token(8),
      name: _str(b['name'], 40).isEmpty ? 'Phone' : _str(b['name'], 40),
      tokenHash: _sha(token),
      pairedAt: ms,
      lastSeen: ms,
    );
    store.devices[d.id] = d;
    store.changed();
    _emit('Paired "${d.name}"');
    _json(res, 200, {'deviceId': d.id, 'token': token});
  }

  // ---- helpers ------------------------------------------------------------

  /// Base for links guardians open: the public address if set, else the
  /// address the phone used to reach this Hub.
  String _base(HttpRequest req) {
    final pub = store.settings.publicUrl.trim();
    if (pub.isNotEmpty) return pub.endsWith('/') ? pub.substring(0, pub.length - 1) : pub;
    final host = req.headers.value(HttpHeaders.hostHeader) ?? 'localhost:${port ?? store.settings.port}';
    return 'http://$host';
  }

  void _note(SessionRec s, int ms, String text) {
    s.notes.add(Note(ms, text));
    if (s.notes.length > maxNotes) s.notes.removeRange(0, s.notes.length - maxNotes);
  }

  void _emit(String text, {bool alert = false}) => onEvent?.call(HubEvent(_now(), text, alert: alert));

  String _token(int bytes) =>
      base64Url.encode(List.generate(bytes, (_) => _rng.nextInt(256))).replaceAll('=', '');

  static String _sha(String s) => sha256.convert(utf8.encode(s)).toString();

  static String _str(Object? v, int maxLen) => v is String ? (v.length > maxLen ? v.substring(0, maxLen) : v) : '';

  static double? _num(Object? v, double lo, double hi) {
    final n = v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    return n != null && n.isFinite && n >= lo && n <= hi ? n : null;
  }

  void _json(HttpResponse res, int code, Object body) {
    res.headers.contentType = ContentType.json;
    _send(res, code, jsonEncode(body));
  }

  void _html(HttpResponse res, String body) {
    res.headers
      ..contentType = ContentType.html
      ..set('Cache-Control', 'no-cache');
    _send(res, 200, body);
  }

  void _send(HttpResponse res, int code, String? body) {
    res.statusCode = code;
    if (body != null) res.write(body);
    res.close();
  }

  String _homePage(HttpRequest req) {
    final base = _esc(_base(req));
    return '''<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Winger Hub</title>
<style>
:root{--page:#FAF7FC;--card:#fff;--text:#241519;--text2:#6E5A5F;--plum:#6B2A55;--green:#3DBE7B}
*{box-sizing:border-box}body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:var(--page);color:var(--text)}
main{max-width:560px;margin:0 auto;padding:28px 16px}
h1{font-size:30px;font-weight:800;letter-spacing:-.6px;margin:0 0 6px}
.pill{display:inline-flex;gap:8px;align-items:center;font-weight:700;font-size:14px;color:#1d6b43;background:#e3f6eb;border-radius:99px;padding:6px 12px;margin-bottom:18px}
.pill i{width:9px;height:9px;border-radius:50%;background:var(--green)}
.card{background:var(--card);border-radius:22px;padding:18px;box-shadow:0 6px 18px rgba(16,20,24,.08);margin-bottom:12px}
p{line-height:1.5;margin:0 0 10px;color:var(--text2)}b{color:var(--text)}
code{background:#F2EEF7;border-radius:8px;padding:2px 7px;font-size:14px;word-break:break-all}
.foot{font-size:12px;text-align:center;margin-top:18px}
</style></head><body><main>
<h1>Winger Hub</h1>
<div class="pill"><i></i>Running</div>
<div class="card"><p><b>This computer is a household Winger Hub.</b> Phones running Winger send their live sessions here instead of the cloud, and guardians follow them by link.</p>
<p>Hub address: <code>$base</code></p></div>
<div class="card"><p><b>Connect a phone.</b> In Winger, set the backend to the address above. Guardians get a link that opens on this Hub; no app, no login.</p>
<p>This page shows no names, sessions or locations. Each live session is visible only to the guardians who were sent its link.</p></div>
<p class="foot">Winger helps get help faster; it is not a guarantee of safety. In danger, call 112.</p>
</main></body></html>''';
  }

  static String _esc(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}
