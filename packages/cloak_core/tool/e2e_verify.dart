// Headless end-to-end verification of the cloak_core stack against the real
// CloakBrowser release: discover -> download -> verify -> extract -> launch
// (real Chromium) -> CDP -> stop. Run from packages/cloak_core:
//
//   dart run tool/e2e_verify.dart
//
// Uses a temp data dir and cleans up afterwards. Exits 0 on success.
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';

Future<int> main() async {
  final base = Directory.systemTemp.createTempSync('cm_e2e_');
  final paths = AppPaths(base);
  final platform = PlatformInfo.current();
  stdout.writeln('Platform: ${platform.os}/${platform.arch}');
  stdout.writeln('Data dir: ${base.path}');

  final bm = BinaryManager(paths: paths, platform: platform);
  final registry = ProcessRegistry();
  final launcher = BrowserLauncher(paths: paths, registry: registry);

  try {
    stdout.writeln('1) Finding latest compatible release…');
    final stable = await bm.latestCompatibleRelease();
    if (stable == null) {
      stderr.writeln('No CloakBrowser build for ${platform.os}/${platform.arch}');
      return 1;
    }
    stdout.writeln('   chosen: ${stable.tagName} (asset '
        '${stable.assetFor(platform)?.name})');

    stdout.writeln('2) Downloading + verifying + extracting…');
    var lastPct = -1;
    final installed = await bm.install(stable, onProgress: (f, r, t) {
      final pct = (f * 100).round();
      if (pct != lastPct && pct % 10 == 0) {
        stdout.writeln('   $pct%  (${r ~/ 1000000}/${t ~/ 1000000} MB)');
        lastPct = pct;
      }
    });
    await bm.saveManifest(
        BinaryManifest.empty().withVersionAdded(installed).withActive(installed.version));
    final exe = bm.executablePathFor(installed);
    stdout.writeln('   installed ${installed.version}');
    stdout.writeln('   exe: $exe  (exists=${File(exe).existsSync()})');

    stdout.writeln('3) Launching a profile (real Chromium)…');
    final profile = Profile(
      id: 'e2e',
      name: 'E2E',
      colorHex: '#5E81F4',
      iconName: 'person',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      stealth: StealthConfig(
        fingerprintSeed: 'e2e-seed',
        platform: SpoofPlatform.macos,
        proxy: ProxyConfig.disabled(),
      ),
      persistent: false,
      startUrl: 'about:blank',
    );
    final running = await launcher.launch(profile: profile, executablePath: exe);
    stdout.writeln('   pid=${running.pid} cdp=${running.cdpHttpUrl}');

    stdout.writeln('4) Querying CDP targets…');
    final targets = await CdpDiscovery().targets(running.cdpHttpUrl);
    stdout.writeln('   ${targets.length} target(s); '
        'first type=${targets.isEmpty ? "-" : targets.first.type}');

    stdout.writeln('5) Stopping…');
    await launcher.stop('e2e');
    stdout.writeln('   running=${registry.isRunning('e2e')}');

    stdout.writeln('\nE2E PASSED');
    return 0;
  } catch (e, st) {
    stderr.writeln('E2E FAILED: $e');
    stderr.writeln(st);
    return 1;
  } finally {
    registry.dispose();
    try {
      base.deleteSync(recursive: true);
    } catch (_) {}
  }
}
