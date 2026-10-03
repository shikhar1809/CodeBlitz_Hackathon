import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One point on a live session's trail.
class Fix {
  final double lat;
  final double lon;
  final int at;
  const Fix(this.lat, this.lon, this.at);

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'at': at};
  factory Fix.fromJson(Map<String, dynamic> j) =>
      Fix((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble(), j['at'] as int);
}

class Note {
  final int at;
  final String text;
  const Note(this.at, this.text);

  Map<String, dynamic> toJson() => {'at': at, 'text': text};
  factory Note.fromJson(Map<String, dynamic> j) => Note(j['at'] as int, j['text'] as String);
}

/// A continuous watch (a journey or Active duty) that guardians follow by link.
/// Only its guardians see it: the Hub's own screens show counts, never names.
class SessionRec {
  final String id;
  final String keyHash;
  final List<String> guardians;
  final String name;
  final String kind;
  final int startedAt;
  String status;
  int lastBeat;
  bool active;
  bool dark;
  int? darkAt;
  int? endedAt;
  Fix? location;
  final List<Fix> trail;
  final List<Note> notes;

  SessionRec({
    required this.id,
    required this.keyHash,
    required this.guardians,
    required this.name,
    required this.kind,
    required this.startedAt,
    this.status = 'watching',
    required this.lastBeat,
    this.active = true,
    this.dark = false,
    this.darkAt,
    this.endedAt,
    this.location,
    List<Fix>? trail,
    List<Note>? notes,
  })  : trail = trail ?? [],
        notes = notes ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyHash': keyHash,
        'guardians': guardians,
        'name': name,
        'kind': kind,
        'startedAt': startedAt,
        'status': status,
        'lastBeat': lastBeat,
        'active': active,
        'dark': dark,
        'darkAt': darkAt,
        'endedAt': endedAt,
        'location': location?.toJson(),
        'trail': [for (final f in trail) f.toJson()],
        'notes': [for (final n in notes) n.toJson()],
      };

  factory SessionRec.fromJson(Map<String, dynamic> j) => SessionRec(
        id: j['id'] as String,
        keyHash: j['keyHash'] as String,
        guardians: [...(j['guardians'] as List? ?? []).cast<String>()],
        name: j['name'] as String,
        kind: j['kind'] as String,
        startedAt: j['startedAt'] as int,
        status: j['status'] as String,
        lastBeat: j['lastBeat'] as int,
        active: j['active'] as bool,
        dark: j['dark'] as bool,
        darkAt: j['darkAt'] as int?,
        endedAt: j['endedAt'] as int?,
        location: j['location'] == null ? null : Fix.fromJson(j['location'] as Map<String, dynamic>),
        trail: [for (final f in j['trail'] as List? ?? []) Fix.fromJson(f as Map<String, dynamic>)],
        notes: [for (final n in j['notes'] as List? ?? []) Note.fromJson(n as Map<String, dynamic>)],
      );
}

/// A phone paired with this Hub. Only the token's hash is kept.
class DeviceRec {
  final String id;
  final String name;
  final String tokenHash;
  final int pairedAt;
  int lastSeen;

  DeviceRec({required this.id, required this.name, required this.tokenHash, required this.pairedAt, required this.lastSeen});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'tokenHash': tokenHash, 'pairedAt': pairedAt, 'lastSeen': lastSeen};
  factory DeviceRec.fromJson(Map<String, dynamic> j) => DeviceRec(
        id: j['id'] as String,
        name: j['name'] as String,
        tokenHash: j['tokenHash'] as String,
        pairedAt: j['pairedAt'] as int,
        lastSeen: j['lastSeen'] as int,
      );
}

class HubSettings {
  /// TCP port the Hub listens on, on every network interface.
  int port;

  /// Where guardians reach this Hub from outside the home, e.g. a Tailscale
  /// Funnel URL. Empty means links use the home-network address.
  String publicUrl;

  /// Let phones that have not paired start sessions. On by default because
  /// today's Winger app talks to the Hub the same way it talks to the cloud.
  bool acceptUnpaired;

  HubSettings({this.port = 8787, this.publicUrl = '', this.acceptUnpaired = true});

  Map<String, dynamic> toJson() => {'port': port, 'publicUrl': publicUrl, 'acceptUnpaired': acceptUnpaired};
  factory HubSettings.fromJson(Map<String, dynamic> j) => HubSettings(
        port: j['port'] as int? ?? 8787,
        publicUrl: j['publicUrl'] as String? ?? '',
        acceptUnpaired: j['acceptUnpaired'] as bool? ?? true,
      );
}

/// Everything the Hub keeps, in one JSON file. Writes are batched and atomic
/// (temp file, then rename), so a power cut never leaves a half-written file.
class HubStore {
  final File? file;
  final Map<String, SessionRec> sessions = {};
  final Map<String, DeviceRec> devices = {};
  HubSettings settings = HubSettings();
  Timer? _pending;

  HubStore([this.file]);

  /// An in-memory store for tests.
  HubStore.memory() : file = null;

  Future<void> load() async {
    final f = file;
    if (f == null || !await f.exists()) return;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      settings = HubSettings.fromJson(j['settings'] as Map<String, dynamic>? ?? {});
      for (final s in j['sessions'] as List? ?? []) {
        final rec = SessionRec.fromJson(s as Map<String, dynamic>);
        sessions[rec.id] = rec;
      }
      for (final d in j['devices'] as List? ?? []) {
        final rec = DeviceRec.fromJson(d as Map<String, dynamic>);
        devices[rec.id] = rec;
      }
    } catch (_) {
      // A damaged file is kept aside, not overwritten, and the Hub starts clean.
      await f.rename('${f.path}.damaged-${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'settings': settings.toJson(),
        'sessions': [for (final s in sessions.values) s.toJson()],
        'devices': [for (final d in devices.values) d.toJson()],
      };

  /// Schedules a write within a second; many changes become one write.
  void changed() {
    if (file == null) return;
    _pending ??= Timer(const Duration(seconds: 1), () {
      _pending = null;
      flush();
    });
  }

  Future<void> flush() async {
    final f = file;
    if (f == null) return;
    _pending?.cancel();
    _pending = null;
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent(' ').convert(toJson()), flush: true);
    await tmp.rename(f.path);
  }
}
