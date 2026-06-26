import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proxyTesterProvider exposes a ProxyTester', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(proxyTesterProvider), isA<ProxyTester>());
  });
}
