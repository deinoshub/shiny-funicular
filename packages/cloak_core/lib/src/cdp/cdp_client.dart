import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class CdpException implements Exception {
  CdpException(this.message);
  final String message;
  @override
  String toString() => 'CdpException: $message';
}

/// Minimal Chrome DevTools Protocol client over a WebSocket.
class CdpClient {
  CdpClient(this.webSocketUrl);

  final String webSocketUrl;
  WebSocketChannel? _channel;
  int _nextId = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  Future<void> connect() async {
    final channel = WebSocketChannel.connect(Uri.parse(webSocketUrl));
    await channel.ready;
    _channel = channel;
    channel.stream.listen(
      _onMessage,
      onDone: _failAllPending,
      onError: (_) => _failAllPending(),
    );
  }

  void _onMessage(dynamic data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    final id = msg['id'];
    if (id is! int) return; // event, not a command reply
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (msg.containsKey('error')) {
      final err = msg['error'] as Map<String, dynamic>;
      completer.completeError(CdpException(err['message']?.toString() ?? 'error'));
    } else {
      completer.complete((msg['result'] as Map<String, dynamic>?) ?? {});
    }
  }

  void _failAllPending() {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(CdpException('connection closed'));
    }
    _pending.clear();
  }

  Future<Map<String, dynamic>> send(String method,
      [Map<String, dynamic>? params]) {
    final channel = _channel;
    if (channel == null) throw CdpException('not connected');
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    channel.sink.add(jsonEncode({
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    }));
    return completer.future;
  }

  Future<Map<String, dynamic>> getBrowserVersion() => send('Browser.getVersion');

  Future<void> navigate(String url) async =>
      await send('Page.navigate', {'url': url});

  Future<void> activateTarget(String targetId) async =>
      await send('Target.activateTarget', {'targetId': targetId});

  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
    _failAllPending();
  }
}
