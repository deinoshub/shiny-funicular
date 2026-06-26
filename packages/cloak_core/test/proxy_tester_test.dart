import 'dart:async';
import 'dart:io';

import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

const _proxy = ProxyConfig(
  enabled: true,
  type: ProxyType.http,
  host: 'proxy.test',
  port: 8080,
  username: 'u',
  password: 'p',
);

void main() {
  test('success parses ip, geo, timezone and sets latency', () async {
    final tester = ProxyTester(
      transport: (_, __, ___) async => const ProxyHttpResponse(
        200,
        '{"success":true,"ip":"203.0.113.7","country":"France",'
        '"city":"Paris","timezone":{"id":"Europe/Paris"}}',
      ),
    );
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.success);
    expect(r.exitIp, '203.0.113.7');
    expect(r.country, 'France');
    expect(r.city, 'Paris');
    expect(r.timezone, 'Europe/Paris');
    expect(r.latency, isNotNull);
  });

  test('HTTP 407 maps to authFailed', () async {
    final tester = ProxyTester(
        transport: (_, __, ___) async => const ProxyHttpResponse(407, ''));
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.authFailed);
  });

  test('ProxyAuthException maps to authFailed and keeps message', () async {
    final tester = ProxyTester(
        transport: (_, __, ___) async =>
            throw const ProxyAuthException('bad creds'));
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.authFailed);
    expect(r.message, 'bad creds');
  });

  test('SocketException maps to unreachable', () async {
    final tester = ProxyTester(
        transport: (_, __, ___) async => throw const SocketException('refused'));
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.unreachable);
  });

  test('TimeoutException maps to timeout', () async {
    final tester = ProxyTester(
        transport: (_, __, ___) async => throw TimeoutException('slow'));
    final r = await tester.test(_proxy, timeout: const Duration(seconds: 5));
    expect(r.status, ProxyTestStatus.timeout);
  });

  test('success:false body maps to badResponse', () async {
    final tester = ProxyTester(
      transport: (_, __, ___) async =>
          const ProxyHttpResponse(200, '{"success":false,"message":"no route"}'),
    );
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.badResponse);
  });

  test('non-JSON body maps to badResponse', () async {
    final tester = ProxyTester(
        transport: (_, __, ___) async => const ProxyHttpResponse(200, '<html>'));
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.badResponse);
  });
}
