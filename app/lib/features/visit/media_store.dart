import 'package:cross_file/cross_file.dart';

import 'media_store_stub.dart'
    if (dart.library.io) 'media_store_io.dart'
    as platform;

/// Where a visit's photos and audio live.
///
/// On the phone: files in the app's documents folder, one folder per visit.
/// Elsewhere: whatever the picker handed us (a blob URL in the browser), kept
/// only until the tab closes — and [persistent] says so, so the screen can too.
abstract class MediaStore {
  factory MediaStore() => platform.createMediaStore();

  /// Whether captures survive the app closing.
  bool get persistent;

  /// Keep [file] as part of [visitId]; returns the path to store.
  Future<String> keep(String visitId, XFile file, {required String name});

  Future<void> deleteVisit(String visitId);
}
