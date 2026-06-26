import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('default HTTP proxy on a closed port -> unreachable', () async {
    final r = await ProxyTester().test(
      const ProxyConfig(
          enabled: true, type: ProxyType.http, host: '127.0.0.1', port: 1),
      timeout: const Duration(seconds: 5),
    );
    expect(r.status, ProxyTestStatus.unreachable);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('default SOCKS5 proxy on a closed port -> unreachable', () async {
    final r = await ProxyTester().test(
      const ProxyConfig(
          enabled: true, type: ProxyType.socks5, host: '127.0.0.1', port: 1),
      timeout: const Duration(seconds: 5),
    );
    expect(r.status, ProxyTestStatus.unreachable);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
