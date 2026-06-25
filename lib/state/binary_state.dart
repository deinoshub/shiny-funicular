import 'package:cloak_core/cloak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

sealed class BinaryInstallState {
  const BinaryInstallState();
}

class NotInstalled extends BinaryInstallState {
  const NotInstalled();
}

class Downloading extends BinaryInstallState {
  const Downloading(this.fraction, this.received, this.total);
  final double fraction;
  final int received;
  final int total;
}

class Verifying extends BinaryInstallState {
  const Verifying();
}

class Extracting extends BinaryInstallState {
  const Extracting();
}

class Installed extends BinaryInstallState {
  const Installed(this.version);
  final InstalledVersion version;
}

class Failed extends BinaryInstallState {
  const Failed(this.message);
  final String message;
}

class BinaryStateController extends AsyncNotifier<BinaryInstallState> {
  @override
  Future<BinaryInstallState> build() async {
    final manifest = await ref.watch(binaryManagerProvider).loadManifest();
    final active = manifest.active;
    return active == null ? const NotInstalled() : Installed(active);
  }

  Future<void> downloadLatest() async {
    final bm = ref.read(binaryManagerProvider);
    final platform = ref.read(platformInfoProvider);
    try {
      final stable = await bm.latestCompatibleRelease();
      if (stable == null) {
        state = AsyncData(Failed(
            'No CloakBrowser build available for ${platform.os}/${platform.arch}'));
        return;
      }
      state = const AsyncData(Downloading(0, 0, 0));
      final installed = await bm.install(stable, onProgress: (f, r, t) {
        state = AsyncData(Downloading(f, r, t));
      });
      state = const AsyncData(Verifying());
      var manifest = await bm.loadManifest();
      manifest = manifest.withVersionAdded(installed).withActive(installed.version);
      await bm.saveManifest(manifest);
      state = AsyncData(Installed(installed));
    } catch (e) {
      state = AsyncData(Failed(e.toString()));
    }
  }
}

final binaryStateProvider =
    AsyncNotifierProvider<BinaryStateController, BinaryInstallState>(
        BinaryStateController.new);
