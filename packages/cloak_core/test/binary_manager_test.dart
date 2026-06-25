import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory base;
  late AppPaths paths;
  setUp(() {
    base = Directory.systemTemp.createTempSync('cm_bm_');
    paths = AppPaths(base);
  });
  tearDown(() => base.deleteSync(recursive: true));

  test('loadManifest migrates legacy binary.json', () async {
    await base.create(recursive: true);
    await paths.legacyBinaryInfoFile.writeAsString('''
{"version":"145.0.1","releaseTag":"chromium-v145.0.1",
 "appPath":"binary/145.0.1/Chromium.app","sizeBytes":1,"sha256":"abc",
 "installedAt":"2026-01-01T00:00:00.000Z"}
''');
    final bm = BinaryManager(
      paths: paths,
      platform: const PlatformInfo(os: 'macos', arch: 'arm64'),
    );
    final manifest = await bm.loadManifest();
    expect(manifest.activeVersion, '145.0.1');
    expect(await paths.manifestFile.exists(), isTrue);
    expect(await paths.legacyBinaryInfoFile.exists(), isFalse);
  });

  test('loadManifest returns empty when nothing installed', () async {
    final bm = BinaryManager(
      paths: paths,
      platform: const PlatformInfo(os: 'linux', arch: 'x64'),
    );
    final m = await bm.loadManifest();
    expect(m.versions, isEmpty);
    expect(m.active, isNull);
  });

  test('executablePathFor resolves per-OS', () {
    final v = InstalledVersion(
      version: '146.0.1',
      releaseTag: 'chromium-v146.0.1',
      appPath: 'binary/146.0.1/Chromium.app',
      sizeBytes: 1,
      sha256: 'abc',
      installedAt: DateTime.utc(2026),
    );
    final mac = BinaryManager(
            paths: paths, platform: const PlatformInfo(os: 'macos', arch: 'arm64'))
        .executablePathFor(v);
    expect(mac, endsWith('Chromium.app/Contents/MacOS/Chromium'));

    final win = BinaryManager(
            paths: paths, platform: const PlatformInfo(os: 'windows', arch: 'x64'))
        .executablePathFor(InstalledVersion(
      version: '146.0.1',
      releaseTag: 'chromium-v146.0.1',
      appPath: 'binary/146.0.1',
      sizeBytes: 1,
      sha256: 'abc',
      installedAt: DateTime.utc(2026),
    ));
    expect(win, endsWith('chrome.exe'));
  });
}
