import '../domain/dose_alarm.dart';
import '../domain/reminder_planner.dart';
import '../domain/sig.dart';
import 'dose_reminders_stub.dart'
    if (dart.library.io) 'dose_reminders_io.dart'
    as platform;

enum ReminderStatus {
  /// Alarms are set.
  ready,

  /// The person refused notifications. The screen says so.
  denied,

  /// This build has no alarm service (web, desktop, the test runner).
  unsupported,
}

/// Hands planned reminders to the phone, and hands tapped alarms back.
///
/// When reminders cannot run at all, [sync] says so and the schedule shows a
/// banner. An alarm that silently never fires is the worst outcome: the
/// patient believes it is handled.
///
/// One per app: the plugin has a single tap handler, and a second instance
/// initialising it would silently replace the first one's.
abstract class DoseReminders {
  factory DoseReminders() => platform.createDoseReminders();

  /// A full replace: every stale alarm goes, then the plan is set. A stale
  /// alarm for a medicine stopped last week is worse than a missing one.
  Future<ReminderStatus> sync(List<PlannedReminder> plan);

  /// Cancel both alarms for [slot] — the moment a dose is confirmed, so the
  /// +30 nudge never fires for a dose already taken.
  Future<void> cancelSlot(DoseSlot slot);

  /// The alarm that started the app from cold, if one did.
  Future<AlarmPayload?> launchAlarm();

  /// Alarms tapped — or woken full-screen — while the app is running.
  Stream<AlarmPayload> get alarms;

  /// Ring once, [after] from now: the demo's way to show the real alarm on a
  /// locked phone. False where alarms cannot ring.
  Future<bool> ringSoon(
    AlarmPayload payload, {
    required String title,
    required String body,
    Duration after = const Duration(seconds: 15),
  });
}
