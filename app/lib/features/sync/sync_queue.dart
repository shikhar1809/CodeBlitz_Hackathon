import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

/// Something that needs the network, written down so it survives a restart.
class SyncJob {
  const SyncJob({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.notBefore,
    this.visitId,
  });

  final String id;

  /// Which handler runs it: `gemini`, `alert`, `pmjay`.
  final String kind;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final int attempts;

  /// Backing off until then.
  final DateTime? notBefore;

  /// The visit it belongs to, so My prescriptions can say "waiting to sync".
  final String? visitId;

  SyncJob retried(DateTime now) => SyncJob(
    id: id,
    kind: kind,
    payload: payload,
    createdAt: createdAt,
    attempts: attempts + 1,
    notBefore: now.add(SyncQueue.backoff(attempts + 1)),
    visitId: visitId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts,
    if (notBefore != null) 'notBefore': notBefore!.toIso8601String(),
    if (visitId != null) 'visitId': visitId,
  };

  factory SyncJob.fromJson(Map<String, Object?> j) => SyncJob(
    id: j['id']! as String,
    kind: j['kind']! as String,
    payload: (j['payload']! as Map).cast<String, Object?>(),
    createdAt: DateTime.parse(j['createdAt']! as String),
    attempts: j['attempts'] as int? ?? 0,
    notBefore: switch (j['notBefore']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
    visitId: j['visitId'] as String?,
  );
}

enum JobResult { done, retry, failed }

class DrainReport {
  const DrainReport({
    required this.done,
    required this.failed,
    required this.remaining,
  });

  final int done;
  final int failed;
  final int remaining;

  bool get allSynced => remaining == 0 && done > 0;
}

/// Everything waiting for a connection, drained in order when one appears.
///
/// A job that fails for a reason that might pass is tried again later, with
/// backoff; one that can never succeed is dropped rather than retried
/// forever. Nothing here blocks the person using the app: the on-device
/// analysis has already given them a result.
class SyncQueue {
  SyncQueue(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'rapidrx.sync.queue';

  static Future<SyncQueue> load() async =>
      SyncQueue(await SharedPreferences.getInstance());

  /// 15 s, 30 s, 1 min … capped at 30 minutes.
  static Duration backoff(int attempts) => Duration(
    seconds: math.min(30 * 60, 15 * math.pow(2, attempts - 1).toInt()),
  );

  List<SyncJob> all() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          SyncJob.fromJson((j as Map).cast<String, Object?>()),
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (_) {
      return [];
    }
  }

  bool get isEmpty => all().isEmpty;

  bool waitingFor(String visitId) => all().any((j) => j.visitId == visitId);

  Future<void> add(SyncJob job) async {
    final jobs = all()..removeWhere((j) => j.id == job.id);
    await _save([...jobs, job]);
  }

  Future<DrainReport> drain(
    Map<String, Future<JobResult> Function(SyncJob)> handlers, {
    required DateTime now,
  }) async {
    var done = 0, failed = 0;
    final keep = <SyncJob>[];
    for (final job in all()) {
      if (job.notBefore != null && job.notBefore!.isAfter(now)) {
        keep.add(job);
        continue;
      }
      final handler = handlers[job.kind];
      if (handler == null) {
        keep.add(job);
        continue;
      }
      JobResult r;
      try {
        r = await handler(job);
      } catch (_) {
        r = JobResult.retry;
      }
      switch (r) {
        case JobResult.done:
          done++;
        case JobResult.failed:
          failed++;
        case JobResult.retry:
          keep.add(job.retried(now));
      }
    }
    await _save(keep);
    return DrainReport(done: done, failed: failed, remaining: keep.length);
  }

  Future<void> _save(List<SyncJob> jobs) =>
      _prefs.setString(_key, jsonEncode([for (final j in jobs) j.toJson()]));
}
