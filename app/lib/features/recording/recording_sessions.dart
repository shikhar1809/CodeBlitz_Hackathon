import 'dart:async';

import 'package:cross_file/cross_file.dart';

import '../../core/l10n/app_language.dart';
import '../../platform/dictation.dart';
import '../visit/capture_tools.dart';
import 'recording_controller.dart';

/// One dictation take into a piece of text.
///
/// Remembers the words from before the take, so "record again" and "delete"
/// undo exactly this take and nothing the person wrote earlier. Whether
/// anything was heard is decided by the words: dictation that returned no
/// text heard nothing, whatever the meter showed (ADR-56).
class DictationSession {
  DictationSession({
    required this.dictation,
    required this.read,
    required this.write,
    RecordingController? recorder,
  }) : recorder = recorder ?? RecordingController();

  final Dictation dictation;
  final String Function() read;
  final void Function(String text) write;
  final RecordingController recorder;

  String _before = '';
  bool _disposed = false;

  bool get listening => recorder.isRecording;

  /// Opens the mic. False when this device cannot dictate.
  Future<bool> start(AppLanguage language) async {
    _before = read().trim();
    // Recording before listen() returns: a fast engine can deliver its final
    // words before the call completes.
    recorder.start();
    final ok = await dictation.listen(
      language: language,
      onLevel: (level) {
        if (!_disposed) recorder.hear(level);
      },
      onWords: (words, done) {
        // The engine can still deliver a final result after the screen left.
        if (_disposed) return;
        // After the stop, only a take that stands (or one judged silent,
        // which late words overturn) may still change the text — never one
        // the person deleted or is retrying.
        final late = !listening;
        if (late &&
            !recorder.isKept &&
            recorder.phase != RecordingPhase.silent) {
          return;
        }
        write([_before, words].where((x) => x.isNotEmpty).join(' '));
        if (late && words.trim().isNotEmpty) recorder.heardLate();
        if (done) _end();
      },
    );
    if (!ok && !_disposed && listening) recorder.reset();
    return ok;
  }

  Future<void> stop() async {
    await dictation.stop();
    _end();
  }

  void _end() {
    if (_disposed || !listening) return;
    recorder.stop(heard: read().trim() != _before);
  }

  /// Throw this take's words away and listen again.
  Future<bool> redo(AppLanguage language) {
    write(_before);
    recorder.reset();
    return start(language);
  }

  /// Throw this take's words away.
  void delete() {
    write(_before);
    recorder.delete();
  }

  /// Nothing was heard: listen again.
  Future<bool> retry(AppLanguage language) {
    recorder.reset();
    return start(language);
  }

  void dispose() {
    if (listening) dictation.stop();
    _disposed = true;
    recorder.dispose();
  }
}

/// One audio take: the recorder, its level stream, and whether the file is
/// worth keeping.
class ClipSession {
  ClipSession({required this.audio, RecordingController? recorder})
    : recorder = recorder ?? RecordingController();

  final AudioCapture audio;
  final RecordingController recorder;
  StreamSubscription<double>? _levels;

  bool get recording => recorder.isRecording;

  /// Opens the mic. False when there is no mic or no permission.
  Future<bool> start() async {
    recorder.start();
    if (!await audio.start()) {
      recorder.reset();
      return false;
    }
    _levels = audio.levels().listen(recorder.hear);
    return true;
  }

  /// Closes the mic. Returns the file only when the take is worth keeping —
  /// long enough, and with something in it.
  Future<XFile?> stop() async {
    // Not awaited: a level stream's cancel can wait on its own timer, and
    // the take must end on the tap, not after it.
    unawaited(_levels?.cancel());
    _levels = null;
    final file = await audio.stop();
    final phase = recorder.stop(heard: file == null ? false : null);
    return phase == RecordingPhase.recorded ? file : null;
  }

  void dispose() {
    _levels?.cancel();
    recorder.dispose();
  }
}
