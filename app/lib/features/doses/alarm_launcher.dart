import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_alarm.dart';
import '../../core/plain_language.dart';
import '../../domain/dose_alarm.dart';
import '../../domain/scheduled_medicine.dart';
import '../../platform/dose_reminders.dart';
import '../caregiver/family.dart';
import '../medicines/medicine_store.dart';
import 'alarm_screen.dart';
import 'dose_log_store.dart';
import 'reminder_sync.dart';

/// Open the alarm screen for [payload] on top of whatever is showing.
///
/// The medicines are read from the store now, not from the notification: one
/// stopped after the alarm was set is not shown. Returns false when there is
/// nothing to ask — the slot was taken meanwhile, or nothing is due in it.
Future<bool> openDoseAlarm(
  NavigatorState navigator,
  AlarmPayload payload, {
  required AppState state,
  DoseReminders? reminders,
  DateTime Function() clock = DateTime.now,
}) async {
  final store = await MedicineStore.load();
  final logs = await DoseLogStore.load();
  final active = store.active();
  final due = payload.demo
      ? DoseAlarm.demoMedicines(payload, active)
      : DoseAlarm.medicinesFor(payload, active);
  final open = DoseAlarm.shouldOpen(
    payload: payload,
    due: due,
    alreadyTaken: logs.logFor(payload.date, payload.slot) != null,
  );
  if (!open || !navigator.mounted) return false;

  final alarms = reminders ?? DoseReminders();
  final strings = AppStrings(state.language);
  final family = familyNotifier(state);
  Future<void> resync(List<ScheduledMedicine> meds) => syncReminders(
    reminders: alarms,
    medicines: meds,
    logs: logs,
    strings: strings,
  );

  unawaited(
    navigator.push(
      MaterialPageRoute<bool>(
        builder: (_) => AlarmScreen(
          slot: payload.slot,
          date: payload.date,
          medicines: due,
          logs: logs,
          reminders: alarms,
          clock: clock,
          demo: payload.demo,
          onTaken: (slot, date) async {
            await family.doseTaken(slot, date, now: clock());
            await resync(store.active());
          },
          // Nothing was logged, so a full re-sync keeps the +30 nudge if it
          // is still ahead — and never adds a third alarm.
          onLater: (_, _) => resync(store.active()),
        ),
      ),
    ),
  );
  return true;
}

/// The demo button (DevFlags.demoTools): the alarm for today's slot nearest
/// to now, with its real medicines — or the demo medicine on an empty
/// schedule. Shown now, or rung in fifteen seconds so it can be watched
/// waking a locked phone. A demo alarm never writes to the log.
Future<void> openDoseDemo(
  BuildContext context, {
  bool ring = false,
  DoseReminders? reminders,
  DateTime Function() clock = DateTime.now,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final state = AppScope.of(context);
  final s = L10n.of(context);
  final store = await MedicineStore.load();
  final logs = await DoseLogStore.load();
  final now = clock();
  final target = DoseAlarm.demoTarget(
    medicines: store.active(),
    now: now,
    taken: (date, slot) => logs.logFor(date, slot) != null,
  );
  if (!ring) {
    await openDoseAlarm(
      navigator,
      target,
      state: state,
      reminders: reminders,
      clock: clock,
    );
    return;
  }
  final meds = DoseAlarm.demoMedicines(target, store.active());
  final rung = await (reminders ?? DoseReminders()).ringSoon(
    target,
    title: '${PlainLanguage.slot(target.slot, s)} · ${s.alarmTitle}',
    body: meds.map((m) => m.name).join(', '),
  );
  messenger.showSnackBar(
    SnackBar(
      content: Text(rung ? s.doseDemoRingSet : s.doseDemoRingUnavailable),
    ),
  );
}

/// Listens for alarms for the life of the app, and opens the one that
/// launched it.
class DoseAlarmRouter {
  DoseAlarmRouter({
    required this.navigatorKey,
    required this.state,
    this.reminders,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final AppState state;

  /// Injected by tests.
  final DoseReminders? reminders;
  StreamSubscription<AlarmPayload>? _sub;

  // Built on first use, never in a constructor: the plugin talks to the
  // platform.
  DoseReminders get _alarms => reminders ?? DoseReminders();

  Future<void> start() async {
    _sub = _alarms.alarms.listen(_open);
    final launch = await _alarms.launchAlarm();
    if (launch != null) await _open(launch);
  }

  Future<void> _open(AlarmPayload payload) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    await openDoseAlarm(navigator, payload, state: state, reminders: _alarms);
  }

  void dispose() => _sub?.cancel();
}
