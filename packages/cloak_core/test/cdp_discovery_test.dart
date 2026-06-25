import 'dart:convert';
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path == '/json/version') {
        req.response.write(jsonEncode({
          'Browser': 'Chrome/146',
          'webSocketDebuggerUrl': 'ws://127.0.0.1:${server.port}/devtools/browser/abc',
        }));
      } else if (req.uri.path == '/json') {
        req.response.write(jsonEncode([
          {
            'id': 't1',
            'type': 'page',
            'title': 'Example',
            'url': 'https://example.com',
            'webSocketDebuggerUrl': 'ws://127.0.0.1:${server.port}/devtools/page/t1',
          }
        ]));
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  String base() => 'http://127.0.0.1:${server.port}';

  test('browserWebSocketUrl reads /json/version', () async {
    final url = await CdpDiscovery().browserWebSocketUrl(base());
    expect(url, contains('/devtools/browser/abc'));
  });

  test('targets reads /json', () async {
    final targets = await CdpDiscovery().targets(base());
    expect(targets.single.title, 'Example');
    expect(targets.single.type, 'page');
  });

  test('waitUntilReady returns true when reachable', () async {
    expect(
      await CdpDiscovery().waitUntilReady(base(),
          timeout: const Duration(seconds: 2)),
      isTrue,
    );
  });
}
