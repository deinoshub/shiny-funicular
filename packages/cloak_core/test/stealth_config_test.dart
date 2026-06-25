import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('defaults() are sane', () {
    final s = StealthConfig.defaults();
    expect(s.platform, SpoofPlatform.auto);
    expect(s.brand, BrowserBrand.chrome);
    expect(s.noiseEnabled, isTrue);
    expect(s.webrtcIpPolicy, WebRtcIpPolicy.real);
    expect(s.proxy.enabled, isFalse);
  });

  test('JSON round-trips a fully-populated config', () {
    final s = StealthConfig(
      fingerprintSeed: 'seed-1',
      platform: SpoofPlatform.windows,
      brand: BrowserBrand.edge,
      brandVersion: '146.0.7680.79',
      platformVersion: '10.0',
      hardwareConcurrency: 16,
      deviceMemoryGB: 16,
      screenWidth: 2560,
      screenHeight: 1440,
      timezone: 'America/New_York',
      locale: 'en-US',
      gpuVendor: 'Google Inc. (NVIDIA)',
      gpuRenderer: 'ANGLE (NVIDIA, RTX 4070)',
      noiseEnabled: false,
      storageQuotaMB: 5000,
      webrtcIpPolicy: WebRtcIpPolicy.spoofExplicit,
      explicitWebRtcIp: '203.0.113.7',
      proxy: const ProxyConfig(
        enabled: true,
        type: ProxyType.http,
        host: 'h',
        port: 8080,
      ),
    );
    final decoded = StealthConfig.fromJson(s.toJson());
    expect(decoded.toJson(), equals(s.toJson()));
  });
}
