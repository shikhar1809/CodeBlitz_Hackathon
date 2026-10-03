import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winger_hub/server/hub_server.dart';
import 'package:winger_hub/server/store.dart';

/// Talks to a real HubServer on a loopback port, with a fake clock.
void main() {
  late HubStore store;
  late HubServer hub;
  late DateTime now;
  late HttpClient client;
  final events = <HubEvent>[];

  Uri url(String path) => Uri.parse('http://127.0.0.1:${hub.port}$path');

  Future<(int, Map<String, dynamic>)> post(String path, Object body, {String? token}) async {
    final req = await client.postUrl(url(path));
    req.headers.contentType = ContentType.json;
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    req.write(jsonEncode(body));
    final res = await req.close();
    return (res.statusCode, jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>);
  }

  Future<(int, String)> get(String path) async {
    final res = await (await client.getUrl(url(path))).close();
    return (res.statusCode, await utf8.decodeStream(res));
  }

  setUp(() async {
    now = DateTime(2026, 10, 3, 9);
    events.clear();
    store = HubStore.memory();
    hub = HubServer(store: store, trackPage: '<html>track</html>', now: () => now, onEvent: events.add);
    await hub.start(port: 0, address: InternetAddress.loopbackIPv4);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await hub.stop();
  });

  test('session start, beat, track and end match the cloud API', () async {
    final (code, s) = await post('/api/session/start', {'name': 'Asha', 'kind': 'journey', 'guardians': ['+911']});
    expect(code, 200);
    final id = s['id'] as String;
    expect(s['trackUrl'], endsWith('/t/$id'));
    expect((s['key'] as String).length, greaterThan(20));

    final (b, _) = await post('/api/session/beat', {'id': id, 'key': s['key'], 'lat': 26.85, 'lon': 80.94, 'status': 'checking', 'note': 'Asked'});
    expect(b, 200);

    final (t, body) = await get('/api/track/$id');
    expect(t, 200);
    final d = jsonDecode(body) as Map<String, dynamic>;
    expect(d['name'], 'Asha');
    expect(d['status'], 'checking');
    expect(d['location']['lat'], 26.85);
    expect((d['trail'] as List).length, 1);
    expect((d['notes'] as List).single['text'], 'Asked');
    expect(d.containsKey('guardians'), isFalse, reason: 'guardian numbers never leave the Hub');

    final (e, _) = await post('/api/session/end', {'id': id, 'key': s['key'], 'reason': 'safe'});
    expect(e, 200);
    expect(store.sessions[id]!.status, 'safe');
    expect(hub.liveSessions, 0);
  });

  test('a wrong key cannot write to a session', () async {
    final (_, s) = await post('/api/session/start', {'name': 'A'});
    final (code, _) = await post('/api/session/beat', {'id': s['id'], 'key': 'nope', 'status': 'safe'});
    expect(code, 403);
    final (end, _) = await post('/api/session/end', {'id': s['id'], 'key': 'nope'});
    expect(end, 403);
  });

  test('bad input is clamped, not trusted', () async {
    final (_, s) = await post('/api/session/start', {'name': 'x' * 500, 'guardians': List.filled(9, '1')});
    final rec = store.sessions[s['id']]!;
    expect(rec.name.length, 40);
    expect(rec.guardians.length, 5);
    await post('/api/session/beat', {'id': s['id'], 'key': s['key'], 'lat': 999, 'lon': 0, 'status': 'hacked'});
    expect(rec.location, isNull);
    expect(rec.status, 'watching');
  });

  test('dead-man switch marks a silent phone dark after 3 minutes', () async {
    final (_, s) = await post('/api/session/start', {'name': 'Zoya', 'guardians': ['+919999']});
    now = now.add(const Duration(minutes: 2));
    hub.sweep();
    expect(store.sessions[s['id']]!.dark, isFalse);
    now = now.add(const Duration(minutes: 2));
    hub.sweep();
    final rec = store.sessions[s['id']]!;
    expect(rec.dark, isTrue);
    expect(rec.status, 'alerting');
    expect(events.last.alert, isTrue);
    for (final e in events) {
      expect(e.text, isNot(anyOf(contains('Zoya'), contains('9999'))), reason: 'no names or numbers on the Hub feed');
    }

    await post('/api/session/beat', {'id': s['id'], 'key': s['key'], 'status': 'watching'});
    expect(rec.dark, isFalse);
  });

  test('ended sessions expire after 24 hours', () async {
    final (_, s) = await post('/api/session/start', {'name': 'A'});
    await post('/api/session/end', {'id': s['id'], 'key': s['key'], 'reason': 'arrived'});
    now = now.add(const Duration(hours: 23));
    hub.sweep();
    expect((await get('/api/track/${s['id']}')).$1, 200);
    now = now.add(const Duration(hours: 2));
    hub.sweep();
    expect((await get('/api/track/${s['id']}')).$1, 404);
  });

  test('pairing: one code, one phone; tokens gate sessions when required', () async {
    store.settings.acceptUnpaired = false;
    final (refused, _) = await post('/api/session/start', {'name': 'A'});
    expect(refused, 401);

    final (wrong, _) = await post('/api/pair', {'code': '000000x', 'name': 'Pixel'});
    expect(wrong, 403);

    final code = hub.newPairingCode();
    final (ok, p) = await post('/api/pair', {'code': code, 'name': 'Pixel'});
    expect(ok, 200);
    final (again, _) = await post('/api/pair', {'code': code, 'name': 'Other'});
    expect(again, 403, reason: 'a code pairs one phone');

    final (started, _) = await post('/api/session/start', {'name': 'A'}, token: p['token'] as String);
    expect(started, 200);

    hub.revoke(p['deviceId'] as String);
    final (revoked, _) = await post('/api/session/start', {'name': 'A'}, token: p['token'] as String);
    expect(revoked, 401);
  });

  test('pairing codes expire after 10 minutes', () async {
    final code = hub.newPairingCode();
    now = now.add(const Duration(minutes: 11));
    expect(hub.pairingCode, isNull);
    final (c, _) = await post('/api/pair', {'code': code});
    expect(c, 403);
  });

  test('public address is used for guardian links when set', () async {
    store.settings.publicUrl = 'https://home.example.ts.net/';
    final (_, s) = await post('/api/session/start', {'name': 'A'});
    expect(s['trackUrl'], 'https://home.example.ts.net/t/${s['id']}');
  });

  test('serves the tracking page, the home page and health', () async {
    expect(await get('/t/abc123'), (200, '<html>track</html>'));
    final (h, home) = await get('/');
    expect(h, 200);
    expect(home, contains('Winger Hub'));
    final (_, health) = await get('/api/health');
    expect(jsonDecode(health)['ok'], isTrue);
    expect((await get('/nope')).$1, 404);
  });

  test('store survives a restart', () async {
    final dir = await Directory.systemTemp.createTemp('hub');
    final f = File('${dir.path}/hub.json');
    final a = HubStore(f);
    a.settings.port = 9000;
    a.devices['d'] = DeviceRec(id: 'd', name: 'Pixel', tokenHash: 'h', pairedAt: 1, lastSeen: 2);
    a.sessions['s'] = SessionRec(id: 's', keyHash: 'k', guardians: ['1'], name: 'A', kind: 'journey', startedAt: 1, lastBeat: 1, location: const Fix(1, 2, 3));
    await a.flush();
    final b = HubStore(f);
    await b.load();
    expect(b.settings.port, 9000);
    expect(b.devices['d']!.name, 'Pixel');
    expect(b.sessions['s']!.location!.lon, 2);
    await dir.delete(recursive: true);
  });

  test('the tracking page is the same one the cloud serves', () {
    final hubCopy = File('assets/web/track.html').readAsStringSync();
    final appCopy = File('../app/web/track.html').readAsStringSync();
    expect(hubCopy, appCopy, reason: 'run tools/build_site.ps1 or copy app/web/track.html to hub/assets/web/');
  });
}
