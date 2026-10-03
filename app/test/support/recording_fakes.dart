import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:winger/core/l10n/app_language.dart';
import 'package:winger/features/recording/clip_player.dart';
import 'package:winger/features/visit/capture_tools.dart';
import 'package:winger/platform/dictation.dart';

/// Dictation the test speaks into: [say] streams words, [loud] a level.
class FakeDictation extends Dictation {
  FakeDictation({this.works = true});

  bool works;
  int stops = 0;
  void Function(String words, bool done)? _onWords;
  void Function(double level)? _onLevel;

  @override
  Future<bool> available() async => works;

  @override
  Future<bool> listen({
    required AppLanguage language,
    required void Function(String words, bool done) onWords,
    void Function(double level)? onLevel,
  }) async {
    if (!works) return false;
    _onWords = onWords;
    _onLevel = onLevel;
    return true;
  }

  @override
  Future<void> stop() async => stops++;

  void say(String words, {bool done = false}) => _onWords!(words, done);

  void loud(double level) => _onLevel?.call(level);
}

/// A microphone that records whatever the test decides, at the levels the
/// test feeds it.
class FakeAudio extends AudioCapture {
  FakeAudio({this.works = true, this.file = 'clip.m4a'});

  bool works;

  /// What stop() returns; null for "nothing captured".
  String? file;
  final _levels = StreamController<double>.broadcast();
  bool _on = false;

  @override
  bool get recording => _on;

  @override
  Future<bool> start() async => _on = works;

  @override
  Future<XFile?> stop() async {
    if (!_on) return null;
    _on = false;
    return file == null ? null : XFile(file!);
  }

  @override
  Stream<double> levels({Duration every = const Duration(milliseconds: 120)}) =>
      _levels.stream;

  void loud(double level) => _levels.add(level);

  @override
  Future<void> dispose() async {}
}

class FakeClipPlayer extends ClipPlayer {
  FakeClipPlayer({this.works = true});

  bool works;
  final List<String> played = [];

  @override
  Future<bool> play(String path) async {
    played.add(path);
    return works;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
