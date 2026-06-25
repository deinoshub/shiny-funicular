import 'dart:async';

import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

/// Captures every `send()` call so we can assert on the CDP traffic the
/// ProxyAuthenticator produces, and lets tests inject events the way the
/// browser would.
class _FakeCdpClient extends CdpClient {
  _FakeCdpClient() : super('ws://fake');

  final List<_SentCall> sent = [];
  final _events = StreamController<CdpEvent>.broadcast();

  @override
  Stream<CdpEvent> get events => _events.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<Map<String, dynamic>> send(
    String method, [
    Map<String, dynamic>? params,
    String? sessionId,
  ]) async {
    sent.add(_SentCall(method, params ?? const {}, sessionId));
    return const {};
  }

  @override
  Future<void> close() async {
    if (!_events.isClosed) await _events.close();
  }

  void emit(String method, Map<String, dynamic> params, {String? sessionId}) {
    _events.add(
      CdpEvent(method: method, params: params, sessionId: sessionId),
    );
  }
}

class _SentCall {
  _SentCall(this.method, this.params, this.sessionId);
  final String method;
  final Map<String, dynamic> params;
  final String? sessionId;

  bool isFetchEnableOn({String? session}) =>
      method == 'Fetch.enable' &&
      params['handleAuthRequests'] == true &&
      sessionId == session;
}

void main() {
  late _FakeCdpClient client;
  late ProxyAuthenticator auth;

  setUp(() {
    client = _FakeCdpClient();
    auth = ProxyAuthenticator(
      browserWsUrl: 'ws://fake',
      username: 'alice',
      password: 's3cret',
      client: client,
    );
  });

  tearDown(() async {
    await auth.stop();
    await client.close();
  });

  test('start() enables Fetch with auth handling on the browser session',
      () async {
    await auth.start();

    expect(
      client.sent.any((c) => c.isFetchEnableOn(session: null)),
      isTrue,
      reason: 'Fetch.enable must be called on the browser-level session '
          '(no sessionId) so proxy 407 challenges are intercepted.',
    );
  });

  test('start() pauses new targets until Fetch is enabled on them', () async {
    await auth.start();

    final attach = client.sent.firstWhere(
      (c) => c.method == 'Target.setAutoAttach',
    );
    expect(attach.params['autoAttach'], isTrue);
    expect(attach.params['waitForDebuggerOnStart'], isTrue,
        reason: 'waitForDebuggerOnStart must be true so a fresh target '
            'cannot fire requests before Fetch.enable is processed.');
    expect(attach.params['flatten'], isTrue);
  });

  test('Target.attachedToTarget enables Fetch AND resumes the target',
      () async {
    await auth.start();
    client.sent.clear();

    client.emit('Target.attachedToTarget', {
      'sessionId': 'S1',
      'targetInfo': {'targetId': 'T1', 'type': 'page'},
    });
    // Let the listener run.
    await Future<void>.delayed(Duration.zero);

    expect(
      client.sent.any((c) => c.isFetchEnableOn(session: 'S1')),
      isTrue,
      reason: 'Fetch.enable must be called on each newly attached session.',
    );
    expect(
      client.sent.any((c) =>
          c.method == 'Runtime.runIfWaitingForDebugger' &&
          c.sessionId == 'S1'),
      isTrue,
      reason: 'After enabling Fetch on a paused target we must resume it, '
          'otherwise the page hangs forever.',
    );
  });

  test('Fetch.authRequired (source=Proxy) answers with credentials',
      () async {
    await auth.start();

    client.emit('Fetch.authRequired', {
      'requestId': 'R1',
      'request': {'url': 'https://example.test/'},
      'authChallenge': {'source': 'Proxy', 'origin': 'http://proxy:8080'},
    });
    await Future<void>.delayed(Duration.zero);

    final resp = client.sent.firstWhere(
      (c) => c.method == 'Fetch.continueWithAuth',
    );
    expect(resp.params['requestId'], 'R1');
    expect(resp.params['authChallengeResponse'],
        {'response': 'ProvideCredentials', 'username': 'alice', 'password': 's3cret'});
  });

  test('Fetch.authRequired (source=Server) falls through with Default',
      () async {
    await auth.start();

    client.emit('Fetch.authRequired', {
      'requestId': 'R2',
      'request': {'url': 'https://example.test/'},
      'authChallenge': {'source': 'Server'},
    });
    await Future<void>.delayed(Duration.zero);

    final resp = client.sent.firstWhere(
      (c) => c.method == 'Fetch.continueWithAuth',
    );
    expect(resp.params['authChallengeResponse'], {'response': 'Default'});
  });
}
