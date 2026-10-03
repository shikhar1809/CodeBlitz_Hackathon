import '../../core/l10n/app_strings.dart';
import '../../domain/reminder_planner.dart';
import '../../domain/scheduled_medicine.dart';
import '../../platform/dose_reminders.dart';
import 'dose_log_store.dart';

/// Plan from the medicines and the log, then hand it all to the phone.
Future<ReminderStatus> syncReminders({
  required DoseReminders reminders,
  required Iterable<ScheduledMedicine> medicines,
  required DoseLogStore logs,
  required AppStrings strings,
  DateTime? now,
}) => reminders.sync(
  ReminderPlanner.plan(
    medicines: medicines,
    taken: (date, slot) => logs.logFor(date, slot) != null,
    now: now ?? DateTime.now(),
    strings: strings,
  ),
);

/// The words the schedule shows when reminders cannot run — or null.
String? reminderBanner(ReminderStatus status, AppStrings s) => switch (status) {
  ReminderStatus.ready => null,
  ReminderStatus.denied => s.remindersOff,
  ReminderStatus.unsupported => s.remindersUnavailable,
};
