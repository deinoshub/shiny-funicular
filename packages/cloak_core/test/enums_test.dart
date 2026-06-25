import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('enum names map to wire flag values', () {
    expect(SpoofPlatform.macos.name, 'macos');
    expect(SpoofPlatform.windows.name, 'windows');
    expect(SpoofPlatform.linux.name, 'linux');
    expect(BrowserBrand.chrome.name, 'chrome');
    expect(BrowserBrand.vivaldi.name, 'vivaldi');
  });

  test('brand default versions match the upstream table', () {
    expect(BrowserBrand.chrome.defaultVersion, '146.0.7680.177');
    expect(BrowserBrand.edge.defaultVersion, '146.0.7680.79');
    expect(BrowserBrand.opera.defaultVersion, '115.0.5322.68');
    expect(BrowserBrand.vivaldi.defaultVersion, '7.5.3735.44');
  });

  test('enums round-trip by name', () {
    expect(ProxyType.values.byName('socks5'), ProxyType.socks5);
    expect(WebRtcIpPolicy.values.byName('spoofAuto'), WebRtcIpPolicy.spoofAuto);
  });
}
