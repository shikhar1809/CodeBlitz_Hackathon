import '../domain/dose_alarm.dart';
import '../domain/reminder_planner.dart';
import '../domain/sig.dart';
import 'dose_reminders.dart';

DoseReminders createDoseReminders() => const UnsupportedReminders();

/// Web, desktop and the test runner: no alarm service, and says so.
class UnsupportedReminders implements DoseReminders {
  const UnsupportedReminders();

  @override
  Future<ReminderStatus> sync(List<PlannedReminder> plan) async =>
      ReminderStatus.unsupported;

  @override
  Future<void> cancelSlot(DoseSlot slot) async {}

  @override
  Future<AlarmPayload?> launchAlarm() async => null;

  @override
  Stream<AlarmPayload> get alarms => const Stream.empty();

  @override
  Future<bool> ringSoon(
    AlarmPayload payload, {
    required String title,
    required String body,
    Duration after = const Duration(seconds: 15),
  }) async => false;
}
