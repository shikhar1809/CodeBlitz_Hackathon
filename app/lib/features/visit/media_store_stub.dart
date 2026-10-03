import 'package:cross_file/cross_file.dart';

import 'media_store.dart';

MediaStore createMediaStore() => _MemoryMediaStore();

class _MemoryMediaStore implements MediaStore {
  @override
  bool get persistent => false;

  @override
  Future<String> keep(
    String visitId,
    XFile file, {
    required String name,
  }) async => file.path;

  @override
  Future<void> deleteVisit(String visitId) async {}
}
