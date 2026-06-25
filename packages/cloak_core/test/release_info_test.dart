import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  final json = {
    'tag_name': 'chromium-v146.0.7680.177.5',
    'name': 'Chromium v146 — Stealth Build',
    'prerelease': false,
    'assets': [
      {
        'name': 'cloakbrowser-darwin-arm64.tar.gz',
        'browser_download_url': 'https://example/darwin-arm64.tar.gz',
        'size': 209715200,
      },
      {
        'name': 'cloakbrowser-windows-x64.zip',
        'browser_download_url': 'https://example/win.zip',
        'size': 220000000,
      },
      {'name': 'SHA256SUMS', 'browser_download_url': 'https://example/sums', 'size': 100},
    ],
  };

  test('parses release + selects asset for platform', () {
    final r = ReleaseInfo.fromJson(json);
    expect(r.tagName, 'chromium-v146.0.7680.177.5');
    expect(r.isPro, isFalse);
    final asset = r.assetFor(const PlatformInfo(os: 'macos', arch: 'arm64'));
    expect(asset?.name, 'cloakbrowser-darwin-arm64.tar.gz');
    expect(asset?.downloadUrl, 'https://example/darwin-arm64.tar.gz');
  });

  test('assetFor returns null when no matching asset', () {
    final r = ReleaseInfo.fromJson(json);
    expect(r.assetFor(const PlatformInfo(os: 'linux', arch: 'x64')), isNull);
  });

  test('isPro detects pro tag', () {
    final r = ReleaseInfo.fromJson({
      ...json,
      'tag_name': 'chromium-v148.0.0.0-pro',
    });
    expect(r.isPro, isTrue);
  });

  test('listFromJson parses an array', () {
    final list = ReleaseInfo.listFromJson([json]);
    expect(list, hasLength(1));
  });
}
