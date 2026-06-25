import 'dart:io';
import 'package:path/path.dart' as p;

/// Resolves the on-disk locations CloakManager owns.
class AppPaths {
  AppPaths(this.baseDir);

  final Directory baseDir;

  /// Computes the per-OS base directory. [operatingSystem] defaults to
  /// `Platform.operatingSystem`; [environment] to `Platform.environment`.
  static AppPaths resolve({
    Map<String, String>? environment,
    String? operatingSystem,
  }) {
    final env = environment ?? Platform.environment;
    final os = operatingSystem ?? Platform.operatingSystem;
    // Build the base path in the target OS's path style so resolving for a
    // foreign OS (e.g. in tests) yields that OS's separators.
    final ctx = p.Context(
        style: os == 'windows' ? p.Style.windows : p.Style.posix);
    final base = switch (os) {
      'macos' => ctx.join(
          env['HOME'] ?? '', 'Library', 'Application Support', 'CloakManager'),
      'windows' => ctx.join(env['APPDATA'] ?? '', 'CloakManager'),
      _ => ctx.join(
          env['XDG_DATA_HOME'] ?? ctx.join(env['HOME'] ?? '', '.local', 'share'),
          'CloakManager'),
    };
    return AppPaths(Directory(base));
  }

  Directory get binaryDir => Directory(p.join(baseDir.path, 'binary'));
  Directory get profilesDir => Directory(p.join(baseDir.path, 'profiles'));
  Directory get downloadsDir => Directory(p.join(baseDir.path, 'downloads'));
  File get manifestFile => File(p.join(baseDir.path, 'manifest.json'));
  File get legacyBinaryInfoFile => File(p.join(baseDir.path, 'binary.json'));
  File get databaseFile => File(p.join(baseDir.path, 'cloakmanager.sqlite'));

  Directory binaryVersionDir(String version) =>
      Directory(p.join(binaryDir.path, version));
  Directory profileDir(String profileId) =>
      Directory(p.join(profilesDir.path, profileId));
}
