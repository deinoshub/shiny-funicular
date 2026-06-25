import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('defaults emit only the always-present brand flag', () {
    final args = StealthArgsBuilder.build(StealthConfig.defaults());
    expect(args, ['--fingerprint-brand=chrome']);
  });

  test('null seed is omitted; set seed is emitted', () {
    final withSeed = StealthArgsBuilder.build(
      StealthConfig(fingerprintSeed: 'abc', proxy: ProxyConfig.disabled()),
    );
    expect(withSeed, contains('--fingerprint=abc'));
  });

  test('auto platform is omitted; explicit platform is emitted', () {
    final auto = StealthArgsBuilder.build(StealthConfig.defaults());
    expect(auto.any((a) => a.startsWith('--fingerprint-platform')), isFalse);

    final win = StealthArgsBuilder.build(
      StealthConfig(platform: SpoofPlatform.windows, proxy: ProxyConfig.disabled()),
    );
    expect(win, contains('--fingerprint-platform=windows'));
  });

  test('noise flag only emitted when disabled', () {
    final on = StealthArgsBuilder.build(StealthConfig.defaults());
    expect(on.any((a) => a.startsWith('--fingerprint-noise')), isFalse);

    final off = StealthArgsBuilder.build(
      StealthConfig(noiseEnabled: false, proxy: ProxyConfig.disabled()),
    );
    expect(off, contains('--fingerprint-noise=false'));
  });

  test('webrtc policy maps correctly', () {
    expect(
      StealthArgsBuilder.build(StealthConfig.defaults())
          .any((a) => a.startsWith('--fingerprint-webrtc-ip')),
      isFalse,
    );
    expect(
      StealthArgsBuilder.build(StealthConfig(
        webrtcIpPolicy: WebRtcIpPolicy.spoofAuto,
        proxy: ProxyConfig.disabled(),
      )),
      contains('--fingerprint-webrtc-ip=auto'),
    );
    expect(
      StealthArgsBuilder.build(StealthConfig(
        webrtcIpPolicy: WebRtcIpPolicy.spoofExplicit,
        explicitWebRtcIp: '203.0.113.7',
        proxy: ProxyConfig.disabled(),
      )),
      contains('--fingerprint-webrtc-ip=203.0.113.7'),
    );
  });

  test('enabled proxy emits server and bypass flags', () {
    final args = StealthArgsBuilder.build(StealthConfig(
      proxy: const ProxyConfig(
        enabled: true,
        type: ProxyType.http,
        host: 'proxy.example.com',
        port: 8080,
        bypassList: 'localhost,127.0.0.1',
      ),
    ));
    expect(args, contains('--proxy-server=http://proxy.example.com:8080'));
    expect(args, contains('--proxy-bypass-list=localhost,127.0.0.1'));
  });

  test('full config produces the worked-example flag set', () {
    final args = StealthArgsBuilder.build(StealthConfig(
      fingerprintSeed: 'work-us-east-2026',
      platform: SpoofPlatform.windows,
      brand: BrowserBrand.chrome,
      brandVersion: '146.0.7680.177',
      hardwareConcurrency: 16,
      deviceMemoryGB: 16,
      screenWidth: 2560,
      screenHeight: 1440,
      timezone: 'America/New_York',
      locale: 'en-US',
      gpuVendor: 'Google Inc. (NVIDIA)',
      gpuRenderer: 'ANGLE (NVIDIA, RTX 4070)',
      webrtcIpPolicy: WebRtcIpPolicy.spoofAuto,
      proxy: const ProxyConfig(
        enabled: true,
        type: ProxyType.http,
        host: 'residential-proxy-us-east',
        port: 8080,
      ),
    ));
    expect(args, containsAll(<String>[
      '--fingerprint=work-us-east-2026',
      '--fingerprint-platform=windows',
      '--fingerprint-brand=chrome',
      '--fingerprint-brand-version=146.0.7680.177',
      '--fingerprint-hardware-concurrency=16',
      '--fingerprint-device-memory=16',
      '--fingerprint-screen-width=2560',
      '--fingerprint-screen-height=1440',
      '--fingerprint-timezone=America/New_York',
      '--fingerprint-locale=en-US',
      '--fingerprint-gpu-vendor=Google Inc. (NVIDIA)',
      '--fingerprint-gpu-renderer=ANGLE (NVIDIA, RTX 4070)',
      '--fingerprint-webrtc-ip=auto',
      '--proxy-server=http://residential-proxy-us-east:8080',
    ]));
  });
}
