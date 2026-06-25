# M2 — Binary Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add to `cloak_core` the ability to discover, download (fast + resumable), verify, extract, and track multiple CloakBrowser binary versions.

**Architecture:** Pure-Dart additions to `cloak_core`. `AppPaths` resolves per-OS data directories. `ReleaseInfo`/`ReleaseAsset` parse the GitHub releases API and filter by host platform. `Sha256Sums` parses the `SHA256SUMS` manifest. `ChunkedDownloader` does parallel HTTP Range downloads with progress and resume (state persisted by `ResumeStore`). `ArchiveExtractor` unpacks `.tar.gz`/`.zip`. `BinaryManager` orchestrates the full install flow and maintains `manifest.json` (multiple installed versions + active version), exposing the executable path the launcher (M3) will use.

**Tech Stack:** Dart 3.3+. New deps: `http`, `crypto`, `archive`, `path`. Tests use `dart:io` `HttpServer` for download/verify and temp dirs for extraction — no real network.

## Global Constraints

- `cloak_core` stays pure Dart (no `package:flutter/*`).
- Release API: `https://api.github.com/repos/CloakHQ/cloakbrowser/releases?per_page=10`.
- Asset names (verbatim, from M1 `PlatformInfo.assetName()`): `cloakbrowser-{darwin,windows,linux}-{arm64,x64}.{tar.gz,zip}`.
- SHA-256 of the downloaded archive MUST be verified against `SHA256SUMS` before extraction; mismatch aborts install and does NOT extract.
- Data directory per OS: Windows `%APPDATA%\CloakManager\`, macOS `~/Library/Application Support/CloakManager/`, Linux `$XDG_DATA_HOME` or `~/.local/share/CloakManager/`.
- Manifest schema version: 2 (matches `CloakBrowser/docs/PLAN-VERSION-MANAGER.md`). Legacy single `binary.json` is read once and migrated to `manifest.json`.
- Default download chunking: 6 chunks; chunk floor 8 MB. Fall back to single-stream when the server replies `200` instead of `206`.
- Resume state lives at `<dataDir>/downloads/<asset-sha256>.json`; deleted on success; expired (deleted) after 7 days untouched.
- Executable path within an extracted version: macOS `Chromium.app/Contents/MacOS/Chromium`, Windows `chrome.exe`, Linux `chrome` (fall back to `chromium` if absent).

## File Structure

| File | Responsibility |
|---|---|
| `lib/src/storage/app_paths.dart` | Per-OS data dir + subpath getters |
| `lib/src/binary/sha256sums.dart` | Parse `SHA256SUMS` → `{filename: hash}` |
| `lib/src/binary/sha256_verifier.dart` | Stream-hash a file, compare to expected |
| `lib/src/models/release_info.dart` | `ReleaseInfo`, `ReleaseAsset`, platform filter |
| `lib/src/models/installed_version.dart` | `InstalledVersion`, `BinaryManifest` (+ legacy migration) |
| `lib/src/binary/resume_store.dart` | `ResumeState` + load/save/expire |
| `lib/src/binary/chunked_downloader.dart` | Parallel Range download with progress/resume |
| `lib/src/binary/archive_extractor.dart` | Extract `.tar.gz` / `.zip` |
| `lib/src/binary/binary_manager.dart` | Orchestration + manifest + executable path |
| `test/*` | One test file per unit |

---

### Task 1: Add dependencies + AppPaths

**Files:**
- Modify: `packages/cloak_core/pubspec.yaml` (add deps)
- Create: `packages/cloak_core/lib/src/storage/app_paths.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/app_paths_test.dart`

**Interfaces:**
- Produces:
  - `class AppPaths` with `AppPaths(Directory baseDir)`.
  - `static AppPaths resolve({Map<String, String>? environment, String? operatingSystem})` — computes base dir per OS.
  - Getters: `Directory get binaryDir`, `Directory get profilesDir`, `Directory get downloadsDir`, `File get manifestFile`, `File get legacyBinaryInfoFile`, `File get databaseFile`.
  - `Directory binaryVersionDir(String version)`, `Directory profileDir(String profileId)`.

- [ ] **Step 1: Add deps**

In `packages/cloak_core/pubspec.yaml`, add a `dependencies:` block above `dev_dependencies:`:

```yaml
dependencies:
  http: ^1.2.0
  crypto: ^3.0.3
  archive: ^3.6.0
  path: ^1.9.0
```

Run: `cd packages/cloak_core && dart pub get`
Expected: resolves without error.

- [ ] **Step 2: Write the failing test**

`packages/cloak_core/test/app_paths_test.dart`:

```dart
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/app_paths_test.dart`
Expected: FAIL — `AppPaths` undefined.

- [ ] **Step 4: Write the implementation**

`packages/cloak_core/lib/src/storage/app_paths.dart`:

```dart
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
```

- [ ] **Step 5: Export it**

In `packages/cloak_core/lib/cloak_core.dart`, add:

```dart
export 'src/storage/app_paths.dart';
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd packages/cloak_core && dart test test/app_paths_test.dart`
Expected: `+4: All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add packages/cloak_core/pubspec.yaml packages/cloak_core/lib/src/storage/app_paths.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/app_paths_test.dart
git commit -m "feat(cloak_core): add deps and AppPaths per-OS directory resolver"
```

---

### Task 2: Sha256Sums parser

**Files:**
- Create: `packages/cloak_core/lib/src/binary/sha256sums.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/sha256sums_test.dart`

**Interfaces:**
- Produces: `class Sha256Sums` with `factory Sha256Sums.parse(String content)` and `String? hashFor(String filename)`. Lines are `<hash><spaces><*?filename>` (the `*` binary marker is stripped).

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/sha256sums_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('parses standard sha256sum lines', () {
    const content = '''
505582aa1bd3971c577f70e0c0000000000000000000000000000000000000000  cloakbrowser-darwin-arm64.tar.gz
4a12bcde0000000000000000000000000000000000000000000000000000aaaa *cloakbrowser-windows-x64.zip
''';
    final sums = Sha256Sums.parse(content);
    expect(sums.hashFor('cloakbrowser-darwin-arm64.tar.gz'),
        '505582aa1bd3971c577f70e0c0000000000000000000000000000000000000000');
    expect(sums.hashFor('cloakbrowser-windows-x64.zip'),
        '4a12bcde0000000000000000000000000000000000000000000000000000aaaa');
    expect(sums.hashFor('missing.tar.gz'), isNull);
  });

  test('ignores blank lines', () {
    final sums = Sha256Sums.parse('\n\n  \n');
    expect(sums.hashFor('anything'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/sha256sums_test.dart`
Expected: FAIL — `Sha256Sums` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/binary/sha256sums.dart`:

```dart
/// Parsed `SHA256SUMS` file: a map of filename → lowercase hex digest.
class Sha256Sums {
  Sha256Sums(this._byName);

  final Map<String, String> _byName;

  factory Sha256Sums.parse(String content) {
    final map = <String, String>{};
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final hash = parts.first.toLowerCase();
      var name = parts.sublist(1).join(' ');
      if (name.startsWith('*')) name = name.substring(1);
      map[name] = hash;
    }
    return Sha256Sums(map);
  }

  String? hashFor(String filename) => _byName[filename];
}
```

- [ ] **Step 4: Export + run + commit**

Add `export 'src/binary/sha256sums.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/sha256sums_test.dart`
Expected: `+2: All tests passed!`

```bash
git add packages/cloak_core/lib/src/binary/sha256sums.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/sha256sums_test.dart
git commit -m "feat(cloak_core): add SHA256SUMS parser"
```

---

### Task 3: Sha256Verifier

**Files:**
- Create: `packages/cloak_core/lib/src/binary/sha256_verifier.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/sha256_verifier_test.dart`

**Interfaces:**
- Produces: `class Sha256Verifier` with `static Future<String> hashFile(File file)` (lowercase hex) and `static Future<bool> verify(File file, String expectedHex)`.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/sha256_verifier_test.dart`:

```dart
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cm_sha_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('hashFile matches the known SHA-256 of "abc"', () async {
    final f = File('${tmp.path}/abc.txt')..writeAsStringSync('abc');
    expect(await Sha256Verifier.hashFile(f),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  test('verify is case-insensitive and detects mismatch', () async {
    final f = File('${tmp.path}/abc.txt')..writeAsStringSync('abc');
    expect(
        await Sha256Verifier.verify(f,
            'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'),
        isTrue);
    expect(await Sha256Verifier.verify(f, 'deadbeef'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/sha256_verifier_test.dart`
Expected: FAIL — `Sha256Verifier` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/binary/sha256_verifier.dart`:

```dart
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Streams a file through SHA-256 and compares against an expected digest.
class Sha256Verifier {
  const Sha256Verifier._();

  static Future<String> hashFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static Future<bool> verify(File file, String expectedHex) async {
    final actual = await hashFile(file);
    return actual.toLowerCase() == expectedHex.toLowerCase();
  }
}
```

- [ ] **Step 4: Export + run + commit**

Add `export 'src/binary/sha256_verifier.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/sha256_verifier_test.dart`
Expected: `+2: All tests passed!`

```bash
git add packages/cloak_core/lib/src/binary/sha256_verifier.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/sha256_verifier_test.dart
git commit -m "feat(cloak_core): add streaming SHA-256 file verifier"
```

---

### Task 4: ReleaseInfo + platform filter

**Files:**
- Create: `packages/cloak_core/lib/src/models/release_info.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/release_info_test.dart`

**Interfaces:**
- Consumes: `PlatformInfo` (M1).
- Produces:
  - `class ReleaseAsset { final String name; final String downloadUrl; final int size; }` + `fromJson`.
  - `class ReleaseInfo { final String tagName; final String name; final bool prerelease; final List<ReleaseAsset> assets; }` + `fromJson`; `ReleaseAsset? assetFor(PlatformInfo)`; `bool get isPro` (tag/name contains `pro`).
  - `static List<ReleaseInfo> listFromJson(List<dynamic>)`.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/release_info_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/release_info_test.dart`
Expected: FAIL — `ReleaseInfo` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/models/release_info.dart`:

```dart
import '../platform/platform_info.dart';

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final String downloadUrl;
  final int size;

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
        name: json['name'] as String,
        downloadUrl: json['browser_download_url'] as String,
        size: (json['size'] as num?)?.toInt() ?? 0,
      );
}

class ReleaseInfo {
  const ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.prerelease,
    required this.assets,
  });

  final String tagName;
  final String name;
  final bool prerelease;
  final List<ReleaseAsset> assets;

  bool get isPro =>
      tagName.toLowerCase().contains('pro') ||
      name.toLowerCase().contains('pro');

  /// The version string without the `chromium-v` prefix, e.g. `146.0.7680.177.5`.
  String get version => tagName.replaceFirst(RegExp(r'^chromium-v'), '');

  ReleaseAsset? assetFor(PlatformInfo platform) {
    final wanted = platform.assetName();
    for (final a in assets) {
      if (a.name == wanted) return a;
    }
    return null;
  }

  ReleaseAsset? get sha256SumsAsset {
    for (final a in assets) {
      if (a.name == 'SHA256SUMS') return a;
    }
    return null;
  }

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) => ReleaseInfo(
        tagName: json['tag_name'] as String,
        name: (json['name'] as String?) ?? '',
        prerelease: (json['prerelease'] as bool?) ?? false,
        assets: ((json['assets'] as List<dynamic>?) ?? [])
            .map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static List<ReleaseInfo> listFromJson(List<dynamic> json) =>
      json.map((e) => ReleaseInfo.fromJson(e as Map<String, dynamic>)).toList();
}
```

- [ ] **Step 4: Export + run + commit**

Add `export 'src/models/release_info.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/release_info_test.dart`
Expected: `+4: All tests passed!`

```bash
git add packages/cloak_core/lib/src/models/release_info.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/release_info_test.dart
git commit -m "feat(cloak_core): add ReleaseInfo with platform asset selection"
```

---

### Task 5: InstalledVersion + BinaryManifest

**Files:**
- Create: `packages/cloak_core/lib/src/models/installed_version.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/installed_version_test.dart`

**Interfaces:**
- Produces:
  - `class InstalledVersion { String version; String releaseTag; String appPath; int sizeBytes; String sha256; DateTime installedAt; DateTime? lastUsedAt; }` + JSON.
  - `class BinaryManifest { int schemaVersion; String? activeVersion; List<InstalledVersion> versions; }` + JSON; `InstalledVersion? get active`; `BinaryManifest withActive(String)`, `withVersionAdded(InstalledVersion)`, `withVersionRemoved(String)`.
  - `static BinaryManifest fromLegacyBinaryInfo(Map<String, dynamic>)` — converts a single `binary.json` to a manifest.
  - `static BinaryManifest empty()`.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/installed_version_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/installed_version_test.dart`
Expected: FAIL — `InstalledVersion` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/models/installed_version.dart`:

```dart
class InstalledVersion {
  const InstalledVersion({
    required this.version,
    required this.releaseTag,
    required this.appPath,
    required this.sizeBytes,
    required this.sha256,
    required this.installedAt,
    this.lastUsedAt,
  });

  final String version;
  final String releaseTag;
  final String appPath; // relative to AppPaths.baseDir
  final int sizeBytes;
  final String sha256;
  final DateTime installedAt;
  final DateTime? lastUsedAt;

  Map<String, dynamic> toJson() => {
        'version': version,
        'releaseTag': releaseTag,
        'appPath': appPath,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
        'installedAt': installedAt.toUtc().toIso8601String(),
        'lastUsedAt': lastUsedAt?.toUtc().toIso8601String(),
      };

  factory InstalledVersion.fromJson(Map<String, dynamic> json) =>
      InstalledVersion(
        version: json['version'] as String,
        releaseTag: json['releaseTag'] as String,
        appPath: json['appPath'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        sha256: json['sha256'] as String,
        installedAt: DateTime.parse(json['installedAt'] as String),
        lastUsedAt: json['lastUsedAt'] == null
            ? null
            : DateTime.parse(json['lastUsedAt'] as String),
      );
}

class BinaryManifest {
  const BinaryManifest({
    required this.schemaVersion,
    required this.activeVersion,
    required this.versions,
  });

  final int schemaVersion;
  final String? activeVersion;
  final List<InstalledVersion> versions;

  static BinaryManifest empty() =>
      const BinaryManifest(schemaVersion: 2, activeVersion: null, versions: []);

  InstalledVersion? get active {
    for (final v in versions) {
      if (v.version == activeVersion) return v;
    }
    return null;
  }

  BinaryManifest _copy({String? activeVersion, List<InstalledVersion>? versions}) =>
      BinaryManifest(
        schemaVersion: schemaVersion,
        activeVersion: activeVersion ?? this.activeVersion,
        versions: versions ?? this.versions,
      );

  BinaryManifest withVersionAdded(InstalledVersion v) {
    final next = versions.where((e) => e.version != v.version).toList()..add(v);
    return _copy(versions: next);
  }

  BinaryManifest withVersionRemoved(String version) {
    final next = versions.where((e) => e.version != version).toList();
    final active = activeVersion == version ? null : activeVersion;
    return BinaryManifest(
        schemaVersion: schemaVersion, activeVersion: active, versions: next);
  }

  BinaryManifest withActive(String version) => _copy(activeVersion: version);

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'activeVersion': activeVersion,
        'versions': versions.map((v) => v.toJson()).toList(),
      };

  factory BinaryManifest.fromJson(Map<String, dynamic> json) => BinaryManifest(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 2,
        activeVersion: json['activeVersion'] as String?,
        versions: ((json['versions'] as List<dynamic>?) ?? [])
            .map((e) => InstalledVersion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory BinaryManifest.fromLegacyBinaryInfo(Map<String, dynamic> legacy) {
    final v = InstalledVersion.fromJson(legacy);
    return BinaryManifest(
        schemaVersion: 2, activeVersion: v.version, versions: [v]);
  }
}
```

- [ ] **Step 4: Export + run + commit**

Add `export 'src/models/installed_version.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/installed_version_test.dart`
Expected: `+3: All tests passed!`

```bash
git add packages/cloak_core/lib/src/models/installed_version.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/installed_version_test.dart
git commit -m "feat(cloak_core): add InstalledVersion and BinaryManifest with legacy migration"
```

---

### Task 6: ResumeStore

**Files:**
- Create: `packages/cloak_core/lib/src/binary/resume_store.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/resume_store_test.dart`

**Interfaces:**
- Produces:
  - `class ResumePart { final int index; int receivedBytes; final String path; }` + JSON.
  - `class ResumeState { String url; int totalBytes; String sha256; int chunkSize; List<ResumePart> parts; DateTime startedAt; DateTime updatedAt; }` + JSON.
  - `class ResumeStore { ResumeStore(Directory downloadsDir); Future<ResumeState?> load(String assetSha256); Future<void> save(ResumeState, {required String assetSha256}); Future<void> delete(String assetSha256); Future<void> purgeExpired({Duration maxAge = const Duration(days: 7), DateTime? now}); }`

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/resume_store_test.dart`:

```dart
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cm_resume_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ResumeState state() => ResumeState(
        url: 'https://example/a.tar.gz',
        totalBytes: 1000,
        sha256: 'abc',
        chunkSize: 500,
        parts: [
          ResumePart(index: 0, receivedBytes: 500, path: 'part-0'),
          ResumePart(index: 1, receivedBytes: 100, path: 'part-1'),
        ],
        startedAt: DateTime.utc(2026, 6, 25),
        updatedAt: DateTime.utc(2026, 6, 25),
      );

  test('save then load round-trips', () async {
    final store = ResumeStore(dir);
    await store.save(state(), assetSha256: 'abc');
    final loaded = await store.load('abc');
    expect(loaded?.totalBytes, 1000);
    expect(loaded?.parts[1].receivedBytes, 100);
  });

  test('load returns null when absent', () async {
    expect(await ResumeStore(dir).load('nope'), isNull);
  });

  test('delete removes the state', () async {
    final store = ResumeStore(dir);
    await store.save(state(), assetSha256: 'abc');
    await store.delete('abc');
    expect(await store.load('abc'), isNull);
  });

  test('purgeExpired removes states older than maxAge', () async {
    final store = ResumeStore(dir);
    final old = state()..updatedAt = DateTime.utc(2026, 6, 1);
    await store.save(old, assetSha256: 'abc');
    await store.purgeExpired(
      maxAge: const Duration(days: 7),
      now: DateTime.utc(2026, 6, 25),
    );
    expect(await store.load('abc'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/resume_store_test.dart`
Expected: FAIL — `ResumeStore` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/binary/resume_store.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class ResumePart {
  ResumePart({required this.index, required this.receivedBytes, required this.path});
  final int index;
  int receivedBytes;
  final String path;

  Map<String, dynamic> toJson() =>
      {'index': index, 'receivedBytes': receivedBytes, 'path': path};

  factory ResumePart.fromJson(Map<String, dynamic> j) => ResumePart(
        index: (j['index'] as num).toInt(),
        receivedBytes: (j['receivedBytes'] as num).toInt(),
        path: j['path'] as String,
      );
}

class ResumeState {
  ResumeState({
    required this.url,
    required this.totalBytes,
    required this.sha256,
    required this.chunkSize,
    required this.parts,
    required this.startedAt,
    required this.updatedAt,
  });

  String url;
  int totalBytes;
  String sha256;
  int chunkSize;
  List<ResumePart> parts;
  DateTime startedAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'url': url,
        'totalBytes': totalBytes,
        'sha256': sha256,
        'chunkSize': chunkSize,
        'parts': parts.map((e) => e.toJson()).toList(),
        'startedAt': startedAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory ResumeState.fromJson(Map<String, dynamic> j) => ResumeState(
        url: j['url'] as String,
        totalBytes: (j['totalBytes'] as num).toInt(),
        sha256: j['sha256'] as String,
        chunkSize: (j['chunkSize'] as num).toInt(),
        parts: (j['parts'] as List<dynamic>)
            .map((e) => ResumePart.fromJson(e as Map<String, dynamic>))
            .toList(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

/// Persists per-download resume state as `<downloadsDir>/<sha256>.json`.
class ResumeStore {
  ResumeStore(this.downloadsDir);
  final Directory downloadsDir;

  File _file(String assetSha256) =>
      File(p.join(downloadsDir.path, '$assetSha256.json'));

  Future<ResumeState?> load(String assetSha256) async {
    final f = _file(assetSha256);
    if (!await f.exists()) return null;
    return ResumeState.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  }

  Future<void> save(ResumeState state, {required String assetSha256}) async {
    await downloadsDir.create(recursive: true);
    await _file(assetSha256)
        .writeAsString(jsonEncode(state.toJson()), flush: true);
  }

  Future<void> delete(String assetSha256) async {
    final f = _file(assetSha256);
    if (await f.exists()) await f.delete();
  }

  Future<void> purgeExpired(
      {Duration maxAge = const Duration(days: 7), DateTime? now}) async {
    if (!await downloadsDir.exists()) return;
    final cutoff = (now ?? DateTime.now().toUtc()).subtract(maxAge);
    await for (final entity in downloadsDir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final state = ResumeState.fromJson(
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>);
        if (state.updatedAt.isBefore(cutoff)) await entity.delete();
      } catch (_) {
        await entity.delete(); // corrupt → drop
      }
    }
  }
}
```

- [ ] **Step 4: Export + run + commit**

Add `export 'src/binary/resume_store.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/resume_store_test.dart`
Expected: `+4: All tests passed!`

```bash
git add packages/cloak_core/lib/src/binary/resume_store.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/resume_store_test.dart
git commit -m "feat(cloak_core): add ResumeStore for resumable downloads"
```

---

### Task 7: ChunkedDownloader

**Files:**
- Create: `packages/cloak_core/lib/src/binary/chunked_downloader.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/chunked_downloader_test.dart`

**Interfaces:**
- Consumes: `ResumeStore`, `ResumeState`.
- Produces:
  - `typedef DownloadProgress = void Function(double fraction, int received, int total);`
  - `class ChunkedDownloader { ChunkedDownloader({http.Client? client, int chunkCount = 6, int minChunkBytes = 8 * 1024 * 1024}); Future<void> download({required Uri url, required File destination, DownloadProgress? onProgress}); }`
  - Behavior: HEAD/Range to learn `Content-Length`; if server lacks range support (no `206`), single-stream into `destination`; otherwise parallel chunks concatenated into `destination`.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/chunked_downloader_test.dart`:

```dart
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late List<int> payload;
  late Directory tmp;
  late bool supportRange;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('cm_dl_');
    payload = List<int>.generate(50000, (i) => i % 256);
    supportRange = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (supportRange && range != null) {
        final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
        final start = int.parse(m.group(1)!);
        final end = m.group(2)!.isEmpty ? payload.length - 1 : int.parse(m.group(2)!);
        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers.set(HttpHeaders.contentLengthHeader, end - start + 1);
        req.response.add(payload.sublist(start, end + 1));
      } else {
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.set(HttpHeaders.contentLengthHeader, payload.length);
        req.response.add(payload);
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  Uri get url => Uri.parse('http://127.0.0.1:${server.port}/file.bin');

  test('parallel chunked download reproduces the payload', () async {
    final dest = File('${tmp.path}/out.bin');
    var lastFraction = 0.0;
    await ChunkedDownloader(chunkCount: 4, minChunkBytes: 1)
        .download(url: url, destination: dest, onProgress: (f, r, t) => lastFraction = f);
    expect(dest.readAsBytesSync(), equals(payload));
    expect(lastFraction, closeTo(1.0, 0.001));
  });

  test('falls back to single-stream when server ignores Range', () async {
    supportRange = false;
    final dest = File('${tmp.path}/out2.bin');
    await ChunkedDownloader(chunkCount: 4, minChunkBytes: 1)
        .download(url: url, destination: dest);
    expect(dest.readAsBytesSync(), equals(payload));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/chunked_downloader_test.dart`
Expected: FAIL — `ChunkedDownloader` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/binary/chunked_downloader.dart`:

```dart
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

typedef DownloadProgress = void Function(double fraction, int received, int total);

/// Downloads a file using parallel HTTP Range requests, falling back to a
/// single stream when the server does not honor `Range`.
class ChunkedDownloader {
  ChunkedDownloader({
    http.Client? client,
    this.chunkCount = 6,
    this.minChunkBytes = 8 * 1024 * 1024,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final int chunkCount;
  final int minChunkBytes;

  Future<void> download({
    required Uri url,
    required File destination,
    DownloadProgress? onProgress,
  }) async {
    final total = await _contentLength(url);
    await destination.parent.create(recursive: true);

    final canRange = total != null && total > 0 && await _supportsRange(url);
    if (!canRange) {
      await _singleStream(url, destination, total, onProgress);
      return;
    }

    final ranges = _computeRanges(total, chunkCount, minChunkBytes);
    final received = List<int>.filled(ranges.length, 0);
    final tmpDir = await destination.parent
        .createTemp('${destination.uri.pathSegments.last}-parts-');
    final partFiles = <File>[];

    void report() {
      if (onProgress == null) return;
      final sum = received.fold<int>(0, (a, b) => a + b);
      onProgress(sum / total, sum, total);
    }

    try {
      await Future.wait([
        for (var i = 0; i < ranges.length; i++)
          () async {
            final (start, end) = ranges[i];
            final part = File('${tmpDir.path}/part-$i');
            partFiles.add(part);
            final req = http.Request('GET', url)
              ..headers[HttpHeaders.rangeHeader] = 'bytes=$start-$end';
            final resp = await _client.send(req);
            final sink = part.openWrite();
            await for (final bytes in resp.stream) {
              sink.add(bytes);
              received[i] += bytes.length;
              report();
            }
            await sink.close();
          }(),
      ]);

      // Concatenate parts in order.
      final out = destination.openWrite();
      for (var i = 0; i < ranges.length; i++) {
        await out.addStream(File('${tmpDir.path}/part-$i').openRead());
      }
      await out.close();
    } finally {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    }
  }

  Future<int?> _contentLength(Uri url) async {
    final resp = await _client.head(url);
    final len = resp.headers[HttpHeaders.contentLengthHeader.toLowerCase()];
    return len == null ? null : int.tryParse(len);
  }

  Future<bool> _supportsRange(Uri url) async {
    final req = http.Request('GET', url)
      ..headers[HttpHeaders.rangeHeader] = 'bytes=0-0';
    final resp = await _client.send(req);
    await resp.stream.drain<void>();
    return resp.statusCode == HttpStatus.partialContent;
  }

  Future<void> _singleStream(
      Uri url, File dest, int? total, DownloadProgress? onProgress) async {
    final resp = await _client.send(http.Request('GET', url));
    final sink = dest.openWrite();
    var received = 0;
    await for (final bytes in resp.stream) {
      sink.add(bytes);
      received += bytes.length;
      if (onProgress != null && total != null && total > 0) {
        onProgress(received / total, received, total);
      }
    }
    await sink.close();
    if (onProgress != null && total != null && total > 0) {
      onProgress(1.0, total, total);
    }
  }

  static List<(int, int)> _computeRanges(int total, int chunkCount, int minChunk) {
    final count = ((total / minChunk).ceil()).clamp(1, chunkCount);
    final size = (total / count).ceil();
    final ranges = <(int, int)>[];
    for (var start = 0; start < total; start += size) {
      final end = (start + size - 1).clamp(0, total - 1);
      ranges.add((start, end));
    }
    return ranges;
  }
}
```

- [ ] **Step 4: Export + run + commit**

Add `export 'src/binary/chunked_downloader.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/chunked_downloader_test.dart`
Expected: `+2: All tests passed!`

```bash
git add packages/cloak_core/lib/src/binary/chunked_downloader.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/chunked_downloader_test.dart
git commit -m "feat(cloak_core): add parallel chunked downloader with single-stream fallback"
```

---

### Task 8: ArchiveExtractor

**Files:**
- Create: `packages/cloak_core/lib/src/binary/archive_extractor.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/archive_extractor_test.dart`

**Interfaces:**
- Produces: `class ArchiveExtractor` with `static Future<void> extract({required File archive, required Directory destination})` — handles `.tar.gz`/`.tgz` and `.zip` (by extension); preserves unix exec bits for tar entries.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/archive_extractor_test.dart`:

```dart
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cm_arc_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('extracts a .zip into destination', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('dir/hello.txt', 5, 'hello'.codeUnits));
    final zipBytes = ZipEncoder().encode(archive)!;
    final zip = File('${tmp.path}/a.zip')..writeAsBytesSync(zipBytes);
    final dest = Directory('${tmp.path}/out');

    await ArchiveExtractor.extract(archive: zip, destination: dest);

    expect(File('${dest.path}/dir/hello.txt').readAsStringSync(), 'hello');
  });

  test('extracts a .tar.gz into destination', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('bin/run', 3, 'abc'.codeUnits));
    final tarBytes = TarEncoder().encode(archive);
    final gz = GZipEncoder().encode(tarBytes)!;
    final tgz = File('${tmp.path}/a.tar.gz')..writeAsBytesSync(gz);
    final dest = Directory('${tmp.path}/out2');

    await ArchiveExtractor.extract(archive: tgz, destination: dest);

    expect(File('${dest.path}/bin/run').readAsStringSync(), 'abc');
  });

  test('unsupported extension throws', () {
    final f = File('${tmp.path}/a.rar')..writeAsBytesSync([0]);
    expect(
      () => ArchiveExtractor.extract(archive: f, destination: tmp),
      throwsUnsupportedError,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/archive_extractor_test.dart`
Expected: FAIL — `ArchiveExtractor` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/binary/archive_extractor.dart`:

```dart
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// Extracts `.tar.gz`/`.tgz` and `.zip` archives to a directory.
class ArchiveExtractor {
  const ArchiveExtractor._();

  static Future<void> extract({
    required File archive,
    required Directory destination,
  }) async {
    final name = archive.path.toLowerCase();
    final bytes = await archive.readAsBytes();
    final Archive decoded;
    if (name.endsWith('.zip')) {
      decoded = ZipDecoder().decodeBytes(bytes);
    } else if (name.endsWith('.tar.gz') || name.endsWith('.tgz')) {
      decoded = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } else {
      throw UnsupportedError('Unsupported archive: ${archive.path}');
    }

    await destination.create(recursive: true);
    for (final entry in decoded) {
      final outPath = p.join(destination.path, entry.name);
      if (entry.isFile) {
        final f = File(outPath);
        await f.parent.create(recursive: true);
        await f.writeAsBytes(entry.content as List<int>);
        if (!Platform.isWindows && (entry.mode & 0x40) != 0) {
          // Owner-execute bit set in the archive → make executable.
          await Process.run('chmod', ['+x', outPath]);
        }
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
  }
}
```

- [ ] **Step 4: Export + run + commit**

Add `export 'src/binary/archive_extractor.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/archive_extractor_test.dart`
Expected: `+3: All tests passed!`

```bash
git add packages/cloak_core/lib/src/binary/archive_extractor.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/archive_extractor_test.dart
git commit -m "feat(cloak_core): add tar.gz/zip archive extractor"
```

---

### Task 9: BinaryManager orchestration

**Files:**
- Create: `packages/cloak_core/lib/src/binary/binary_manager.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/binary_manager_test.dart`

**Interfaces:**
- Consumes: `AppPaths`, `PlatformInfo`, `ReleaseInfo`, `BinaryManifest`, `InstalledVersion`, `ChunkedDownloader`, `Sha256Verifier`, `ArchiveExtractor`.
- Produces:
  - `class BinaryManager { BinaryManager({required AppPaths paths, required PlatformInfo platform, http.Client? client, ChunkedDownloader? downloader}); }`
  - `Future<BinaryManifest> loadManifest()` — reads `manifest.json`, migrating legacy `binary.json` if present.
  - `Future<void> saveManifest(BinaryManifest)`.
  - `String? executablePathFor(InstalledVersion)` — resolves the per-OS executable inside the version dir.
  - `Future<List<ReleaseInfo>> listReleases()` — GitHub API.
  - `Future<InstalledVersion> install(ReleaseInfo release, {DownloadProgress? onProgress})` — download asset + SHA256SUMS, verify, extract into `binaryVersionDir(version)`, return the registered `InstalledVersion` (caller adds it to the manifest).

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/binary_manager_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/binary_manager_test.dart`
Expected: FAIL — `BinaryManager` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/binary/binary_manager.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/installed_version.dart';
import '../models/release_info.dart';
import '../platform/platform_info.dart';
import '../storage/app_paths.dart';
import 'archive_extractor.dart';
import 'chunked_downloader.dart';
import 'sha256_verifier.dart';
import 'sha256sums.dart';

/// Orchestrates discovery, download, verification, extraction, and tracking
/// of CloakBrowser binaries.
class BinaryManager {
  BinaryManager({
    required this.paths,
    required this.platform,
    http.Client? client,
    ChunkedDownloader? downloader,
  })  : _client = client ?? http.Client(),
        _downloader = downloader ?? ChunkedDownloader(client: client);

  final AppPaths paths;
  final PlatformInfo platform;
  final http.Client _client;
  final ChunkedDownloader _downloader;

  static const releasesApi =
      'https://api.github.com/repos/CloakHQ/cloakbrowser/releases?per_page=10';

  Future<BinaryManifest> loadManifest() async {
    final manifestFile = paths.manifestFile;
    if (await manifestFile.exists()) {
      return BinaryManifest.fromJson(
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>);
    }
    final legacy = paths.legacyBinaryInfoFile;
    if (await legacy.exists()) {
      final migrated = BinaryManifest.fromLegacyBinaryInfo(
          jsonDecode(await legacy.readAsString()) as Map<String, dynamic>);
      await saveManifest(migrated);
      await legacy.delete();
      return migrated;
    }
    return BinaryManifest.empty();
  }

  Future<void> saveManifest(BinaryManifest manifest) async {
    await paths.baseDir.create(recursive: true);
    await paths.manifestFile
        .writeAsString(jsonEncode(manifest.toJson()), flush: true);
  }

  /// Absolute path to the launchable executable inside an installed version.
  String executablePathFor(InstalledVersion v) {
    final root = p.join(paths.baseDir.path, v.appPath);
    return switch (platform.os) {
      'macos' => p.join(root, 'Contents', 'MacOS', 'Chromium'),
      'windows' => p.join(root, 'chrome.exe'),
      _ => p.join(root, 'chrome'),
    };
  }

  Future<List<ReleaseInfo>> listReleases() async {
    final resp = await _client.get(Uri.parse(releasesApi),
        headers: {'Accept': 'application/vnd.github+json'});
    if (resp.statusCode != 200) {
      throw HttpException('GitHub API ${resp.statusCode}');
    }
    return ReleaseInfo.listFromJson(jsonDecode(resp.body) as List<dynamic>);
  }

  /// Downloads + verifies + extracts [release]'s platform asset. Returns the
  /// resulting [InstalledVersion]; the caller registers it in the manifest.
  Future<InstalledVersion> install(
    ReleaseInfo release, {
    DownloadProgress? onProgress,
  }) async {
    final asset = release.assetFor(platform);
    if (asset == null) {
      throw StateError('No asset for ${platform.os}/${platform.arch}');
    }
    final sumsAsset = release.sha256SumsAsset;
    if (sumsAsset == null) {
      throw StateError('Release ${release.tagName} has no SHA256SUMS');
    }

    await paths.downloadsDir.create(recursive: true);
    final archiveFile =
        File(p.join(paths.downloadsDir.path, asset.name));

    await _downloader.download(
      url: Uri.parse(asset.downloadUrl),
      destination: archiveFile,
      onProgress: onProgress,
    );

    // Fetch and check SHA-256.
    final sumsResp = await _client.get(Uri.parse(sumsAsset.downloadUrl));
    final expected = Sha256Sums.parse(sumsResp.body).hashFor(asset.name);
    if (expected == null) {
      throw StateError('SHA256SUMS missing entry for ${asset.name}');
    }
    if (!await Sha256Verifier.verify(archiveFile, expected)) {
      await archiveFile.delete();
      throw StateError('SHA-256 mismatch for ${asset.name}');
    }

    final versionDir = paths.binaryVersionDir(release.version);
    if (await versionDir.exists()) await versionDir.delete(recursive: true);
    await ArchiveExtractor.extract(
        archive: archiveFile, destination: versionDir);

    if (platform.os == 'macos') {
      await Process.run('xattr', ['-cr', versionDir.path]);
    }
    await archiveFile.delete();

    final appPath = _findAppPath(versionDir, release.version);
    return InstalledVersion(
      version: release.version,
      releaseTag: release.tagName,
      appPath: p.relative(appPath, from: paths.baseDir.path),
      sizeBytes: asset.size,
      sha256: expected,
      installedAt: DateTime.now().toUtc(),
    );
  }

  String _findAppPath(Directory versionDir, String version) {
    if (platform.os == 'macos') {
      // Find the *.app bundle (usually Chromium.app) at the top level.
      for (final e in versionDir.listSync()) {
        if (e is Directory && e.path.endsWith('.app')) return e.path;
      }
    }
    return versionDir.path;
  }
}
```

- [ ] **Step 4: Export + run + commit**

Add `export 'src/binary/binary_manager.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/binary_manager_test.dart`
Expected: `+3: All tests passed!`

- [ ] **Step 5: Full suite + analyzer**

Run: `cd packages/cloak_core && dart analyze && dart test`
Expected: `No issues found!` and all M1+M2 tests pass.

```bash
git add packages/cloak_core/lib/src/binary/binary_manager.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/binary_manager_test.dart
git commit -m "feat(cloak_core): add BinaryManager orchestration and manifest IO"
```

---

## Self-Review

- **Spec coverage:** download speed/resume (spec §4d) → Tasks 6,7; SHA-256 verify → Tasks 2,3,9; extraction → Task 8; multi-version manifest + migration → Tasks 5,9; release discovery + platform asset → Tasks 4,9; data dirs → Task 1; executable path per OS (needed by M3) → Task 9.
- **Placeholder scan:** none — every step has complete, compilable code and exact commands.
- **Type consistency:** `PlatformInfo(os:, arch:)` matches M1; `ReleaseInfo.assetFor`/`sha256SumsAsset`/`version` defined in Task 4 and consumed in Task 9; `DownloadProgress` typedef from Task 7 reused in Task 9; `BinaryManifest`/`InstalledVersion` from Task 5 used in Task 9; `AppPaths` getters from Task 1 used throughout.
