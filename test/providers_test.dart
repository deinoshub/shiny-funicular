import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core providers construct without throwing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appPathsProvider), isA<AppPaths>());
    expect(container.read(platformInfoProvider), isA<PlatformInfo>());
    expect(container.read(processRegistryProvider), isA<ProcessRegistry>());
    expect(container.read(binaryManagerProvider), isA<BinaryManager>());
    expect(container.read(browserLauncherProvider), isA<BrowserLauncher>());
  });
}
