import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('macOS base dir uses Application Support', () {
    final paths = AppPaths.resolve(
      operatingSystem: 'macos',
      environment: {'HOME': '/Users/jane'},
    );
    expect(paths.baseDir.path,
        '/Users/jane/Library/Application Support/CloakManager');
  });

  test('Windows base dir uses APPDATA', () {
    final paths = AppPaths.resolve(
      operatingSystem: 'windows',
      environment: {'APPDATA': r'C:\Users\jane\AppData\Roaming'},
    );
    expect(paths.baseDir.path, r'C:\Users\jane\AppData\Roaming\CloakManager');
  });

  test('Linux honors XDG_DATA_HOME then falls back', () {
    final xdg = AppPaths.resolve(
      operatingSystem: 'linux',
      environment: {'XDG_DATA_HOME': '/home/jane/.xdg'},
    );
    expect(xdg.baseDir.path, '/home/jane/.xdg/CloakManager');

    final fallback = AppPaths.resolve(
      operatingSystem: 'linux',
      environment: {'HOME': '/home/jane'},
    );
    expect(fallback.baseDir.path, '/home/jane/.local/share/CloakManager');
  });

  test('subpaths derive from base', () {
    final paths = AppPaths(Directory('/data'));
    expect(paths.binaryDir.path, p.normalize('/data/binary'));
    expect(paths.manifestFile.path, p.normalize('/data/manifest.json'));
    expect(paths.binaryVersionDir('1.2.3').path,
        p.normalize('/data/binary/1.2.3'));
    expect(paths.profileDir('abc').path, p.normalize('/data/profiles/abc'));
  });
}
