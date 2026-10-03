import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QueuedAlert {
  const QueuedAlert({
    required this.key,
    required this.to,
    required this.body,
    required this.queuedAt,
  });

  final String key;
  final String to;
  final String body;
  final DateTime queuedAt;

  Map<String, Object?> toJson() => {
    'key': key,
    'to': to,
    'body': body,
    'queuedAt': queuedAt.toIso8601String(),
  };

  factory QueuedAlert.fromJson(Map<String, Object?> j) => QueuedAlert(
    key: j['key']! as String,
    to: j['to']! as String,
    body: j['body']! as String,
    queuedAt: DateTime.parse(j['queuedAt']! as String),
  );
}

/// An alert with no signal is not lost.
///
/// A send that failed for a reason that might pass — no network, a busy
/// server — is written down here and tried again the next time the app has
/// reason to reach out. Only retryable failures come here: a bad number would
/// be retried forever.
class AlertOutbox {
  AlertOutbox(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'rapidrx.alerts.outbox';

  /// An alert this old is news nobody needs any more.
  static const maxAge = Duration(days: 2);

  List<QueuedAlert> all() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          QueuedAlert.fromJson((j as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> queue(QueuedAlert a) async {
    final items = all()..removeWhere((x) => x.key == a.key);
    await _save([...items, a]);
  }

  /// Try each queued alert with [send]. Sent ones, permanent failures and
  /// stale ones leave the queue; the rest stay for next time.
  Future<int> drain(
    Future<({bool sent, bool retryable})> Function(QueuedAlert) send, {
    required DateTime now,
  }) async {
    var sent = 0;
    final keep = <QueuedAlert>[];
    for (final a in all()) {
      if (now.difference(a.queuedAt) > maxAge) continue;
      final r = await send(a);
      if (r.sent) {
        sent++;
      } else if (r.retryable) {
        keep.add(a);
      }
    }
    await _save(keep);
    return sent;
  }

  Future<void> _save(List<QueuedAlert> items) =>
      _prefs.setString(_key, jsonEncode([for (final a in items) a.toJson()]));
}
