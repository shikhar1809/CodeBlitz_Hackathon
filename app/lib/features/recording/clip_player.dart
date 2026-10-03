import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays back a kept recording. Built lazily: an [AudioPlayer] touches a
/// platform channel, and one built at load breaks every test (GOTCHAS).
class ClipPlayer {
  ClipPlayer({AudioPlayer? player}) : _injected = player;

  final AudioPlayer? _injected;
  AudioPlayer? _lazy;
  AudioPlayer get _player => _injected ?? (_lazy ??= AudioPlayer());

  /// Plays [path] from the start. False when it cannot — the screen says so
  /// rather than sitting silent.
  Future<bool> play(String path) async {
    try {
      await _player.stop();
      // On the web a kept recording is a blob URL, not a file.
      await _player.play(kIsWeb ? UrlSource(path) : DeviceFileSource(path));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    if (_injected == null && _lazy == null) return;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (_lazy == null) return;
    try {
      await _lazy!.dispose();
    } catch (_) {}
  }
}
