import 'dart:async';
import 'dart:convert';

import 'package:cross_file/cross_file.dart';

import '../../ai/gemini_client.dart';
import '../../core/l10n/app_strings.dart';
import '../../platform/network_status.dart';
import '../../platform/notices.dart';
import '../caregiver/whatsapp_alerts.dart';
import '../health/pmjay_client.dart';
import '../medicines/medicine_store.dart';
import 'sync_queue.dart';

/// Watches the connection, and when it comes back drains the queue.
///
/// Save first, sync later: a session recorded with no signal is kept on the
/// phone and the person carries on. Nothing that arrives later changes a
/// schedule on its own — an online reading is attached to the prescription
/// for a person to review.
class SyncService {
  SyncService({
    required this.queue,
    required this.network,
    required this.notices,
    required this.strings,
    this.store,
    GeminiClient Function()? gemini,
    this.alerts,
    this.pmjay,
    this.onPmjayCard,
    DateTime Function()? clock,
  }) : _gemini = gemini ?? GeminiClient.new,
       _clock = clock ?? DateTime.now;

  final SyncQueue queue;
  final NetworkStatus network;
  final Notices notices;
  AppStrings strings;

  final MedicineStore? store;
  final GeminiClient Function() _gemini;
  final WhatsAppAlerts? alerts;
  final PmjayClient? pmjay;
  final DateTime Function() _clock;

  /// A PM-JAY card found in the background: saved unconfirmed, for the
  /// patient to say "yes, this is me".
  final Future<void> Function(AyushmanCard card)? onPmjayCard;

  StreamSubscription<bool>? _sub;
  bool _draining = false;
  bool _toldOffline = false;

  void start() {
    _sub ??= network.changes.listen((online) {
      if (online) drainNow();
    });
  }

  Future<void> dispose() async => _sub?.cancel();

  /// Once per session: the banner on screen, and one notification.
  Future<void> savedOffline() async {
    if (_toldOffline) return;
    _toldOffline = true;
    await notices.show(
      NoticeIds.offline,
      strings.offlineTitle,
      strings.offlineSaved,
    );
  }

  Future<void> enqueue(SyncJob job) async {
    await queue.add(job);
    if (await network.isOnline()) unawaited(drainNow());
  }

  Future<DrainReport?> drainNow() async {
    if (_draining || queue.isEmpty) return null;
    _draining = true;
    try {
      final report = await queue.drain(_handlers, now: _clock());
      if (report.allSynced) {
        _toldOffline = false;
        await notices.show(
          NoticeIds.synced,
          strings.allSyncedTitle,
          strings.allSynced,
        );
      }
      return report;
    } finally {
      _draining = false;
    }
  }

  Map<String, Future<JobResult> Function(SyncJob)> get _handlers => {
    'gemini': _geminiRead,
    'alert': _alert,
    'pmjay': _pmjayFetch,
  };

  Future<JobResult> _geminiRead(SyncJob job) async {
    final store = this.store;
    final visitId = job.visitId;
    if (store == null || visitId == null) return JobResult.failed;
    final client = _gemini();
    if (!client.configured) return JobResult.failed;
    final readings = <Map<String, Object?>>[];
    for (final path in (job.payload['photos'] as List).cast<String>()) {
      try {
        final bytes = await XFile(path).readAsBytes();
        final r = await client.readPrescription(bytes);
        readings.addAll([
          for (final m in r.medicines)
            {
              'name': m.name,
              'instruction': m.instruction,
              'raw': m.raw,
              'uncertain': m.uncertain,
            },
        ]);
      } on GeminiException catch (e) {
        return switch (e.failure) {
          GeminiFailure.timedOut || GeminiFailure.rejected => JobResult.retry,
          _ => JobResult.failed,
        };
      } catch (_) {
        // The photo is gone: nothing to read, ever.
        return JobResult.failed;
      }
    }
    await store.attachOnlineReading(visitId, jsonEncode(readings));
    await notices.show(
      NoticeIds.newReading,
      strings.newReadingTitle,
      strings.newReading,
    );
    return JobResult.done;
  }

  Future<JobResult> _alert(SyncJob job) async {
    final r = await (alerts ?? WhatsAppAlerts()).sendAutomatic(
      job.payload['to']! as String,
      job.payload['body']! as String,
    );
    if (r.sent) return JobResult.done;
    return r.retryable ? JobResult.retry : JobResult.failed;
  }

  Future<JobResult> _pmjayFetch(SyncJob job) async {
    final r = await (pmjay ?? MockPmjayClient()).fetch(
      job.payload['id']! as String,
    );
    if (r case PmjayFound(:final card)) {
      await onPmjayCard?.call(card);
    }
    // Not found and bad format are answers too; they are not retried.
    return JobResult.done;
  }
}
