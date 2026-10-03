import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/feedback/haptics.dart';

/// Where one take is.
enum RecordingPhase {
  /// Nothing yet.
  idle,

  /// The microphone is open.
  recording,

  /// Kept: long enough, and something was heard.
  recorded,

  /// Stopped before [RecordingController.minLength].
  tooShort,

  /// Long enough, but nothing was heard.
  silent,

  /// A kept take the person threw away.
  deleted,
}

/// "Did it record?" — the answer, as a state machine with no widgets, no
/// timers and no microphone in it.
///
/// idle → recording → recorded(length) → deleted, or recording → tooShort /
/// silent. Time and sound are *fed in*: [tick] with the time since the start
/// (a ticker on the phone, a pumped frame in a test) and [hear] with a
/// loudness from 0 to 1. That makes every branch testable without waiting a
/// real second.
class RecordingController extends ChangeNotifier {
  RecordingController({
    this.minLength = const Duration(seconds: 1),
    this.silenceBelow = .15,
    this.meterBars = 12,
  });

  /// Shorter than this is a slip of the finger, not a recording.
  final Duration minLength;

  /// A take whose loudest moment stays under this heard nothing.
  final double silenceBelow;

  /// How many recent levels the meter shows.
  final int meterBars;

  RecordingPhase _phase = RecordingPhase.idle;
  RecordingPhase get phase => _phase;

  Duration _elapsed = Duration.zero;

  /// Time since the start, while recording; the length of the take after.
  Duration get elapsed => _elapsed;

  /// The length of a kept take, when it is known. A take kept on an earlier
  /// visit to the screen has no length to show.
  Duration? _length;
  Duration? get length => _length;

  double _peak = 0;
  bool _sawLevel = false;
  late List<double> _history = List.filled(meterBars, 0);

  /// The most recent levels, oldest first, for the meter.
  List<double> get history => List.unmodifiable(_history);

  double get level => _history.last;

  bool get isRecording => _phase == RecordingPhase.recording;
  bool get isKept => _phase == RecordingPhase.recorded;

  /// Too short or silent: the amber "nothing heard".
  bool get heardNothing =>
      _phase == RecordingPhase.tooShort || _phase == RecordingPhase.silent;

  /// The mic opened. A light tap, so the finger knows it took.
  void start() {
    _phase = RecordingPhase.recording;
    _elapsed = Duration.zero;
    _length = null;
    _peak = 0;
    _sawLevel = false;
    _history = List.filled(meterBars, 0);
    Haptics.tap();
    notifyListeners();
  }

  /// Time since [start]. Only a new second is news to the screen.
  void tick(Duration sinceStart) {
    if (!isRecording) return;
    final newSecond = sinceStart.inSeconds != _elapsed.inSeconds;
    _elapsed = sinceStart;
    if (newSecond) notifyListeners();
  }

  /// A loudness from 0 (quiet) to 1 (loud).
  void hear(double value) {
    if (!isRecording) return;
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    _sawLevel = true;
    _peak = math.max(_peak, v);
    _history = [..._history.skip(1), v];
    notifyListeners();
  }

  /// The mic closed. Decides what the take was, says so with a buzz, and
  /// returns it.
  ///
  /// [heard] overrides the loudness when the caller knows better — dictation
  /// knows whether any words came back. Without it, a take with no level
  /// readings at all (a platform that reports none) is given the benefit of
  /// the doubt: silence is only claimed when it was measured.
  RecordingPhase stop({bool? heard}) {
    if (!isRecording) return _phase;
    final silent = heard != null ? !heard : _sawLevel && _peak < silenceBelow;
    _phase = _elapsed < minLength
        ? RecordingPhase.tooShort
        : silent
        ? RecordingPhase.silent
        : RecordingPhase.recorded;
    if (_phase == RecordingPhase.recorded) {
      _length = _elapsed;
      Haptics.confirm();
    } else {
      Haptics.error();
    }
    notifyListeners();
    return _phase;
  }

  /// Words that arrived after the stop: a take judged silent was not.
  void heardLate() {
    if (_phase != RecordingPhase.silent) return;
    _phase = RecordingPhase.recorded;
    _length = _elapsed;
    Haptics.confirm();
    notifyListeners();
  }

  /// Show a take kept earlier, whose length is not known.
  void restoreKept() {
    _phase = RecordingPhase.recorded;
    _length = null;
    notifyListeners();
  }

  void delete() {
    if (_phase != RecordingPhase.recorded) return;
    _phase = RecordingPhase.deleted;
    notifyListeners();
  }

  /// Back to nothing — the mic could not open, or a retry is about to start.
  void reset() {
    _phase = RecordingPhase.idle;
    _elapsed = Duration.zero;
    _length = null;
    notifyListeners();
  }

  /// `0:42`, `12:05`.
  static String clock(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}
