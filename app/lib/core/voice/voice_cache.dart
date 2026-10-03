import 'dart:typed_data';

import 'voice_cache_stub.dart'
    if (dart.library.io) 'voice_cache_io.dart'
    as platform;

/// Synthesised sentences, kept so the voice works offline after one warm run.
///
/// WAV files in app support on the phone; memory on the web.
abstract class VoiceCache {
  factory VoiceCache() => platform.createVoiceCache();

  Future<Uint8List?> read(String key);
  Future<void> write(String key, Uint8List bytes);

  /// Where the bytes can be played from, if the platform plays files.
  Future<String?> pathFor(String key);
}

/// Always-memory cache. Used on the web, and by tests.
class MemoryVoiceCache implements VoiceCache {
  final _entries = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, Uint8List bytes) async =>
      _entries[key] = bytes;

  @override
  Future<String?> pathFor(String key) async => null;
}
