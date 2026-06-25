import 'dart:convert';
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final socket = await WebSocketTransformer.upgrade(req);
      socket.listen((data) {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        final id = msg['id'];
        final method = msg['method'];
        if (method == 'Browser.getVersion') {
          socket.add(jsonEncode({'id': id, 'result': {'product': 'Chrome/146'}}));
        } else if (method == 'Page.navigate') {
          socket.add(jsonEncode({'id': id, 'result': {'frameId': 'f1'}}));
        } else {
          socket.add(jsonEncode({'id': id, 'error': {'message': 'unknown'}}));
        }
      });
    });
  });
  tearDown(() => server.close(force: true));

  String wsUrl() => 'ws://127.0.0.1:${server.port}/devtools/browser/abc';

  test('send resolves matching result', () async {
    final client = CdpClient(wsUrl());
    await client.connect();
    final result = await client.getBrowserVersion();
    expect(result['product'], 'Chrome/146');
    await client.close();
  });

  test('navigate sends Page.navigate', () async {
    final client = CdpClient(wsUrl());
    await client.connect();
    await client.navigate('https://example.com'); // resolves without throwing
    await client.close();
  });

  test('unknown method surfaces the error', () async {
    final client = CdpClient(wsUrl());
    await client.connect();
    expect(client.send('Bogus.method'), throwsA(isA<CdpException>()));
    await client.close();
  });
}
