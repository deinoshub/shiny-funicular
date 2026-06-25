# M1 — cloak_core Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-Dart foundation of `cloak_core` — data models, stealth-arg generation, platform/asset detection, and port allocation — fully unit-tested with no Flutter, no network, and no process spawning.

**Architecture:** A standalone Dart package `packages/cloak_core` with no Flutter dependency. This milestone delivers the value types (`Profile`, `StealthConfig`, `ProxyConfig`, enums), the `StealthArgsBuilder` that maps a `StealthConfig` to CloakBrowser `--fingerprint-*` / `--proxy-*` flags, `PlatformInfo` for OS/arch→asset-name mapping, and `PortAllocator` for picking a free CDP port. Everything is deterministic and unit-testable with `dart test`.

**Tech Stack:** Dart 3.3+, `package:test`, `package:lints`. SDK libraries only (`dart:io`, `dart:ffi`). No third-party runtime dependencies in M1.

## Global Constraints

- Dart SDK floor: `>=3.3.0 <4.0.0` (Dart 3 switch-expressions and patterns are used).
- `cloak_core` MUST NOT import `package:flutter/*` — it is pure Dart.
- Stealth flags MUST match the upstream table verbatim (`--fingerprint-*` prefix), per `CloakBrowser/docs/STEALTH-FLAGS.md`.
- Brand default versions (verbatim): chrome `146.0.7680.177`, edge `146.0.7680.79`, opera `115.0.5322.68`, vivaldi `7.5.3735.44`.
- CloakBrowser release asset names (verbatim): `cloakbrowser-darwin-arm64.tar.gz`, `cloakbrowser-darwin-x64.tar.gz`, `cloakbrowser-windows-x64.zip`, `cloakbrowser-linux-x64.tar.gz`, `cloakbrowser-linux-arm64.tar.gz`.
- CDP port range: 9222–10222 inclusive.
- `StealthArgsBuilder` emits ONLY stealth/proxy flags. Manager-injected flags (`--user-data-dir`, `--remote-debugging-*`, etc.) are added later in M3 by `BrowserLauncher`, NOT here.

## File Structure

| File | Responsibility |
|---|---|
| `packages/cloak_core/pubspec.yaml` | Package manifest, SDK floor, dev deps |
| `packages/cloak_core/analysis_options.yaml` | Lints |
| `packages/cloak_core/lib/cloak_core.dart` | Barrel export of the public API |
| `packages/cloak_core/lib/src/models/enums.dart` | `SpoofPlatform`, `BrowserBrand`, `WebRtcIpPolicy`, `ProxyType` + brand default versions |
| `packages/cloak_core/lib/src/models/proxy_config.dart` | `ProxyConfig` value type + `serverString` + JSON |
| `packages/cloak_core/lib/src/models/stealth_config.dart` | `StealthConfig` value type + JSON |
| `packages/cloak_core/lib/src/models/profile.dart` | `Profile` value type + JSON |
| `packages/cloak_core/lib/src/stealth/stealth_args_builder.dart` | `StealthArgsBuilder.build(StealthConfig)` |
| `packages/cloak_core/lib/src/platform/platform_info.dart` | `PlatformInfo` OS/arch + `assetName()` + `current()` |
| `packages/cloak_core/lib/src/launcher/port_allocator.dart` | `PortAllocator.allocate()` |
| `packages/cloak_core/test/*` | One test file per unit |

---

### Task 1: Package scaffold

**Files:**
- Create: `packages/cloak_core/pubspec.yaml`
- Create: `packages/cloak_core/analysis_options.yaml`
- Create: `packages/cloak_core/lib/cloak_core.dart`
- Create: `packages/cloak_core/lib/src/version.dart`
- Test: `packages/cloak_core/test/scaffold_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: a working `dart test` harness; `cloakCoreVersion` (`String`) exported from `cloak_core.dart`.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/scaffold_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('package exposes a version string', () {
    expect(cloakCoreVersion, isNotEmpty);
  });
}
```

- [ ] **Step 2: Create the package manifest**

`packages/cloak_core/pubspec.yaml`:

```yaml
name: cloak_core
description: Pure-Dart core for CloakManager (stealth args, launcher, CDP, binary management).
publish_to: none
version: 0.1.0

environment:
  sdk: '>=3.3.0 <4.0.0'

dev_dependencies:
  test: ^1.25.0
  lints: ^4.0.0
```

`packages/cloak_core/analysis_options.yaml`:

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
```

- [ ] **Step 3: Create the library entrypoints**

`packages/cloak_core/lib/src/version.dart`:

```dart
/// Current version of the cloak_core package.
const String cloakCoreVersion = '0.1.0';
```

`packages/cloak_core/lib/cloak_core.dart`:

```dart
/// Pure-Dart core for CloakManager.
library;

export 'src/version.dart';
```

- [ ] **Step 4: Resolve dependencies and run the test**

Run: `cd packages/cloak_core && dart pub get && dart test test/scaffold_test.dart`
Expected: `+1: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add packages/cloak_core/pubspec.yaml packages/cloak_core/analysis_options.yaml packages/cloak_core/lib packages/cloak_core/test/scaffold_test.dart
git commit -m "feat(cloak_core): scaffold pure-Dart package with test harness"
```

---

### Task 2: Enums + brand default versions

**Files:**
- Create: `packages/cloak_core/lib/src/models/enums.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (add export)
- Test: `packages/cloak_core/test/enums_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum SpoofPlatform { auto, macos, windows, linux }`
  - `enum BrowserBrand { chrome, edge, opera, vivaldi }` with `String get defaultVersion`
  - `enum WebRtcIpPolicy { real, spoofAuto, spoofExplicit }`
  - `enum ProxyType { http, socks5 }`
  - Each enum's `.name` is its on-the-wire flag value (`macos`/`windows`/`linux`, `chrome`/`edge`/`opera`/`vivaldi`).

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/enums_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('enum names map to wire flag values', () {
    expect(SpoofPlatform.macos.name, 'macos');
    expect(SpoofPlatform.windows.name, 'windows');
    expect(SpoofPlatform.linux.name, 'linux');
    expect(BrowserBrand.chrome.name, 'chrome');
    expect(BrowserBrand.vivaldi.name, 'vivaldi');
  });

  test('brand default versions match the upstream table', () {
    expect(BrowserBrand.chrome.defaultVersion, '146.0.7680.177');
    expect(BrowserBrand.edge.defaultVersion, '146.0.7680.79');
    expect(BrowserBrand.opera.defaultVersion, '115.0.5322.68');
    expect(BrowserBrand.vivaldi.defaultVersion, '7.5.3735.44');
  });

  test('enums round-trip by name', () {
    expect(ProxyType.values.byName('socks5'), ProxyType.socks5);
    expect(WebRtcIpPolicy.values.byName('spoofAuto'), WebRtcIpPolicy.spoofAuto);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/enums_test.dart`
Expected: FAIL — `SpoofPlatform` / `BrowserBrand` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/models/enums.dart`:

```dart
/// Spoofed OS reported by CloakBrowser. `auto` means "let the binary decide"
/// (the `--fingerprint-platform` flag is omitted).
enum SpoofPlatform { auto, macos, windows, linux }

/// Browser brand spoofed in the User-Agent and Client Hints.
enum BrowserBrand { chrome, edge, opera, vivaldi }

extension BrowserBrandDefaults on BrowserBrand {
  /// Default brand version used when `StealthConfig.brandVersion` is null.
  String get defaultVersion => switch (this) {
        BrowserBrand.chrome => '146.0.7680.177',
        BrowserBrand.edge => '146.0.7680.79',
        BrowserBrand.opera => '115.0.5322.68',
        BrowserBrand.vivaldi => '7.5.3735.44',
      };
}

/// WebRTC IP exposure policy.
enum WebRtcIpPolicy { real, spoofAuto, spoofExplicit }

/// Proxy transport.
enum ProxyType { http, socks5 }
```

- [ ] **Step 4: Export it**

In `packages/cloak_core/lib/cloak_core.dart`, add under the existing export:

```dart
export 'src/models/enums.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/cloak_core && dart test test/enums_test.dart`
Expected: `+3: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add packages/cloak_core/lib/src/models/enums.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/enums_test.dart
git commit -m "feat(cloak_core): add stealth/proxy enums and brand default versions"
```

---

### Task 3: ProxyConfig

**Files:**
- Create: `packages/cloak_core/lib/src/models/proxy_config.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (add export)
- Test: `packages/cloak_core/test/proxy_config_test.dart`

**Interfaces:**
- Consumes: `ProxyType` from `enums.dart`.
- Produces:
  - `class ProxyConfig` with final fields: `bool enabled`, `ProxyType type`, `String host`, `int port`, `String? username`, `String? password`, `String bypassList`, `bool geoipEnabled`.
  - `String get serverString` → `<scheme>://[user:pass@]host:port`.
  - `factory ProxyConfig.disabled()`.
  - `Map<String, dynamic> toJson()` / `factory ProxyConfig.fromJson(Map<String, dynamic>)`.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/proxy_config_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('serverString builds http URL without auth', () {
    const p = ProxyConfig(
      enabled: true,
      type: ProxyType.http,
      host: 'proxy.example.com',
      port: 8080,
    );
    expect(p.serverString, 'http://proxy.example.com:8080');
  });

  test('serverString builds socks5 URL with auth', () {
    const p = ProxyConfig(
      enabled: true,
      type: ProxyType.socks5,
      host: 'proxy.example.com',
      port: 1080,
      username: 'user',
      password: 'pass',
    );
    expect(p.serverString, 'socks5://user:pass@proxy.example.com:1080');
  });

  test('disabled() factory yields a disabled config', () {
    final p = ProxyConfig.disabled();
    expect(p.enabled, isFalse);
    expect(p.type, ProxyType.http);
  });

  test('JSON round-trips', () {
    const p = ProxyConfig(
      enabled: true,
      type: ProxyType.socks5,
      host: 'h',
      port: 1,
      username: 'u',
      password: 'p',
      bypassList: 'localhost,127.0.0.1',
      geoipEnabled: true,
    );
    expect(ProxyConfig.fromJson(p.toJson()), equals(p));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/proxy_config_test.dart`
Expected: FAIL — `ProxyConfig` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/models/proxy_config.dart`:

```dart
import 'enums.dart';

/// Per-profile proxy settings. Maps to `--proxy-server` / `--proxy-bypass-list`.
class ProxyConfig {
  const ProxyConfig({
    required this.enabled,
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.bypassList = '',
    this.geoipEnabled = false,
  });

  final bool enabled;
  final ProxyType type;
  final String host;
  final int port;
  final String? username;
  final String? password;

  /// Comma-separated hosts that bypass the proxy (Chrome `--proxy-bypass-list` syntax).
  final String bypassList;

  /// When true, the binary resolves the proxy exit IP to auto-set timezone/locale.
  final bool geoipEnabled;

  factory ProxyConfig.disabled() => const ProxyConfig(
        enabled: false,
        type: ProxyType.http,
        host: '',
        port: 0,
      );

  /// `<scheme>://[user:pass@]host:port` for `--proxy-server`.
  String get serverString {
    final scheme = type == ProxyType.socks5 ? 'socks5' : 'http';
    final hasAuth = (username != null && username!.isNotEmpty);
    final auth = hasAuth ? '$username:${password ?? ''}@' : '';
    return '$scheme://$auth$host:$port';
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'type': type.name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'bypassList': bypassList,
        'geoipEnabled': geoipEnabled,
      };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
        enabled: json['enabled'] as bool,
        type: ProxyType.values.byName(json['type'] as String),
        host: json['host'] as String,
        port: json['port'] as int,
        username: json['username'] as String?,
        password: json['password'] as String?,
        bypassList: (json['bypassList'] as String?) ?? '',
        geoipEnabled: (json['geoipEnabled'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is ProxyConfig &&
      other.enabled == enabled &&
      other.type == type &&
      other.host == host &&
      other.port == port &&
      other.username == username &&
      other.password == password &&
      other.bypassList == bypassList &&
      other.geoipEnabled == geoipEnabled;

  @override
  int get hashCode => Object.hash(
        enabled, type, host, port, username, password, bypassList, geoipEnabled,
      );
}
```

- [ ] **Step 4: Export it**

In `packages/cloak_core/lib/cloak_core.dart`, add:

```dart
export 'src/models/proxy_config.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/cloak_core && dart test test/proxy_config_test.dart`
Expected: `+4: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add packages/cloak_core/lib/src/models/proxy_config.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/proxy_config_test.dart
git commit -m "feat(cloak_core): add ProxyConfig with serverString and JSON"
```

---

### Task 4: StealthConfig

**Files:**
- Create: `packages/cloak_core/lib/src/models/stealth_config.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (add export)
- Test: `packages/cloak_core/test/stealth_config_test.dart`

**Interfaces:**
- Consumes: `SpoofPlatform`, `BrowserBrand`, `WebRtcIpPolicy` from `enums.dart`; `ProxyConfig` from `proxy_config.dart`.
- Produces:
  - `class StealthConfig` with final fields: `String? fingerprintSeed`, `SpoofPlatform platform`, `BrowserBrand brand`, `String? brandVersion`, `String? platformVersion`, `int? hardwareConcurrency`, `int? deviceMemoryGB`, `int? screenWidth`, `int? screenHeight`, `String? timezone`, `String? locale`, `String? gpuVendor`, `String? gpuRenderer`, `bool noiseEnabled`, `int? storageQuotaMB`, `WebRtcIpPolicy webrtcIpPolicy`, `String? explicitWebRtcIp`, `ProxyConfig proxy`.
  - `factory StealthConfig.defaults()` (platform auto, brand chrome, noise on, webrtc real, proxy disabled).
  - `Map<String, dynamic> toJson()` / `factory StealthConfig.fromJson(Map<String, dynamic>)`.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/stealth_config_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('defaults() are sane', () {
    final s = StealthConfig.defaults();
    expect(s.platform, SpoofPlatform.auto);
    expect(s.brand, BrowserBrand.chrome);
    expect(s.noiseEnabled, isTrue);
    expect(s.webrtcIpPolicy, WebRtcIpPolicy.real);
    expect(s.proxy.enabled, isFalse);
  });

  test('JSON round-trips a fully-populated config', () {
    final s = StealthConfig(
      fingerprintSeed: 'seed-1',
      platform: SpoofPlatform.windows,
      brand: BrowserBrand.edge,
      brandVersion: '146.0.7680.79',
      platformVersion: '10.0',
      hardwareConcurrency: 16,
      deviceMemoryGB: 16,
      screenWidth: 2560,
      screenHeight: 1440,
      timezone: 'America/New_York',
      locale: 'en-US',
      gpuVendor: 'Google Inc. (NVIDIA)',
      gpuRenderer: 'ANGLE (NVIDIA, RTX 4070)',
      noiseEnabled: false,
      storageQuotaMB: 5000,
      webrtcIpPolicy: WebRtcIpPolicy.spoofExplicit,
      explicitWebRtcIp: '203.0.113.7',
      proxy: const ProxyConfig(
        enabled: true,
        type: ProxyType.http,
        host: 'h',
        port: 8080,
      ),
    );
    final decoded = StealthConfig.fromJson(s.toJson());
    expect(decoded.toJson(), equals(s.toJson()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/stealth_config_test.dart`
Expected: FAIL — `StealthConfig` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/models/stealth_config.dart`:

```dart
import 'enums.dart';
import 'proxy_config.dart';

/// Full per-profile stealth configuration. Serialized to the `stealth_json`
/// column and consumed by `StealthArgsBuilder`.
class StealthConfig {
  const StealthConfig({
    this.fingerprintSeed,
    this.platform = SpoofPlatform.auto,
    this.brand = BrowserBrand.chrome,
    this.brandVersion,
    this.platformVersion,
    this.hardwareConcurrency,
    this.deviceMemoryGB,
    this.screenWidth,
    this.screenHeight,
    this.timezone,
    this.locale,
    this.gpuVendor,
    this.gpuRenderer,
    this.noiseEnabled = true,
    this.storageQuotaMB,
    this.webrtcIpPolicy = WebRtcIpPolicy.real,
    this.explicitWebRtcIp,
    required this.proxy,
  });

  final String? fingerprintSeed;
  final SpoofPlatform platform;
  final BrowserBrand brand;
  final String? brandVersion;
  final String? platformVersion;
  final int? hardwareConcurrency;
  final int? deviceMemoryGB;
  final int? screenWidth;
  final int? screenHeight;
  final String? timezone;
  final String? locale;
  final String? gpuVendor;
  final String? gpuRenderer;
  final bool noiseEnabled;
  final int? storageQuotaMB;
  final WebRtcIpPolicy webrtcIpPolicy;
  final String? explicitWebRtcIp;
  final ProxyConfig proxy;

  factory StealthConfig.defaults() =>
      StealthConfig(proxy: ProxyConfig.disabled());

  Map<String, dynamic> toJson() => {
        'fingerprintSeed': fingerprintSeed,
        'platform': platform.name,
        'brand': brand.name,
        'brandVersion': brandVersion,
        'platformVersion': platformVersion,
        'hardwareConcurrency': hardwareConcurrency,
        'deviceMemoryGB': deviceMemoryGB,
        'screenWidth': screenWidth,
        'screenHeight': screenHeight,
        'timezone': timezone,
        'locale': locale,
        'gpuVendor': gpuVendor,
        'gpuRenderer': gpuRenderer,
        'noiseEnabled': noiseEnabled,
        'storageQuotaMB': storageQuotaMB,
        'webrtcIpPolicy': webrtcIpPolicy.name,
        'explicitWebRtcIp': explicitWebRtcIp,
        'proxy': proxy.toJson(),
      };

  factory StealthConfig.fromJson(Map<String, dynamic> json) => StealthConfig(
        fingerprintSeed: json['fingerprintSeed'] as String?,
        platform: SpoofPlatform.values.byName(json['platform'] as String),
        brand: BrowserBrand.values.byName(json['brand'] as String),
        brandVersion: json['brandVersion'] as String?,
        platformVersion: json['platformVersion'] as String?,
        hardwareConcurrency: json['hardwareConcurrency'] as int?,
        deviceMemoryGB: json['deviceMemoryGB'] as int?,
        screenWidth: json['screenWidth'] as int?,
        screenHeight: json['screenHeight'] as int?,
        timezone: json['timezone'] as String?,
        locale: json['locale'] as String?,
        gpuVendor: json['gpuVendor'] as String?,
        gpuRenderer: json['gpuRenderer'] as String?,
        noiseEnabled: (json['noiseEnabled'] as bool?) ?? true,
        storageQuotaMB: json['storageQuotaMB'] as int?,
        webrtcIpPolicy:
            WebRtcIpPolicy.values.byName(json['webrtcIpPolicy'] as String),
        explicitWebRtcIp: json['explicitWebRtcIp'] as String?,
        proxy: ProxyConfig.fromJson(json['proxy'] as Map<String, dynamic>),
      );
}
```

- [ ] **Step 4: Export it**

In `packages/cloak_core/lib/cloak_core.dart`, add:

```dart
export 'src/models/stealth_config.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/cloak_core && dart test test/stealth_config_test.dart`
Expected: `+2: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add packages/cloak_core/lib/src/models/stealth_config.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/stealth_config_test.dart
git commit -m "feat(cloak_core): add StealthConfig with defaults and JSON"
```

---

### Task 5: Profile

**Files:**
- Create: `packages/cloak_core/lib/src/models/profile.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (add export)
- Test: `packages/cloak_core/test/profile_test.dart`

**Interfaces:**
- Consumes: `StealthConfig`.
- Produces:
  - `class Profile` with final fields: `String id`, `String name`, `String notes`, `String colorHex`, `String iconName`, `String? groupName`, `DateTime createdAt`, `DateTime updatedAt`, `DateTime? lastLaunchedAt`, `StealthConfig stealth`, `bool persistent`, `String startUrl`, `List<String> customArgs`, `Map<String, String> customEnv`, `List<String> tags`, `int sortOrder`.
  - `Map<String, dynamic> toJson()` / `factory Profile.fromJson(Map<String, dynamic>)` (DateTimes as ISO-8601 strings).

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/profile_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  Profile sample() => Profile(
        id: 'abc-123',
        name: 'Work',
        colorHex: '#5E81F4',
        iconName: 'person',
        createdAt: DateTime.utc(2026, 6, 25, 12),
        updatedAt: DateTime.utc(2026, 6, 25, 12),
        stealth: StealthConfig.defaults(),
        startUrl: 'https://example.com',
        customArgs: const ['--mute-audio'],
        customEnv: const {'TZ': 'UTC'},
        tags: const ['work', 'us'],
        sortOrder: 3,
      );

  test('JSON round-trips including nested stealth', () {
    final p = sample();
    final decoded = Profile.fromJson(p.toJson());
    expect(decoded.toJson(), equals(p.toJson()));
  });

  test('dates serialize as ISO-8601', () {
    final json = sample().toJson();
    expect(json['createdAt'], '2026-06-25T12:00:00.000Z');
    expect(json['lastLaunchedAt'], isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/profile_test.dart`
Expected: FAIL — `Profile` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/models/profile.dart`:

```dart
import 'stealth_config.dart';

/// A managed CloakBrowser profile. Mirrors the `profiles` table.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.notes = '',
    required this.colorHex,
    required this.iconName,
    this.groupName,
    required this.createdAt,
    required this.updatedAt,
    this.lastLaunchedAt,
    required this.stealth,
    this.persistent = true,
    this.startUrl = 'about:blank',
    this.customArgs = const [],
    this.customEnv = const {},
    this.tags = const [],
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String notes;
  final String colorHex;
  final String iconName;
  final String? groupName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLaunchedAt;
  final StealthConfig stealth;
  final bool persistent;
  final String startUrl;
  final List<String> customArgs;
  final Map<String, String> customEnv;
  final List<String> tags;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
        'colorHex': colorHex,
        'iconName': iconName,
        'groupName': groupName,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'lastLaunchedAt': lastLaunchedAt?.toUtc().toIso8601String(),
        'stealth': stealth.toJson(),
        'persistent': persistent,
        'startUrl': startUrl,
        'customArgs': customArgs,
        'customEnv': customEnv,
        'tags': tags,
        'sortOrder': sortOrder,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        notes: (json['notes'] as String?) ?? '',
        colorHex: json['colorHex'] as String,
        iconName: json['iconName'] as String,
        groupName: json['groupName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        lastLaunchedAt: json['lastLaunchedAt'] == null
            ? null
            : DateTime.parse(json['lastLaunchedAt'] as String),
        stealth:
            StealthConfig.fromJson(json['stealth'] as Map<String, dynamic>),
        persistent: (json['persistent'] as bool?) ?? true,
        startUrl: (json['startUrl'] as String?) ?? 'about:blank',
        customArgs:
            (json['customArgs'] as List<dynamic>? ?? []).cast<String>(),
        customEnv: (json['customEnv'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as String)),
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
        sortOrder: (json['sortOrder'] as int?) ?? 0,
      );
}
```

- [ ] **Step 4: Export it**

In `packages/cloak_core/lib/cloak_core.dart`, add:

```dart
export 'src/models/profile.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/cloak_core && dart test test/profile_test.dart`
Expected: `+2: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add packages/cloak_core/lib/src/models/profile.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/profile_test.dart
git commit -m "feat(cloak_core): add Profile model with JSON"
```

---

### Task 6: PlatformInfo

**Files:**
- Create: `packages/cloak_core/lib/src/platform/platform_info.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (add export)
- Test: `packages/cloak_core/test/platform_info_test.dart`

**Interfaces:**
- Consumes: nothing (uses `dart:ffi` `Abi` only inside `current()`).
- Produces:
  - `class PlatformInfo` with `final String os` (`macos`/`windows`/`linux`) and `final String arch` (`arm64`/`x64`).
  - `String assetName()` → the CloakBrowser release asset filename.
  - `static PlatformInfo current()` derived from `Abi.current()`.
  - Throws `UnsupportedError` for unsupported combos (e.g. `windows`+`arm64`).

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/platform_info_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/platform_info_test.dart`
Expected: FAIL — `PlatformInfo` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/platform/platform_info.dart`:

```dart
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
```

- [ ] **Step 4: Export it**

In `packages/cloak_core/lib/cloak_core.dart`, add:

```dart
export 'src/platform/platform_info.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/cloak_core && dart test test/platform_info_test.dart`
Expected: `+3: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add packages/cloak_core/lib/src/platform/platform_info.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/platform_info_test.dart
git commit -m "feat(cloak_core): add PlatformInfo with asset-name mapping"
```

---

### Task 7: StealthArgsBuilder

**Files:**
- Create: `packages/cloak_core/lib/src/stealth/stealth_args_builder.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (add export)
- Test: `packages/cloak_core/test/stealth_args_builder_test.dart`

**Interfaces:**
- Consumes: `StealthConfig`, `SpoofPlatform`, `BrowserBrand`, `WebRtcIpPolicy`, `ProxyType`, `ProxyConfig`.
- Produces: `class StealthArgsBuilder` with `static List<String> build(StealthConfig config)`. Emits ONLY stealth/proxy flags (no manager-injected flags).

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/stealth_args_builder_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('defaults emit only the always-present brand flag', () {
    final args = StealthArgsBuilder.build(StealthConfig.defaults());
    expect(args, ['--fingerprint-brand=chrome']);
  });

  test('null seed is omitted; set seed is emitted', () {
    final withSeed = StealthArgsBuilder.build(
      StealthConfig(fingerprintSeed: 'abc', proxy: ProxyConfig.disabled()),
    );
    expect(withSeed, contains('--fingerprint=abc'));
  });

  test('auto platform is omitted; explicit platform is emitted', () {
    final auto = StealthArgsBuilder.build(StealthConfig.defaults());
    expect(auto.any((a) => a.startsWith('--fingerprint-platform')), isFalse);

    final win = StealthArgsBuilder.build(
      StealthConfig(platform: SpoofPlatform.windows, proxy: ProxyConfig.disabled()),
    );
    expect(win, contains('--fingerprint-platform=windows'));
  });

  test('noise flag only emitted when disabled', () {
    final on = StealthArgsBuilder.build(StealthConfig.defaults());
    expect(on.any((a) => a.startsWith('--fingerprint-noise')), isFalse);

    final off = StealthArgsBuilder.build(
      StealthConfig(noiseEnabled: false, proxy: ProxyConfig.disabled()),
    );
    expect(off, contains('--fingerprint-noise=false'));
  });

  test('webrtc policy maps correctly', () {
    expect(
      StealthArgsBuilder.build(StealthConfig.defaults())
          .any((a) => a.startsWith('--fingerprint-webrtc-ip')),
      isFalse,
    );
    expect(
      StealthArgsBuilder.build(StealthConfig(
        webrtcIpPolicy: WebRtcIpPolicy.spoofAuto,
        proxy: ProxyConfig.disabled(),
      )),
      contains('--fingerprint-webrtc-ip=auto'),
    );
    expect(
      StealthArgsBuilder.build(StealthConfig(
        webrtcIpPolicy: WebRtcIpPolicy.spoofExplicit,
        explicitWebRtcIp: '203.0.113.7',
        proxy: ProxyConfig.disabled(),
      )),
      contains('--fingerprint-webrtc-ip=203.0.113.7'),
    );
  });

  test('enabled proxy emits server and bypass flags', () {
    final args = StealthArgsBuilder.build(StealthConfig(
      proxy: const ProxyConfig(
        enabled: true,
        type: ProxyType.http,
        host: 'proxy.example.com',
        port: 8080,
        bypassList: 'localhost,127.0.0.1',
      ),
    ));
    expect(args, contains('--proxy-server=http://proxy.example.com:8080'));
    expect(args, contains('--proxy-bypass-list=localhost,127.0.0.1'));
  });

  test('full config produces the worked-example flag set', () {
    final args = StealthArgsBuilder.build(StealthConfig(
      fingerprintSeed: 'work-us-east-2026',
      platform: SpoofPlatform.windows,
      brand: BrowserBrand.chrome,
      brandVersion: '146.0.7680.177',
      hardwareConcurrency: 16,
      deviceMemoryGB: 16,
      screenWidth: 2560,
      screenHeight: 1440,
      timezone: 'America/New_York',
      locale: 'en-US',
      gpuVendor: 'Google Inc. (NVIDIA)',
      gpuRenderer: 'ANGLE (NVIDIA, RTX 4070)',
      webrtcIpPolicy: WebRtcIpPolicy.spoofAuto,
      proxy: const ProxyConfig(
        enabled: true,
        type: ProxyType.http,
        host: 'residential-proxy-us-east',
        port: 8080,
      ),
    ));
    expect(args, containsAll(<String>[
      '--fingerprint=work-us-east-2026',
      '--fingerprint-platform=windows',
      '--fingerprint-brand=chrome',
      '--fingerprint-brand-version=146.0.7680.177',
      '--fingerprint-hardware-concurrency=16',
      '--fingerprint-device-memory=16',
      '--fingerprint-screen-width=2560',
      '--fingerprint-screen-height=1440',
      '--fingerprint-timezone=America/New_York',
      '--fingerprint-locale=en-US',
      '--fingerprint-gpu-vendor=Google Inc. (NVIDIA)',
      '--fingerprint-gpu-renderer=ANGLE (NVIDIA, RTX 4070)',
      '--fingerprint-webrtc-ip=auto',
      '--proxy-server=http://residential-proxy-us-east:8080',
    ]));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/stealth_args_builder_test.dart`
Expected: FAIL — `StealthArgsBuilder` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/stealth/stealth_args_builder.dart`:

```dart
import '../models/enums.dart';
import '../models/stealth_config.dart';

/// Maps a [StealthConfig] to CloakBrowser `--fingerprint-*` / `--proxy-*`
/// flags. Emits ONLY stealth/proxy flags — manager-injected flags
/// (`--user-data-dir`, `--remote-debugging-*`, …) are added by the launcher.
class StealthArgsBuilder {
  const StealthArgsBuilder._();

  static List<String> build(StealthConfig c) {
    final args = <String>[];

    final seed = c.fingerprintSeed;
    if (seed != null && seed.isNotEmpty) {
      args.add('--fingerprint=$seed');
    }

    if (c.platform != SpoofPlatform.auto) {
      args.add('--fingerprint-platform=${c.platform.name}');
    }

    // Brand is always emitted (defaults to chrome).
    args.add('--fingerprint-brand=${c.brand.name}');
    if (c.brandVersion != null) {
      args.add('--fingerprint-brand-version=${c.brandVersion}');
    }
    if (c.platformVersion != null) {
      args.add('--fingerprint-platform-version=${c.platformVersion}');
    }

    _addIfNotNull(args, '--fingerprint-hardware-concurrency', c.hardwareConcurrency);
    _addIfNotNull(args, '--fingerprint-device-memory', c.deviceMemoryGB);
    _addIfNotNull(args, '--fingerprint-screen-width', c.screenWidth);
    _addIfNotNull(args, '--fingerprint-screen-height', c.screenHeight);
    _addIfNotNull(args, '--fingerprint-timezone', c.timezone);
    _addIfNotNull(args, '--fingerprint-locale', c.locale);
    _addIfNotNull(args, '--fingerprint-gpu-vendor', c.gpuVendor);
    _addIfNotNull(args, '--fingerprint-gpu-renderer', c.gpuRenderer);

    if (!c.noiseEnabled) {
      args.add('--fingerprint-noise=false');
    }
    _addIfNotNull(args, '--fingerprint-storage-quota', c.storageQuotaMB);

    switch (c.webrtcIpPolicy) {
      case WebRtcIpPolicy.real:
        break;
      case WebRtcIpPolicy.spoofAuto:
        args.add('--fingerprint-webrtc-ip=auto');
      case WebRtcIpPolicy.spoofExplicit:
        final ip = c.explicitWebRtcIp;
        if (ip != null && ip.isNotEmpty) {
          args.add('--fingerprint-webrtc-ip=$ip');
        }
    }

    if (c.proxy.enabled) {
      args.add('--proxy-server=${c.proxy.serverString}');
      if (c.proxy.bypassList.isNotEmpty) {
        args.add('--proxy-bypass-list=${c.proxy.bypassList}');
      }
    }

    return args;
  }

  static void _addIfNotNull(List<String> args, String flag, Object? value) {
    if (value != null) args.add('$flag=$value');
  }
}
```

- [ ] **Step 4: Export it**

In `packages/cloak_core/lib/cloak_core.dart`, add:

```dart
export 'src/stealth/stealth_args_builder.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/cloak_core && dart test test/stealth_args_builder_test.dart`
Expected: `+7: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add packages/cloak_core/lib/src/stealth/stealth_args_builder.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/stealth_args_builder_test.dart
git commit -m "feat(cloak_core): add StealthArgsBuilder mapping config to flags"
```

---

### Task 8: PortAllocator

**Files:**
- Create: `packages/cloak_core/lib/src/launcher/port_allocator.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (add export)
- Test: `packages/cloak_core/test/port_allocator_test.dart`

**Interfaces:**
- Consumes: `dart:io` `ServerSocket`.
- Produces:
  - `class PortAllocator` with `const PortAllocator({int start = 9222, int end = 10222})`.
  - `Future<int> allocate()` — binds `127.0.0.1` on the first free port in `[start, end]`; throws `StateError` if none free.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/port_allocator_test.dart`:

```dart
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('allocate returns a port within the range', () async {
    const alloc = PortAllocator(start: 9222, end: 10222);
    final port = await alloc.allocate();
    expect(port, inInclusiveRange(9222, 10222));
  });

  test('allocate skips a port already bound', () async {
    // Occupy the first port in a tiny range, expect the next one.
    final occupied = await ServerSocket.bind('127.0.0.1', 0);
    final p = occupied.port;
    final alloc = PortAllocator(start: p, end: p + 1);
    final got = await alloc.allocate();
    expect(got, p + 1);
    await occupied.close();
  });

  test('allocate throws when no port is free', () async {
    final occupied = await ServerSocket.bind('127.0.0.1', 0);
    final p = occupied.port;
    final alloc = PortAllocator(start: p, end: p);
    expect(alloc.allocate(), throwsStateError);
    await occupied.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/port_allocator_test.dart`
Expected: FAIL — `PortAllocator` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/launcher/port_allocator.dart`:

```dart
import 'dart:io';

/// Finds a free localhost TCP port for the Chromium remote-debugging endpoint.
class PortAllocator {
  const PortAllocator({this.start = 9222, this.end = 10222});

  final int start;
  final int end;

  /// Returns the first free port in `[start, end]`. Throws [StateError] if
  /// every port in the range is in use.
  Future<int> allocate() async {
    for (var port = start; port <= end; port++) {
      try {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
        await socket.close();
        return port;
      } on SocketException {
        continue;
      }
    }
    throw StateError('No free port in range $start-$end');
  }
}
```

- [ ] **Step 4: Export it**

In `packages/cloak_core/lib/cloak_core.dart`, add:

```dart
export 'src/launcher/port_allocator.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/cloak_core && dart test test/port_allocator_test.dart`
Expected: `+3: All tests passed!`

- [ ] **Step 6: Run the full suite + analyzer**

Run: `cd packages/cloak_core && dart analyze && dart test`
Expected: `No issues found!` and all tests pass across every test file.

- [ ] **Step 7: Commit**

```bash
git add packages/cloak_core/lib/src/launcher/port_allocator.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/port_allocator_test.dart
git commit -m "feat(cloak_core): add PortAllocator for CDP ports"
```

---

## Milestone roadmap (subsequent plans)

Each gets its own spec-referenced plan after M1 lands:

- **M2 — Binary management:** `ChunkedDownloader` (HTTP Range), `ResumeStore`, SHA-256 verify vs `SHA256SUMS`, archive extraction (`.tar.gz` / `.zip`), `manifest.json` multi-version model. Adds deps: `http`, `crypto`, `archive`.
- **M3 — Launcher + CDP:** `BrowserLauncher` (combines `StealthArgsBuilder` output + manager-injected flags + `Process.start`), `ProcessRegistry`, `CdpClient` (`web_socket_channel`).
- **M4 — Flutter shell + persistence:** Flutter app at repo root, Drift DB + `ProfileDao` + migrations, Riverpod providers, onboarding flow.
- **M5 — UI full parity:** sidebar (search/groups/status), 4-tab editor (General/Stealth/Proxy/Advanced + computed-args preview), settings (Versions/About), keyboard shortcuts.

## Self-Review

- **Spec coverage (M1 slice):** models (`Profile`/`StealthConfig`/`ProxyConfig`/enums) → Tasks 2–5; stealth flag mapping (spec §4a / STEALTH-FLAGS) → Task 7; platform→asset detection (spec §4d) → Task 6; port allocation (spec §4b) → Task 8. Binary/launcher/CDP/UI are intentionally deferred to M2–M5.
- **Placeholder scan:** none — every step has complete, compilable code and exact commands.
- **Type consistency:** `StealthConfig` field `webrtcIpPolicy` / `explicitWebRtcIp` used identically in Tasks 4 and 7; `ProxyConfig.serverString` defined in Task 3 and consumed in Task 7; `PlatformInfo(os:, arch:)` constructor used identically in Task 6 tests and impl. `StealthConfig.defaults()` requires `proxy`, satisfied via the internal `let` helper / `ProxyConfig.disabled()`.
