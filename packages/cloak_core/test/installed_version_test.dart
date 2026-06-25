import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  InstalledVersion v(String version) => InstalledVersion(
        version: version,
        releaseTag: 'chromium-v$version',
        appPath: 'binary/$version/Chromium.app',
        sizeBytes: 200,
        sha256: 'abc',
        installedAt: DateTime.utc(2026, 6, 25),
      );

  test('manifest add/active/remove are immutable transforms', () {
    var m = BinaryManifest.empty();
    expect(m.active, isNull);
    m = m.withVersionAdded(v('146.0.1'));
    m = m.withVersionAdded(v('147.0.2'));
    m = m.withActive('147.0.2');
    expect(m.active?.version, '147.0.2');
    m = m.withVersionRemoved('146.0.1');
    expect(m.versions, hasLength(1));
  });

  test('JSON round-trips', () {
    final m = BinaryManifest.empty()
        .withVersionAdded(v('146.0.1'))
        .withActive('146.0.1');
    expect(BinaryManifest.fromJson(m.toJson()).toJson(), equals(m.toJson()));
  });

  test('legacy binary.json migrates to a manifest', () {
    final legacy = {
      'version': '145.0.1',
      'releaseTag': 'chromium-v145.0.1',
      'appPath': 'binary/145.0.1/Chromium.app',
      'sizeBytes': 200,
      'sha256': 'abc',
      'installedAt': '2026-01-01T00:00:00.000Z',
    };
    final m = BinaryManifest.fromLegacyBinaryInfo(legacy);
    expect(m.schemaVersion, 2);
    expect(m.activeVersion, '145.0.1');
    expect(m.versions.single.version, '145.0.1');
  });
}
