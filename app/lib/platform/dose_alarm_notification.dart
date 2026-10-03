import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// How a dose alarm looks and sounds on Android. Pure, so a test can hold it
/// to the promise: it wakes the screen.
///
/// Its own channel, not the old `dose_reminders` one: Android freezes a
/// channel's importance and sound the first time it is created, so an
/// upgraded phone would keep the quiet settings forever.
abstract final class DoseAlarmNotification {
  static const channelId = 'dose_alarms';
  static const channelName = 'Dose alarms';

  /// The channel before alarms woke the screen. Deleted on first use so the
  /// settings page does not list a dead one.
  static const oldChannelId = 'dose_reminders';

  /// Long, short, long: a phone buzzing on a table, not a text message.
  static final vibration = Int64List.fromList([0, 900, 400, 900, 400, 900]);

  static NotificationDetails details() => NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription:
          'Wakes the screen when a dose is due, and once more 30 minutes later',
      importance: Importance.max,
      priority: Priority.max,
      // Wake the screen and open the alarm screen, even when locked. Android
      // 14+ lets a person turn this off per app; the notification still
      // shows as a heads-up then, and tapping it opens the same screen.
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      // Rings on the alarm stream, so a phone on "media volume zero" still
      // rings; vibrates too, for a phone on silent.
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibration,
      // The alarm screen shows the names over the lock screen anyway; hiding
      // them here would only make the heads-up less useful.
      visibility: NotificationVisibility.public,
      ticker: 'Dose due',
    ),
  );
}
