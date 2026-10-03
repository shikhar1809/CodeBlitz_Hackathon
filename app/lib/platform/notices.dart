import 'notices_stub.dart' if (dart.library.io) 'notices_io.dart' as platform;

/// A one-off notification: "saved offline", "all synced".
abstract class Notices {
  factory Notices() => platform.createNotices();

  Future<void> show(int id, String title, String body);
}

/// Ids for one-off notices, clear of the dose reminders (0–7).
abstract final class NoticeIds {
  static const offline = 100;
  static const synced = 101;
  static const newReading = 102;
}

/// Records what it was asked to show. For tests.
class FakeNotices implements Notices {
  final shown = <(int, String, String)>[];

  @override
  Future<void> show(int id, String title, String body) async =>
      shown.add((id, title, body));
}
