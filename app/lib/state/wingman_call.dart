import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/companion.dart';
import '../core/ladder.dart';
import '../core/pin_vault.dart';
import '../services/live_agent.dart';
import 'app_state.dart';

enum CallPhase { calling, connected, ended }

/// One Wingman call: the live ElevenLabs agent when reachable, otherwise the
/// offline companion script spoken on the phone.
class WingmanCall extends ChangeNotifier {
  WingmanCall(this.app, {LiveAgent? agent}) : agent = agent ?? LiveAgent();

  final AppState app;
  final LiveAgent agent;
  final CompanionScript script = CompanionScript();

  CallPhase phase = CallPhase.calling;
  DateTime? connectedAt;
  bool live = false;
  bool muted = false;
  bool speaker = false;
  String keypad = '';
  int _reconnects = 0;
  DateTime? _riyaSpokeAt;
  DateTime? _herLastWords;
  DateTime? _agentLostAt;

  bool get ended => phase == CallPhase.ended;

  Duration elapsed(DateTime now) =>
      connectedAt == null ? Duration.zero : now.difference(connectedAt!);

  Future<void> start() async {
    final s = app.settings;
    live = await agent.connect(
      variables: {
        'user_name': s.name,
        'companion_name': s.companionName,
        'language': s.lang == 'hi' ? 'Hindi' : 'English',
        'safe_phrases': s.phrases.join('; '),
      },
      onSilentAlert: () => app.silentAlert('Safe phrase heard on the call'),
      onAlert: () async => app.help(),
      onLost: _agentLost,
    );
    if (ended) {
      await agent.end();
      return;
    }
    phase = CallPhase.connected;
    connectedAt = DateTime.now();
    app.note(live ? 'Live voice agent on the line' : 'Offline companion voice on the line');
    if (!live) _say(script.next(connectedAt!));
    notifyListeners();
    app.notifyListeners();
  }

  void _agentLost() {
    if (ended) return;
    live = false;
    _agentLostAt = DateTime.now();
    app.note('Agent hung up; offline voice carries on');
    notifyListeners();
  }

  void _say(String? line) {
    if (line == null || ended) return;
    _riyaSpokeAt = DateTime.now();
    if (app.settings.voiceCompanion) app.voice.say(line, lang: app.settings.lang);
  }

  /// She finished saying something (from the on-phone recogniser).
  void herTurn(String words) {
    if (ended || phase != CallPhase.connected) return;
    final now = DateTime.now();
    _herLastWords = now;
    if (live) return;
    // The agent dropped after her silence: bring it back when she speaks.
    if (agent.configured && _agentLostAt != null && _reconnects < 4) {
      _reconnects++;
      _agentLostAt = null;
      unawaited(_reconnect());
      return;
    }
    _say(script.next(now, herTurnEnded: true, heardHer: true));
  }

  Future<void> _reconnect() async {
    await app.voice.stop();
    final ok = await agent.connect(
      variables: {
        'user_name': app.settings.name,
        'companion_name': app.settings.companionName,
        'language': app.settings.lang == 'hi' ? 'Hindi' : 'English',
        'safe_phrases': app.settings.phrases.join('; '),
      },
      onSilentAlert: () => app.silentAlert('Safe phrase heard on the call'),
      onAlert: () async => app.help(),
      onLost: _agentLost,
    );
    live = ok;
    if (ok) app.note('Live voice agent back on the line');
    notifyListeners();
  }

  void tick(DateTime now) {
    if (phase != CallPhase.connected || live) return;
    final spoke = _riyaSpokeAt;
    if (spoke != null &&
        now.difference(spoke) >= const Duration(seconds: 12) &&
        (_herLastWords == null || _herLastWords!.isBefore(spoke))) {
      // Her whole turn passed in silence.
      _say(script.next(now, herTurnEnded: true, heardHer: false));
      if (script.wantsCheckIn && app.session?.ladder.rung == Rung.idle) {
        app.session!.ladder.raise(now, to: Rung.nudge);
      }
    } else {
      _say(script.next(now));
    }
    notifyListeners();
  }

  void routeCue(String trouble) {
    final cue = CompanionScript.routeCues[trouble];
    if (cue == null || ended) return;
    if (live) {
      agent.tell('Winger noticed: $trouble. Ask her gently if she is okay.');
    } else {
      _say(cue);
    }
  }

  /// Holding Mute sends a silent alert.
  void holdMute() {
    app.note('Mute held');
    app.silentAlert('Mute held on the call');
  }

  void toggleMute() {
    muted = !muted;
    agent.setMuted(muted);
    notifyListeners();
  }

  void toggleSpeaker() {
    speaker = !speaker;
    notifyListeners();
  }

  /// A key on the dial pad. A code followed by `#` is checked.
  Future<PinResult?> press(String key) async {
    if (key == '#') {
      final entry = keypad;
      keypad = '';
      notifyListeners();
      final r = app.vault.check(entry);
      if (r == PinResult.wrong) return r;
      await app.answerPin(entry);
      return r;
    }
    keypad += key;
    if (keypad.length > 12) keypad = keypad.substring(keypad.length - 12);
    notifyListeners();
    return null;
  }

  /// The duress PIN was used: the call looks stopped like a real cancel.
  void hangUpQuietly() {
    if (ended) return;
    phase = CallPhase.ended;
    agent.end();
    app.voice.stop();
    notifyListeners();
  }

  Future<void> end({bool byUser = true}) async {
    if (ended) return;
    phase = CallPhase.ended;
    await agent.end();
    await app.voice.stop();
    if (byUser) app.callEnded();
    notifyListeners();
  }
}
