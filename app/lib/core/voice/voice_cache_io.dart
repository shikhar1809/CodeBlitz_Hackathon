import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'voice_cache.dart';

VoiceCache createVoiceCache() => _FileVoiceCache();

class _FileVoiceCache implements VoiceCache {
  Directory? _dir;
  final _memory = MemoryVoiceCache();

  Future<Directory?> _folder() async {
    if (_dir != null) return _dir;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/voice');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return _dir = dir;
    } catch (_) {
      // No documents folder (a desktop test runner, say): memory will do.
      return null;
    }
  }

  @override
  Future<Uint8List?> read(String key) async {
    final dir = await _folder();
    if (dir == null) return _memory.read(key);
    final file = File('${dir.path}/$key.wav');
    return file.existsSync() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    final dir = await _folder();
    if (dir == null) return _memory.write(key, bytes);
    await File('${dir.path}/$key.wav').writeAsBytes(bytes, flush: true);
  }

  @override
  Future<String?> pathFor(String key) async {
    final dir = await _folder();
    if (dir == null) return null;
    final file = File('${dir.path}/$key.wav');
    return file.existsSync() ? file.path : null;
  }
}
