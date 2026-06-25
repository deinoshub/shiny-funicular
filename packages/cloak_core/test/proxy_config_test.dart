import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('serverString builds http URL without auth', () {
    const p = ProxyConfig(
      enabled: true,
      type: ProxyType.http,
      host: 'proxy.example.com',
      port: 8080,
    );
    expect(p.serverString, 'http://proxy.example.com:8080');
  });

  test('serverString builds socks5 URL with auth', () {
    const p = ProxyConfig(
      enabled: true,
      type: ProxyType.socks5,
      host: 'proxy.example.com',
      port: 1080,
      username: 'user',
      password: 'pass',
    );
    expect(p.serverString, 'socks5://user:pass@proxy.example.com:1080');
  });

  test('disabled() factory yields a disabled config', () {
    final p = ProxyConfig.disabled();
    expect(p.enabled, isFalse);
    expect(p.type, ProxyType.http);
  });

  test('JSON round-trips', () {
    const p = ProxyConfig(
      enabled: true,
      type: ProxyType.socks5,
      host: 'h',
      port: 1,
      username: 'u',
      password: 'p',
      bypassList: 'localhost,127.0.0.1',
      geoipEnabled: true,
    );
    expect(ProxyConfig.fromJson(p.toJson()), equals(p));
  });
}
