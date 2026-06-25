import 'dart:async';

import 'cdp_client.dart';

/// Supplies proxy credentials to Chromium over CDP, because `--proxy-server`
/// cannot carry inline `user:pass`. It auto-attaches to every page target,
/// enables the Fetch domain with auth handling, answers `Fetch.authRequired`
/// proxy challenges with the configured credentials, and lets all other
/// paused requests continue.
///
/// Connect it to the **browser-level** WebSocket URL
/// (`CdpDiscovery.browserWebSocketUrl`) and keep it alive for the lifetime of
/// the browser process.
class ProxyAuthenticator {
  ProxyAuthenticator({
    required this.browserWsUrl,
    required this.username,
    required this.password,
    CdpClient? client,
  }) : _client = client ?? CdpClient(browserWsUrl);

  final String browserWsUrl;
  final String username;
  final String password;
  final CdpClient _client;
  StreamSubscription<CdpEvent>? _sub;

  Future<void> start() async {
    await _client.connect();
    _sub = _client.events.listen(_onEvent);
    // Auto-attach (flattened) so all target events arrive on this connection.
    await _client.send('Target.setAutoAttach', {
      'autoAttach': true,
      'waitForDebuggerOnStart': false,
      'flatten': true,
    });
  }

  Future<void> _onEvent(CdpEvent e) async {
    try {
      switch (e.method) {
        case 'Target.attachedToTarget':
          final sessionId = e.params['sessionId'] as String?;
          if (sessionId != null) {
            await _client.send(
                'Fetch.enable', {'handleAuthRequests': true}, sessionId);
          }
        case 'Fetch.authRequired':
          final requestId = e.params['requestId'];
          final challenge = e.params['authChallenge'] as Map<String, dynamic>?;
          final isProxy = challenge?['source'] == 'Proxy';
          await _client.send(
            'Fetch.continueWithAuth',
            {
              'requestId': requestId,
              'authChallengeResponse': isProxy
                  ? {
                      'response': 'ProvideCredentials',
                      'username': username,
                      'password': password,
                    }
                  : {'response': 'Default'},
            },
            e.sessionId,
          );
        case 'Fetch.requestPaused':
          await _client.send('Fetch.continueRequest',
              {'requestId': e.params['requestId']}, e.sessionId);
      }
    } catch (_) {
      // Best-effort: ignore transient CDP errors (e.g. target gone).
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    await _client.close();
  }
}
