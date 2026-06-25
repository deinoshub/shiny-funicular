import 'dart:convert';
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
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

  test('latestCompatibleRelease skips pro + platform-less releases', () async {
    // Newest-first: pro (has darwin), newest free (NO darwin), older free (has darwin).
    final releasesJson = [
      {
        'tag_name': 'chromium-v148-pro',
        'name': 'Pro',
        'assets': [
          {'name': 'cloakbrowser-darwin-arm64.tar.gz', 'browser_download_url': 'x', 'size': 1},
          {'name': 'SHA256SUMS', 'browser_download_url': 'x', 'size': 1},
        ],
      },
      {
        'tag_name': 'chromium-v146.0.0.5',
        'name': 'Free',
        'assets': [
          {'name': 'cloakbrowser-linux-x64.tar.gz', 'browser_download_url': 'x', 'size': 1},
          {'name': 'cloakbrowser-windows-x64.zip', 'browser_download_url': 'x', 'size': 1},
        ],
      },
      {
        'tag_name': 'chromium-v145.0.0.2',
        'name': 'Free',
        'assets': [
          {'name': 'cloakbrowser-darwin-arm64.tar.gz', 'browser_download_url': 'x', 'size': 1},
          {'name': 'SHA256SUMS', 'browser_download_url': 'x', 'size': 1},
        ],
      },
    ];
    final client = MockClient((req) async => http.Response(
        jsonEncode(releasesJson), 200,
        headers: {'content-type': 'application/json'}));

    final mac = BinaryManager(
      paths: paths,
      platform: const PlatformInfo(os: 'macos', arch: 'arm64'),
      client: client,
    );
    final chosen = await mac.latestCompatibleRelease();
    expect(chosen?.tagName, 'chromium-v145.0.0.2'); // newest free with darwin

    final win = BinaryManager(
      paths: paths,
      platform: const PlatformInfo(os: 'windows', arch: 'x64'),
      client: client,
    );
    expect((await win.latestCompatibleRelease())?.tagName, 'chromium-v146.0.0.5');
  });
}
