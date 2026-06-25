import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('ProxyConfig.copyWith overrides selected fields', () {
    final p = ProxyConfig.disabled().copyWith(enabled: true, host: 'h', port: 8080);
    expect(p.enabled, isTrue);
    expect(p.host, 'h');
    expect(p.port, 8080);
  });

  test('StealthConfig.copyWith overrides nested proxy', () {
    final s = StealthConfig.defaults()
        .copyWith(platform: SpoofPlatform.windows, brand: BrowserBrand.edge);
    expect(s.platform, SpoofPlatform.windows);
    expect(s.brand, BrowserBrand.edge);
    expect(s.proxy.enabled, isFalse);
  });

  test('Profile.copyWith overrides name + stealth', () {
    final base = Profile(
      id: 'p1',
      name: 'A',
      colorHex: '#fff',
      iconName: 'person',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      stealth: StealthConfig.defaults(),
    );
    final next = base.copyWith(name: 'B');
    expect(next.name, 'B');
    expect(next.id, 'p1');
  });
}
