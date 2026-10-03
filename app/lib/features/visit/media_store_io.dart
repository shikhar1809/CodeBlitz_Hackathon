import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';

import 'media_store.dart';

MediaStore createMediaStore() => _FileMediaStore();

class _FileMediaStore implements MediaStore {
  @override
  bool get persistent => true;

  Future<Directory> _visitDir(String visitId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/visits/$visitId');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  @override
  Future<String> keep(
    String visitId,
    XFile file, {
    required String name,
  }) async {
    final dir = await _visitDir(visitId);
    final ext = _extension(file.name.isNotEmpty ? file.name : file.path);
    final target = '${dir.path}/$name$ext';
    await file.saveTo(target);
    return target;
  }

  @override
  Future<void> deleteVisit(String visitId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/visits/$visitId');
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || name.length - dot > 6) return '';
    return name.substring(dot);
  }
}
