import 'dart:async';

import 'package:elevenlabs_agents/elevenlabs_agents.dart';

import '../config.dart';

/// The ElevenLabs voice agent on the other end of the Wingman call.
///
/// The app connects with the public agent id alone; no API key is ever in
/// the app. If the agent is not reachable within [connectTimeout] the call
/// falls back to the offline companion.
class LiveAgent {
  static const connectTimeout = Duration(seconds: 5);
  ConversationClient? _client;

  bool get configured => wingerAgentId.isNotEmpty;
  bool get connected => _client != null;

  /// [variables] fill the `{{placeholders}}` in the agent's prompt. The agent
  /// can call two tools: `silent_alert` when it hears the safe phrase, and
  /// `alert_guardians` when she says she is in danger.
  Future<bool> connect({
    required Map<String, dynamic> variables,
    required Future<void> Function() onSilentAlert,
    required Future<void> Function() onAlert,
    required void Function() onLost,
  }) async {
    if (!configured) return false;
    final client = ConversationClient(
      clientTools: {
        'silent_alert': _Tool(onSilentAlert),
        'alert_guardians': _Tool(onAlert),
      },
      callbacks: ConversationCallbacks(onDisconnect: (_) {
        if (_client != null) {
          _client = null;
          onLost();
        }
      }),
    );
    try {
      await client
          .startSession(agentId: wingerAgentId, dynamicVariables: variables)
          .timeout(connectTimeout);
      _client = client;
      return true;
    } catch (_) {
      unawaited(client.endSession().catchError((_) {}));
      return false;
    }
  }

  /// Tells the agent something it cannot hear for itself.
  void tell(String context) {
    try {
      _client?.sendContextualUpdate(context);
    } catch (_) {}
  }

  Future<void> setMuted(bool muted) async {
    try {
      await _client?.setMicMuted(muted);
    } catch (_) {}
  }

  Future<void> end() async {
    final c = _client;
    _client = null;
    try {
      await c?.endSession();
    } catch (_) {}
  }
}

class _Tool implements ClientTool {
  _Tool(this.run);
  final Future<void> Function() run;

  @override
  Future<ClientToolResult?> execute(Map<String, dynamic> parameters) async {
    await run();
    return ClientToolResult.success('done');
  }
}
