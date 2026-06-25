import 'dart:ffi' show Abi;

/// Host OS + CPU architecture and the CloakBrowser release asset it needs.
class PlatformInfo {
  const PlatformInfo({required this.os, required this.arch});

  /// `macos` | `windows` | `linux`.
  final String os;

  /// `arm64` | `x64`.
  final String arch;

  /// Filename of the matching GitHub release asset.
  String assetName() => switch ((os, arch)) {
        ('macos', 'arm64') => 'cloakbrowser-darwin-arm64.tar.gz',
        ('macos', 'x64') => 'cloakbrowser-darwin-x64.tar.gz',
        ('windows', 'x64') => 'cloakbrowser-windows-x64.zip',
        ('linux', 'x64') => 'cloakbrowser-linux-x64.tar.gz',
        ('linux', 'arm64') => 'cloakbrowser-linux-arm64.tar.gz',
        _ => throw UnsupportedError('Unsupported platform: $os/$arch'),
      };

  /// Whether the asset is a `.zip` (Windows) vs `.tar.gz`.
  bool get isZip => os == 'windows';

  static PlatformInfo current() => switch (Abi.current()) {
        Abi.macosArm64 => const PlatformInfo(os: 'macos', arch: 'arm64'),
        Abi.macosX64 => const PlatformInfo(os: 'macos', arch: 'x64'),
        Abi.windowsX64 => const PlatformInfo(os: 'windows', arch: 'x64'),
        Abi.linuxX64 => const PlatformInfo(os: 'linux', arch: 'x64'),
        Abi.linuxArm64 => const PlatformInfo(os: 'linux', arch: 'arm64'),
        final other => throw UnsupportedError('Unsupported ABI: $other'),
      };
}
