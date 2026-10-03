import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/dose_alarm.dart';
import '../domain/reminder_planner.dart';
import '../domain/sig.dart';
import 'dose_alarm_notification.dart';
import 'dose_reminders.dart';
import 'dose_reminders_stub.dart';

// One for the whole app: the plugin keeps a single tap handler.
DoseReminders? _shared;

DoseReminders createDoseReminders() => _shared ??= Platform.isAndroid
    ? _AndroidReminders()
    : const UnsupportedReminders();

class _AndroidReminders implements DoseReminders {
  // Built on first use: the plugin talks to the platform.
  FlutterLocalNotificationsPlugin? _plugin;
  Future<void>? _ready;
  bool _launchRead = false;
  final _taps = StreamController<AlarmPayload>.broadcast();

  /// Outside the slot ids (0–7), so a demo never replaces a real alarm.
  static const _demoId = 100;

  Future<AndroidFlutterLocalNotificationsPlugin?> _android() async {
    final plugin = _plugin ??= FlutterLocalNotificationsPlugin();
    await (_ready ??= _init(plugin));
    return plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  Future<void> _init(FlutterLocalNotificationsPlugin plugin) async {
    tzdata.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      // A tap, or a full-screen alarm firing while the app is open: the plugin
      // reports both here.
      onDidReceiveNotificationResponse: (r) {
        final payload = AlarmPayload.decode(r.payload);
        if (payload != null) _taps.add(payload);
      },
    );
    try {
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.deleteNotificationChannel(
            channelId: DoseAlarmNotification.oldChannelId,
          );
    } catch (_) {
      // Not there, or never was: nothing to tidy.
    }
  }

  @override
  Future<ReminderStatus> sync(List<PlannedReminder> plan) async {
    try {
      final android = await _android();
      final allowed =
          await android?.requestNotificationsPermission() ??
          await android?.areNotificationsEnabled() ??
          false;
      if (!allowed) return ReminderStatus.denied;

      // Exact, because an inexact alarm can drift by hours, and a tablet due
      // with breakfast reminded at 2pm is the same as no reminder. If exact
      // alarms are refused, an inexact one is still far better than none.
      final mode = await _mode(android);

      final plugin = _plugin!;
      await plugin.cancelAll();
      for (final r in plan) {
        await plugin.zonedSchedule(
          id: r.id,
          // An absolute instant: correct whatever zone the phone is in.
          scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
          notificationDetails: DoseAlarmNotification.details(),
          androidScheduleMode: mode,
          title: r.title,
          body: r.body,
          payload: r.payload,
        );
      }
      return ReminderStatus.ready;
    } catch (_) {
      return ReminderStatus.unsupported;
    }
  }

  Future<AndroidScheduleMode> _mode(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    var exact = await android?.canScheduleExactNotifications() ?? false;
    if (!exact) exact = await android?.requestExactAlarmsPermission() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  @override
  Future<void> cancelSlot(DoseSlot slot) async {
    await _android();
    for (final nudge in [false, true]) {
      await _plugin!.cancel(id: ReminderPlanner.idFor(slot, nudge: nudge));
    }
  }

  @override
  Future<AlarmPayload?> launchAlarm() async {
    // Asked once: the plugin reports the same launch for the whole process,
    // and a second answer would reopen an alarm already dealt with.
    if (_launchRead) return null;
    _launchRead = true;
    try {
      await _android();
      final details = await _plugin!.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return AlarmPayload.decode(details.notificationResponse?.payload);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<AlarmPayload> get alarms => _taps.stream;

  @override
  Future<bool> ringSoon(
    AlarmPayload payload, {
    required String title,
    required String body,
    Duration after = const Duration(seconds: 15),
  }) async {
    try {
      final android = await _android();
      final allowed =
          await android?.requestNotificationsPermission() ??
          await android?.areNotificationsEnabled() ??
          false;
      if (!allowed) return false;
      await _plugin!.zonedSchedule(
        id: _demoId,
        scheduledDate: tz.TZDateTime.from(
          DateTime.now().add(after).toUtc(),
          tz.UTC,
        ),
        notificationDetails: DoseAlarmNotification.details(),
        androidScheduleMode: await _mode(android),
        title: title,
        body: body,
        payload: payload.encode(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
