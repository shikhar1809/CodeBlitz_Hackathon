import 'notices.dart';

/// The web and desktop have no notification service here. The on-screen
/// banner already says the same thing.
Notices createNotices() => _Silent();

class _Silent implements Notices {
  @override
  Future<void> show(int id, String title, String body) async {}
}
