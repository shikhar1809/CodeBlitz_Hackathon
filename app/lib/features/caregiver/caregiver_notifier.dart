import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../doses/dose_log_store.dart';
import 'alert_outbox.dart';
import 'plan_summary.dart';
import 'whatsapp_alerts.dart';

enum NotifyResult { sent, queued, alreadySent, notConfigured, noNumber, failed }

/// When the family is told.
///
/// Automatic only, for dose events: it never falls back to opening WhatsApp,
/// because hijacking the patient's screen the moment they press "सब ले ली"
/// would be worse than no alert at all. Once per slot per day, remembered on
/// the phone, so reopening the app never re-announces a dose missed three
/// hours ago.
class CaregiverNotifier {
  CaregiverNotifier({
    required this.alerts,
    required this.prefs,
    required this.patientName,
    required this.caregiverPhone,
    required this.strings,
  }) : outbox = AlertOutbox(prefs);

  final WhatsAppAlerts alerts;
  final SharedPreferences prefs;
  final AlertOutbox outbox;
  final String patientName;
  final String? caregiverPhone;
  final AppStrings strings;

  static const _sentKey = 'rapidrx.alerts.sent';

  /// Enough to cover two days of four slots, with room.
  static const remember = 60;

  static String keyFor(DateTime date, DoseSlot slot, String kind) {
    final d = dayOf(date);
    return '${d.year}-${d.month}-${d.day}/${slot.name}/$kind';
  }

  bool alreadySent(String key) =>
      (prefs.getStringList(_sentKey) ?? const []).contains(key);

  Future<void> _remember(String key) async {
    final keys = [...?prefs.getStringList(_sentKey), key];
    await prefs.setStringList(
      _sentKey,
      keys.length > remember ? keys.sublist(keys.length - remember) : keys,
    );
  }

  Future<NotifyResult> doseTaken(
    DoseSlot slot,
    DateTime date, {
    required DateTime now,
  }) => _notify(
    keyFor(date, slot, 'taken'),
    PlanSummary.alert(
      name: patientName,
      slot: slot,
      taken: true,
      date: date,
      now: now,
      s: strings,
    ),
  );

  /// Look back over today and yesterday for slots that were missed and not
  /// yet reported. Called when a schedule screen opens.
  Future<List<NotifyResult>> checkMissed(
    Iterable<ScheduledMedicine> medicines,
    DoseLogStore logs, {
    required DateTime now,
  }) async {
    final out = <NotifyResult>[];
    for (final date in [now.subtract(const Duration(days: 1)), now]) {
      for (final slot in logs.missedOn(now, date, medicines)) {
        out.add(
          await _notify(
            keyFor(date, slot, 'missed'),
            PlanSummary.alert(
              name: patientName,
              slot: slot,
              taken: false,
              date: date,
              now: now,
              s: strings,
            ),
          ),
        );
      }
    }
    return out;
  }

  /// Send what the outbox is holding.
  Future<int> drainOutbox({required DateTime now}) => outbox.drain((a) async {
    final r = await alerts.sendAutomatic(a.to, a.body);
    return (sent: r.sent, retryable: r.retryable);
  }, now: now);

  Future<NotifyResult> _notify(String key, String body) async {
    final to = WhatsAppAlerts.normalise(caregiverPhone);
    if (to == null) return NotifyResult.noNumber;
    if (!alerts.automatic) return NotifyResult.notConfigured;
    if (alreadySent(key)) return NotifyResult.alreadySent;

    final r = await alerts.sendAutomatic(to, body);
    if (r.sent) {
      await _remember(key);
      return NotifyResult.sent;
    }
    if (r.retryable) {
      // Remembered now, at queue time, so a queued alert is never also sent
      // fresh the next time the screen opens.
      await _remember(key);
      await outbox.queue(
        QueuedAlert(key: key, to: to, body: body, queuedAt: DateTime.now()),
      );
      return NotifyResult.queued;
    }
    return NotifyResult.failed;
  }
}
