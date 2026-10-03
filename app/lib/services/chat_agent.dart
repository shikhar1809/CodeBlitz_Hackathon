import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../core/help_guide.dart';

/// The ElevenLabs text agent behind the Help chat, over a raw WebSocket in
/// text-only mode. Connects with the public agent id; no key in the app.
class ChatAgent {
  static const answerTimeout = Duration(seconds: 12);

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Completer<String>? _waiting;

  bool get configured => wingerChatAgentId.isNotEmpty;

  /// The guide is sent along so the agent tailors steps rather than invents.
  static String withGuide(String message, Guide? guide) {
    if (guide == null) return message;
    final steps = [
      for (var i = 0; i < guide.steps.length; i++) '${i + 1}. ${guide.steps[i]}'
    ].join('\n');
    final lines = guide.helplines.map((h) => '${h.name} ${h.number}').join(', ');
    return 'GUIDE: ${guide.title}\n$steps\nHelplines: $lines\n\nHER MESSAGE: $message';
  }

  Future<String> ask(String message, {Guide? guide, String language = 'en'}) async {
    if (!configured) throw StateError('no chat agent');
    _channel ??= await _open(language);
    final w = Completer<String>();
    _waiting = w;
    _channel!.sink.add(jsonEncode({'type': 'user_message', 'text': withGuide(message, guide)}));
    return w.future.timeout(answerTimeout);
  }

  Future<WebSocketChannel> _open(String language) async {
    final channel = WebSocketChannel.connect(Uri.parse(
        'wss://api.elevenlabs.io/v1/convai/conversation?agent_id=$wingerChatAgentId'));
    await channel.ready;
    _sub = channel.stream.listen(_onMessage, onDone: _lost, onError: (_) => _lost());
    channel.sink.add(jsonEncode({
      'type': 'conversation_initiation_client_data',
      'dynamic_variables': {'language': language},
    }));
    return channel;
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    switch (m['type']) {
      case 'ping':
        _channel?.sink.add(jsonEncode(
            {'type': 'pong', 'event_id': (m['ping_event'] as Map)['event_id']}));
      case 'agent_response':
        final text =
            ((m['agent_response_event'] as Map)['agent_response'] as String).trim();
        final w = _waiting;
        _waiting = null;
        if (w != null && !w.isCompleted && text.isNotEmpty) w.complete(text);
    }
  }

  void _lost() {
    final w = _waiting;
    _waiting = null;
    if (w != null && !w.isCompleted) w.completeError(StateError('connection lost'));
    _channel = null;
  }

  Future<void> close() async {
    final c = _channel;
    _channel = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await c?.sink.close();
    } catch (_) {}
  }
}
