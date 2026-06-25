import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/editor/advanced_tab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Profile p() => Profile(
        id: 'p1',
        name: 'Work',
        colorHex: '#fff',
        iconName: 'person',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        stealth: StealthConfig(fingerprintSeed: 'seed', proxy: ProxyConfig.disabled()),
        startUrl: 'https://example.com',
      );

  test('computedArgsPreview matches LaunchArgsComposer output', () {
    final preview = computedArgsPreview(p());
    expect(preview, contains('--fingerprint=seed'));
    expect(preview, contains('--remote-debugging-address=127.0.0.1'));
    expect(preview.split('\n').last, 'https://example.com');
  });
}
