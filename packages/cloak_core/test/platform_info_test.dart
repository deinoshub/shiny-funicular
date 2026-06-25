import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('asset names match the published release assets', () {
    expect(const PlatformInfo(os: 'macos', arch: 'arm64').assetName(),
        'cloakbrowser-darwin-arm64.tar.gz');
    expect(const PlatformInfo(os: 'macos', arch: 'x64').assetName(),
        'cloakbrowser-darwin-x64.tar.gz');
    expect(const PlatformInfo(os: 'windows', arch: 'x64').assetName(),
        'cloakbrowser-windows-x64.zip');
    expect(const PlatformInfo(os: 'linux', arch: 'x64').assetName(),
        'cloakbrowser-linux-x64.tar.gz');
    expect(const PlatformInfo(os: 'linux', arch: 'arm64').assetName(),
        'cloakbrowser-linux-arm64.tar.gz');
  });

  test('unsupported combo throws', () {
    expect(
      () => const PlatformInfo(os: 'windows', arch: 'arm64').assetName(),
      throwsUnsupportedError,
    );
  });

  test('current() returns a supported os/arch', () {
    final info = PlatformInfo.current();
    expect(['macos', 'windows', 'linux'], contains(info.os));
    expect(['arm64', 'x64'], contains(info.arch));
  });
}
