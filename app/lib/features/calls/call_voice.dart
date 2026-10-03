import 'dart:async';

import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/l10n/app_language.dart';

/// The Winger companion agent on ElevenLabs. Public agent: the app connects
/// with the id alone, so no API key is ever in the app.
const String companionAgentId = String.fromEnvironment('WINGER_COMPANION_AGENT_ID');

/// A tool the agent can call during the call.
typedef CallTool = Future<String> Function(Map<String, dynamic> params);

/// The voice on a Winger call: the ElevenLabs agent when it is reachable,
/// otherwise the phone's own voice reading a short script. Offline is never
/// silent.
class CallVoice {
  CallVoice({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  static const connectTimeout = Duration(seconds: 6);

  final FlutterTts _tts;
  ConversationClient? _agent;
  bool _ended = false;

  /// Something the agent said, for the caption on screen.
  void Function(String text)? onAgentText;

  bool get live => _agent != null;

  /// Tries ElevenLabs first. Returns true when the agent is on the line.
  Future<bool> connectAgent({
    required Map<String, dynamic> variables,
    required Map<String, CallTool> tools,
    required void Function() onLost,
  }) async {
    if (companionAgentId.isEmpty || _ended) return false;
    final client = ConversationClient(
      clientTools: {for (final e in tools.entries) e.key: _Tool(e.value)},
      callbacks: ConversationCallbacks(
        onMessage: ({required message, required source}) {
          if (source == Role.ai) onAgentText?.call(message);
        },
        onDisconnect: (_) {
          if (_agent != null) {
            _agent = null;
            onLost();
          }
        },
      ),
    );
    try {
      await client
          .startSession(agentId: companionAgentId, dynamicVariables: variables)
          .timeout(connectTimeout);
      if (_ended) {
        unawaited(client.endSession().catchError((_) {}));
        return false;
      }
      _agent = client;
      return true;
    } catch (_) {
      unawaited(client.endSession().catchError((_) {}));
      return false;
    }
  }

  /// The phone's own voice: works with no network at all.
  Future<void> say(String text, AppLanguage language) async {
    if (_ended) return;
    try {
      await _tts.setLanguage(language.locale);
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } catch (_) {}
  }

  /// Tells the agent what happened on screen (a button was pressed).
  void tell(String context) {
    try {
      _agent?.sendContextualUpdate(context);
    } catch (_) {}
  }

  Future<void> end() async {
    _ended = true;
    final a = _agent;
    _agent = null;
    try {
      await a?.endSession();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

class _Tool implements ClientTool {
  _Tool(this.run);
  final CallTool run;

  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    try {
      return ClientToolResult.success(await run(parameters));
    } catch (e) {
      return ClientToolResult.failure('$e');
    }
  }
}
