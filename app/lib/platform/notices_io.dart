import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notices.dart';

Notices createNotices() => Platform.isAndroid ? _AndroidNotices() : _Silent();

class _AndroidNotices implements Notices {
  FlutterLocalNotificationsPlugin? _plugin;

  static const _channel = AndroidNotificationDetails(
    'sync',
    'Saving and syncing',
    channelDescription: 'Saved offline, and synced when back online',
    importance: Importance.defaultImportance,
  );

  @override
  Future<void> show(int id, String title, String body) async {
    try {
      final plugin = _plugin ??= FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _channel),
      );
    } catch (_) {
      // A notice that cannot be shown is not worth a crash; the on-screen
      // banner says the same thing.
    }
  }
}

class _Silent implements Notices {
  @override
  Future<void> show(int id, String title, String body) async {}
}
