# M3 — Launcher + ProcessRegistry + CDP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete `cloak_core` by adding the ability to launch a profile's Chromium process with the full computed flag set, track running processes, and talk to each browser over the Chrome DevTools Protocol (CDP).

**Architecture:** Pure-Dart additions. `LaunchArgsComposer` combines `StealthArgsBuilder` output (M1) with the manager-injected flags and the start URL. `BrowserLauncher` resolves the user-data-dir (persistent vs ephemeral), allocates a CDP port (M1 `PortAllocator`), spawns the process via `Process.start`, discovers the CDP WebSocket endpoint, and registers it. `ProcessRegistry` tracks `pid → RunningProcess` and exposes a status stream. `CdpClient` is a minimal JSON-RPC-over-WebSocket client for the handful of CDP methods the manager uses.

**Tech Stack:** Dart 3.3+. New dep: `web_socket_channel`. Tests use `dart:io` `HttpServer` (mock `/json` discovery + WebSocket upgrade) and a tiny cross-platform stub executable script — no real Chromium.

## Global Constraints

- `cloak_core` stays pure Dart (no `package:flutter/*`).
- Manager-injected flags, in this exact order, appended AFTER stealth flags and BEFORE custom args + start URL: `--user-data-dir=<dir>`, `--remote-debugging-port=<port>`, `--remote-debugging-address=127.0.0.1`, `--no-default-browser-check`, `--no-first-run`, `--disable-background-mode`, `--disable-features=TranslateUI,InfiniteSessionRestore`.
- CDP discovery: `GET http://127.0.0.1:<port>/json/version` → `webSocketDebuggerUrl`; tabs via `GET http://127.0.0.1:<port>/json`.
- Persistent profile → `<dataDir>/profiles/<id>/`; ephemeral → a temp dir created per launch (caller/registry cleans up on stop).
- CDP methods used: `Browser.getVersion`, `Target.getTargets`, `Page.navigate`, `Target.activateTarget`.
- A profile is "running" while its process is alive; on process exit the registry marks it stopped and (for ephemeral) deletes the temp dir.

## File Structure

| File | Responsibility |
|---|---|
| `lib/src/launcher/launch_args_composer.dart` | Compose full arg list (stealth + injected + custom + url) |
| `lib/src/launcher/running_process.dart` | `RunningProcess` value/handle type |
| `lib/src/launcher/process_registry.dart` | Track running processes + status stream |
| `lib/src/launcher/browser_launcher.dart` | Resolve dirs, spawn, discover CDP, register |
| `lib/src/cdp/cdp_client.dart` | WebSocket JSON-RPC client |
| `lib/src/cdp/cdp_discovery.dart` | HTTP `/json` discovery helpers |
| `test/*` | One test file per unit |

---

### Task 1: LaunchArgsComposer

**Files:**
- Create: `packages/cloak_core/lib/src/launcher/launch_args_composer.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/launch_args_composer_test.dart`

**Interfaces:**
- Consumes: `Profile`, `StealthArgsBuilder` (M1).
- Produces: `class LaunchArgsComposer` with `static List<String> compose({required Profile profile, required String userDataDir, required int debugPort})`. Order: stealth flags, injected flags, `profile.customArgs`, then `profile.startUrl` (omitted when blank or `about:blank`? — include `about:blank` so a window always opens).

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/launch_args_composer_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  Profile profile({List<String> customArgs = const [], String startUrl = 'https://example.com'}) =>
      Profile(
        id: 'p1',
        name: 'P',
        colorHex: '#fff',
        iconName: 'person',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        stealth: StealthConfig(
          fingerprintSeed: 'seed',
          proxy: ProxyConfig.disabled(),
        ),
        startUrl: startUrl,
        customArgs: customArgs,
      );

  test('composes stealth + injected + custom + url in order', () {
    final args = LaunchArgsComposer.compose(
      profile: profile(customArgs: const ['--mute-audio']),
      userDataDir: '/data/profiles/p1',
      debugPort: 9333,
    );
    expect(args.first, '--fingerprint=seed');
    expect(args, containsAllInOrder(<String>[
      '--user-data-dir=/data/profiles/p1',
      '--remote-debugging-port=9333',
      '--remote-debugging-address=127.0.0.1',
      '--no-default-browser-check',
      '--no-first-run',
      '--disable-background-mode',
      '--disable-features=TranslateUI,InfiniteSessionRestore',
      '--mute-audio',
      'https://example.com',
    ]));
    expect(args.last, 'https://example.com');
  });

  test('about:blank is still included as start url', () {
    final args = LaunchArgsComposer.compose(
      profile: profile(startUrl: 'about:blank'),
      userDataDir: '/d',
      debugPort: 9222,
    );
    expect(args.last, 'about:blank');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/launch_args_composer_test.dart`
Expected: FAIL — `LaunchArgsComposer` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/launcher/launch_args_composer.dart`:

```dart
import '../models/profile.dart';
import '../stealth/stealth_args_builder.dart';

/// Builds the full Chromium argument vector for launching a profile.
class LaunchArgsComposer {
  const LaunchArgsComposer._();

  static List<String> compose({
    required Profile profile,
    required String userDataDir,
    required int debugPort,
  }) {
    return [
      ...StealthArgsBuilder.build(profile.stealth),
      '--user-data-dir=$userDataDir',
      '--remote-debugging-port=$debugPort',
      '--remote-debugging-address=127.0.0.1',
      '--no-default-browser-check',
      '--no-first-run',
      '--disable-background-mode',
      '--disable-features=TranslateUI,InfiniteSessionRestore',
      ...profile.customArgs,
      if (profile.startUrl.isNotEmpty) profile.startUrl,
    ];
  }
}
```

- [ ] **Step 4: Export + run + commit**

Add `export 'src/launcher/launch_args_composer.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/launch_args_composer_test.dart`
Expected: `+2: All tests passed!`

```bash
git add packages/cloak_core/lib/src/launcher/launch_args_composer.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/launch_args_composer_test.dart
git commit -m "feat(cloak_core): add LaunchArgsComposer for full launch argv"
```

---

### Task 2: RunningProcess + ProcessRegistry

**Files:**
- Create: `packages/cloak_core/lib/src/launcher/running_process.dart`
- Create: `packages/cloak_core/lib/src/launcher/process_registry.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (exports)
- Test: `packages/cloak_core/test/process_registry_test.dart`

**Interfaces:**
- Produces:
  - `class RunningProcess { final String profileId; final int pid; final int debugPort; final String cdpHttpUrl; final bool ephemeral; final String userDataDir; }`
  - `class ProcessRegistry { void add(RunningProcess); RunningProcess? byProfile(String profileId); List<RunningProcess> get all; bool isRunning(String profileId); void remove(String profileId); Stream<Set<String>> get runningProfileIds; void dispose(); }` — `runningProfileIds` emits the set of running profile IDs on every add/remove.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/process_registry_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  RunningProcess proc(String id, int pid) => RunningProcess(
        profileId: id,
        pid: pid,
        debugPort: 9222,
        cdpHttpUrl: 'http://127.0.0.1:9222',
        ephemeral: false,
        userDataDir: '/d/$id',
      );

  test('add/byProfile/isRunning/remove', () {
    final reg = ProcessRegistry();
    expect(reg.isRunning('a'), isFalse);
    reg.add(proc('a', 1));
    expect(reg.isRunning('a'), isTrue);
    expect(reg.byProfile('a')?.pid, 1);
    reg.remove('a');
    expect(reg.isRunning('a'), isFalse);
    reg.dispose();
  });

  test('runningProfileIds stream reflects changes', () async {
    final reg = ProcessRegistry();
    final emissions = <Set<String>>[];
    final sub = reg.runningProfileIds.listen(emissions.add);
    reg.add(proc('a', 1));
    reg.add(proc('b', 2));
    reg.remove('a');
    await Future<void>.delayed(Duration.zero);
    expect(emissions.last, {'b'});
    await sub.cancel();
    reg.dispose();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/process_registry_test.dart`
Expected: FAIL — `ProcessRegistry` undefined.

- [ ] **Step 3: Write the implementations**

`packages/cloak_core/lib/src/launcher/running_process.dart`:

```dart
/// A live browser process launched for a profile.
class RunningProcess {
  const RunningProcess({
    required this.profileId,
    required this.pid,
    required this.debugPort,
    required this.cdpHttpUrl,
    required this.ephemeral,
    required this.userDataDir,
  });

  final String profileId;
  final int pid;
  final int debugPort;
  final String cdpHttpUrl; // e.g. http://127.0.0.1:9333
  final bool ephemeral;
  final String userDataDir;
}
```

`packages/cloak_core/lib/src/launcher/process_registry.dart`:

```dart
import 'dart:async';
import 'running_process.dart';

/// Tracks running browser processes keyed by profile id.
class ProcessRegistry {
  final Map<String, RunningProcess> _byProfile = {};
  final StreamController<Set<String>> _controller =
      StreamController<Set<String>>.broadcast();

  void add(RunningProcess process) {
    _byProfile[process.profileId] = process;
    _emit();
  }

  RunningProcess? byProfile(String profileId) => _byProfile[profileId];

  List<RunningProcess> get all => List.unmodifiable(_byProfile.values);

  bool isRunning(String profileId) => _byProfile.containsKey(profileId);

  void remove(String profileId) {
    if (_byProfile.remove(profileId) != null) _emit();
  }

  Stream<Set<String>> get runningProfileIds => _controller.stream;

  void _emit() => _controller.add(_byProfile.keys.toSet());

  void dispose() => _controller.close();
}
```

- [ ] **Step 4: Export + run + commit**

Add to `cloak_core.dart`:

```dart
export 'src/launcher/running_process.dart';
export 'src/launcher/process_registry.dart';
```

Run: `cd packages/cloak_core && dart test test/process_registry_test.dart`
Expected: `+2: All tests passed!`

```bash
git add packages/cloak_core/lib/src/launcher/running_process.dart packages/cloak_core/lib/src/launcher/process_registry.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/process_registry_test.dart
git commit -m "feat(cloak_core): add RunningProcess and ProcessRegistry"
```

---

### Task 3: CdpDiscovery

**Files:**
- Create: `packages/cloak_core/lib/src/cdp/cdp_discovery.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/cdp_discovery_test.dart`

**Interfaces:**
- Produces:
  - `class CdpTarget { final String targetId; final String type; final String title; final String url; final String? webSocketDebuggerUrl; }` + `fromJson`.
  - `class CdpDiscovery { CdpDiscovery({http.Client? client}); Future<String> browserWebSocketUrl(String httpBase); Future<List<CdpTarget>> targets(String httpBase); Future<bool> waitUntilReady(String httpBase, {Duration timeout, Duration interval}); }`

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/cdp_discovery_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path == '/json/version') {
        req.response.write(jsonEncode({
          'Browser': 'Chrome/146',
          'webSocketDebuggerUrl': 'ws://127.0.0.1:${server.port}/devtools/browser/abc',
        }));
      } else if (req.uri.path == '/json') {
        req.response.write(jsonEncode([
          {
            'id': 't1',
            'type': 'page',
            'title': 'Example',
            'url': 'https://example.com',
            'webSocketDebuggerUrl': 'ws://127.0.0.1:${server.port}/devtools/page/t1',
          }
        ]));
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  String get base => 'http://127.0.0.1:${server.port}';

  test('browserWebSocketUrl reads /json/version', () async {
    final url = await CdpDiscovery().browserWebSocketUrl(base);
    expect(url, contains('/devtools/browser/abc'));
  });

  test('targets reads /json', () async {
    final targets = await CdpDiscovery().targets(base);
    expect(targets.single.title, 'Example');
    expect(targets.single.type, 'page');
  });

  test('waitUntilReady returns true when reachable', () async {
    expect(
      await CdpDiscovery().waitUntilReady(base,
          timeout: const Duration(seconds: 2)),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/cdp_discovery_test.dart`
Expected: FAIL — `CdpDiscovery` undefined.

- [ ] **Step 3: Write the implementation**

`packages/cloak_core/lib/src/cdp/cdp_discovery.dart`:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class CdpTarget {
  const CdpTarget({
    required this.targetId,
    required this.type,
    required this.title,
    required this.url,
    this.webSocketDebuggerUrl,
  });

  final String targetId;
  final String type;
  final String title;
  final String url;
  final String? webSocketDebuggerUrl;

  factory CdpTarget.fromJson(Map<String, dynamic> j) => CdpTarget(
        targetId: (j['id'] ?? j['targetId'] ?? '') as String,
        type: (j['type'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        webSocketDebuggerUrl: j['webSocketDebuggerUrl'] as String?,
      );
}

/// Reads the Chromium remote-debugging HTTP endpoints (`/json/*`).
class CdpDiscovery {
  CdpDiscovery({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<String> browserWebSocketUrl(String httpBase) async {
    final resp = await _client.get(Uri.parse('$httpBase/json/version'));
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = json['webSocketDebuggerUrl'] as String?;
    if (url == null) {
      throw StateError('No webSocketDebuggerUrl at $httpBase/json/version');
    }
    return url;
  }

  Future<List<CdpTarget>> targets(String httpBase) async {
    final resp = await _client.get(Uri.parse('$httpBase/json'));
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .map((e) => CdpTarget.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> waitUntilReady(
    String httpBase, {
    Duration timeout = const Duration(seconds: 20),
    Duration interval = const Duration(milliseconds: 200),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        await browserWebSocketUrl(httpBase);
        return true;
      } catch (_) {
        await Future<void>.delayed(interval);
      }
    }
    return false;
  }
}
```

- [ ] **Step 4: Export + run + commit**

Add `export 'src/cdp/cdp_discovery.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/cdp_discovery_test.dart`
Expected: `+3: All tests passed!`

```bash
git add packages/cloak_core/lib/src/cdp/cdp_discovery.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/cdp_discovery_test.dart
git commit -m "feat(cloak_core): add CDP HTTP discovery (/json endpoints)"
```

---

### Task 4: CdpClient

**Files:**
- Modify: `packages/cloak_core/pubspec.yaml` (add `web_socket_channel`)
- Create: `packages/cloak_core/lib/src/cdp/cdp_client.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/cdp_client_test.dart`

**Interfaces:**
- Produces:
  - `class CdpClient { CdpClient(this.webSocketUrl); Future<void> connect(); Future<Map<String, dynamic>> send(String method, [Map<String, dynamic>? params]); Future<void> close(); }`
  - Convenience: `Future<Map<String,dynamic>> getBrowserVersion()`, `Future<void> navigate(String url)`, `Future<void> activateTarget(String targetId)`.
  - JSON-RPC: each `send` assigns an incrementing `id`, resolves when the matching `{id, result}` arrives (or throws on `{id, error}`).

- [ ] **Step 1: Add dep**

In `packages/cloak_core/pubspec.yaml` `dependencies:`, add:

```yaml
  web_socket_channel: ^3.0.0
```

Run: `cd packages/cloak_core && dart pub get`
Expected: resolves cleanly.

- [ ] **Step 2: Write the failing test**

`packages/cloak_core/test/cdp_client_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final socket = await WebSocketTransformer.upgrade(req);
      socket.listen((data) {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        final id = msg['id'];
        final method = msg['method'];
        if (method == 'Browser.getVersion') {
          socket.add(jsonEncode({'id': id, 'result': {'product': 'Chrome/146'}}));
        } else if (method == 'Page.navigate') {
          socket.add(jsonEncode({'id': id, 'result': {'frameId': 'f1'}}));
        } else {
          socket.add(jsonEncode({'id': id, 'error': {'message': 'unknown'}}));
        }
      });
    });
  });
  tearDown(() => server.close(force: true));

  String get wsUrl => 'ws://127.0.0.1:${server.port}/devtools/browser/abc';

  test('send resolves matching result', () async {
    final client = CdpClient(wsUrl);
    await client.connect();
    final result = await client.getBrowserVersion();
    expect(result['product'], 'Chrome/146');
    await client.close();
  });

  test('navigate sends Page.navigate', () async {
    final client = CdpClient(wsUrl);
    await client.connect();
    await client.navigate('https://example.com'); // resolves without throwing
    await client.close();
  });

  test('unknown method surfaces the error', () async {
    final client = CdpClient(wsUrl);
    await client.connect();
    expect(client.send('Bogus.method'), throwsA(isA<CdpException>()));
    await client.close();
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/cdp_client_test.dart`
Expected: FAIL — `CdpClient` undefined.

- [ ] **Step 4: Write the implementation**

`packages/cloak_core/lib/src/cdp/cdp_client.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class CdpException implements Exception {
  CdpException(this.message);
  final String message;
  @override
  String toString() => 'CdpException: $message';
}

/// Minimal Chrome DevTools Protocol client over a WebSocket.
class CdpClient {
  CdpClient(this.webSocketUrl);

  final String webSocketUrl;
  WebSocketChannel? _channel;
  int _nextId = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  Future<void> connect() async {
    final channel = WebSocketChannel.connect(Uri.parse(webSocketUrl));
    await channel.ready;
    _channel = channel;
    channel.stream.listen(
      _onMessage,
      onDone: _failAllPending,
      onError: (_) => _failAllPending(),
    );
  }

  void _onMessage(dynamic data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    final id = msg['id'];
    if (id is! int) return; // event, not a command reply
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (msg.containsKey('error')) {
      final err = msg['error'] as Map<String, dynamic>;
      completer.completeError(CdpException(err['message']?.toString() ?? 'error'));
    } else {
      completer.complete((msg['result'] as Map<String, dynamic>?) ?? {});
    }
  }

  void _failAllPending() {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(CdpException('connection closed'));
    }
    _pending.clear();
  }

  Future<Map<String, dynamic>> send(String method,
      [Map<String, dynamic>? params]) {
    final channel = _channel;
    if (channel == null) throw CdpException('not connected');
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    channel.sink.add(jsonEncode({
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    }));
    return completer.future;
  }

  Future<Map<String, dynamic>> getBrowserVersion() => send('Browser.getVersion');

  Future<void> navigate(String url) async =>
      await send('Page.navigate', {'url': url});

  Future<void> activateTarget(String targetId) async =>
      await send('Target.activateTarget', {'targetId': targetId});

  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
    _failAllPending();
  }
}
```

- [ ] **Step 5: Export + run + commit**

Add `export 'src/cdp/cdp_client.dart';` to `cloak_core.dart`.

Run: `cd packages/cloak_core && dart test test/cdp_client_test.dart`
Expected: `+3: All tests passed!`

```bash
git add packages/cloak_core/pubspec.yaml packages/cloak_core/lib/src/cdp/cdp_client.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/cdp_client_test.dart
git commit -m "feat(cloak_core): add minimal CDP WebSocket client"
```

---

### Task 5: BrowserLauncher

**Files:**
- Create: `packages/cloak_core/lib/src/launcher/browser_launcher.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export)
- Test: `packages/cloak_core/test/browser_launcher_test.dart`

**Interfaces:**
- Consumes: `Profile`, `AppPaths`, `PortAllocator`, `LaunchArgsComposer`, `CdpDiscovery`, `ProcessRegistry`, `RunningProcess`.
- Produces:
  - `class BrowserLauncher { BrowserLauncher({required AppPaths paths, required ProcessRegistry registry, PortAllocator? portAllocator, CdpDiscovery? discovery}); }`
  - `Future<RunningProcess> launch({required Profile profile, required String executablePath})` — resolves user-data-dir, allocates port, composes args, `Process.start`, waits for CDP readiness, registers, and wires process-exit cleanup. Throws `LaunchException` on spawn failure.
  - `Future<void> stop(String profileId)` / `Future<void> stopAll()` — kills the process(es) and removes from the registry; deletes ephemeral dirs.
  - To keep this unit testable without Chromium, expose a seam: `BrowserLauncher` takes an optional `Future<Process> Function(String exe, List<String> args, {Map<String,String>? environment})? spawn` (defaults to `Process.start`).

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/browser_launcher_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory base;
  late AppPaths paths;
  late ProcessRegistry registry;
  late HttpServer cdpServer;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('cm_launch_');
    paths = AppPaths(base);
    registry = ProcessRegistry();
    // Stand-in CDP HTTP endpoint so waitUntilReady succeeds.
    cdpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    cdpServer.listen((req) async {
      if (req.uri.path == '/json/version') {
        req.response.write(jsonEncode({
          'webSocketDebuggerUrl': 'ws://127.0.0.1:${cdpServer.port}/devtools/browser/x'
        }));
      }
      await req.response.close();
    });
  });
  tearDown(() async {
    registry.dispose();
    await cdpServer.close(force: true);
    base.deleteSync(recursive: true);
  });

  Profile profile({bool persistent = true}) => Profile(
        id: 'p1',
        name: 'P',
        colorHex: '#fff',
        iconName: 'person',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        stealth: StealthConfig(proxy: ProxyConfig.disabled()),
        persistent: persistent,
        startUrl: 'about:blank',
      );

  test('launch spawns, waits for CDP, and registers the process', () async {
    // A fake "browser": a long-lived process that ignores its args.
    final launcher = BrowserLauncher(
      paths: paths,
      registry: registry,
      // Force discovery at the stand-in CDP server's port.
      portAllocator: _FixedPortAllocator(cdpServer.port),
      discovery: CdpDiscovery(),
      spawn: (exe, args, {environment}) async =>
          await Process.start(_sleepCommand.first, _sleepCommand.sublist(1)),
    );

    final running = await launcher.launch(
      profile: profile(),
      executablePath: '/unused/fake-chromium',
    );

    expect(running.debugPort, cdpServer.port);
    expect(registry.isRunning('p1'), isTrue);
    expect(Directory(running.userDataDir).existsSync(), isTrue);

    await launcher.stop('p1');
    expect(registry.isRunning('p1'), isFalse);
  });
}

// A cross-platform "sleep ~30s" command for the fake browser process.
List<String> get _sleepCommand => Platform.isWindows
    ? ['cmd', '/c', 'ping', '127.0.0.1', '-n', '30']
    : ['sleep', '30'];

class _FixedPortAllocator implements PortAllocator {
  _FixedPortAllocator(this.port);
  final int port;
  @override
  int get start => port;
  @override
  int get end => port;
  @override
  Future<int> allocate() async => port;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/browser_launcher_test.dart`
Expected: FAIL — `BrowserLauncher` undefined (and the `spawn` seam/`PortAllocator` interface not yet matching).

- [ ] **Step 3: Make `PortAllocator` implementable**

So a test double can satisfy `PortAllocator`, change `packages/cloak_core/lib/src/launcher/port_allocator.dart` Task-8 class to a non-const class with overridable members. Replace the class body's constructor line:

```dart
class PortAllocator {
  PortAllocator({this.start = 9222, this.end = 10222});
```

(Remove `const`.) Leave the rest unchanged.

- [ ] **Step 4: Write the implementation**

`packages/cloak_core/lib/src/launcher/browser_launcher.dart`:

```dart
import 'dart:io';
import 'package:path/path.dart' as p;

import '../cdp/cdp_discovery.dart';
import '../models/profile.dart';
import '../storage/app_paths.dart';
import 'launch_args_composer.dart';
import 'port_allocator.dart';
import 'process_registry.dart';
import 'running_process.dart';

class LaunchException implements Exception {
  LaunchException(this.message);
  final String message;
  @override
  String toString() => 'LaunchException: $message';
}

typedef SpawnFn = Future<Process> Function(
  String executable,
  List<String> args, {
  Map<String, String>? environment,
});

/// Launches and stops per-profile browser processes.
class BrowserLauncher {
  BrowserLauncher({
    required this.paths,
    required this.registry,
    PortAllocator? portAllocator,
    CdpDiscovery? discovery,
    SpawnFn? spawn,
  })  : _ports = portAllocator ?? PortAllocator(),
        _discovery = discovery ?? CdpDiscovery(),
        _spawn = spawn ?? Process.start;

  final AppPaths paths;
  final ProcessRegistry registry;
  final PortAllocator _ports;
  final CdpDiscovery _discovery;
  final SpawnFn _spawn;

  final Map<String, Process> _processes = {};

  Future<RunningProcess> launch({
    required Profile profile,
    required String executablePath,
  }) async {
    final (userDataDir, ephemeral) = await _resolveUserDataDir(profile);
    final port = await _ports.allocate();
    final args = LaunchArgsComposer.compose(
      profile: profile,
      userDataDir: userDataDir,
      debugPort: port,
    );

    final Process process;
    try {
      process = await _spawn(executablePath, args,
          environment: profile.customEnv.isEmpty ? null : profile.customEnv);
    } catch (e) {
      throw LaunchException('Failed to start $executablePath: $e');
    }

    final httpBase = 'http://127.0.0.1:$port';
    final ready = await _discovery.waitUntilReady(httpBase);
    if (!ready) {
      process.kill();
      throw LaunchException('CDP endpoint did not come up on port $port');
    }

    final running = RunningProcess(
      profileId: profile.id,
      pid: process.pid,
      debugPort: port,
      cdpHttpUrl: httpBase,
      ephemeral: ephemeral,
      userDataDir: userDataDir,
    );
    _processes[profile.id] = process;
    registry.add(running);

    // Auto-cleanup when the process exits on its own.
    unawaited(process.exitCode.then((_) => _cleanup(profile.id)));
    return running;
  }

  Future<void> stop(String profileId) async {
    _processes[profileId]?.kill();
    await _cleanup(profileId);
  }

  Future<void> stopAll() async {
    for (final id in _processes.keys.toList()) {
      await stop(id);
    }
  }

  Future<void> _cleanup(String profileId) async {
    final running = registry.byProfile(profileId);
    _processes.remove(profileId);
    registry.remove(profileId);
    if (running != null && running.ephemeral) {
      final dir = Directory(running.userDataDir);
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }

  Future<(String dir, bool ephemeral)> _resolveUserDataDir(Profile profile) async {
    if (profile.persistent) {
      final dir = paths.profileDir(profile.id);
      await dir.create(recursive: true);
      return (dir.path, false);
    }
    final tmp = await Directory.systemTemp
        .createTemp('cloakbrowser-ephemeral-${profile.id}-');
    return (tmp.path, true);
  }
}

// Local helper so we don't need package:async for unawaited.
void unawaited(Future<void> future) {}
```

Note: replace the trailing `unawaited` stub with the SDK one — add `import 'dart:async';` at the top and delete the local `void unawaited(...)` function (Dart's `dart:async` exports `unawaited`).

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/cloak_core && dart test test/browser_launcher_test.dart`
Expected: `+1: All tests passed!`

- [ ] **Step 6: Full suite + analyzer**

Run: `cd packages/cloak_core && dart analyze && dart test`
Expected: `No issues found!` and all M1+M2+M3 tests pass.

- [ ] **Step 7: Commit**

```bash
git add packages/cloak_core/lib/src/launcher/browser_launcher.dart packages/cloak_core/lib/src/launcher/port_allocator.dart packages/cloak_core/lib/cloak_core.dart packages/cloak_core/test/browser_launcher_test.dart
git commit -m "feat(cloak_core): add BrowserLauncher with spawn seam and lifecycle"
```

---

## Self-Review

- **Spec coverage:** full launch argv incl. manager-injected flags (spec §4a/4b) → Task 1; process tracking + stop/stop-all (spec §4b) → Tasks 2,5; CDP tab titles + navigate/activate (spec §4c) → Tasks 3,4; persistent vs ephemeral dirs (spec §3) → Task 5.
- **Placeholder scan:** none — complete code + commands. Two steps contain explicit refactor instructions (remove `const` from `PortAllocator`; swap the `unawaited` stub for the `dart:async` import) — these are concrete edits, not placeholders.
- **Type consistency:** `Profile`/`StealthConfig`/`ProxyConfig` from M1; `AppPaths.profileDir` from M2; `PortAllocator.allocate()` from M1 (made non-const here so doubles can implement it); `CdpDiscovery.waitUntilReady` defined in Task 3 used in Task 5; `ProcessRegistry.add/remove/byProfile` from Task 2 used in Task 5; `RunningProcess` fields consistent across Tasks 2 and 5.
