# Proxy Connection Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stubbed "Test Connection" button in the Proxy tab with a real through-proxy reachability check that reports latency, exit IP, exit geo, and auth validity.

**Architecture:** A pure-Dart `ProxyTester` in `cloak_core` issues one `GET https://ipwho.is/` through the configured proxy and classifies the outcome into a `ProxyTestResult`. The network call is isolated behind an injectable `ProxyTransport` function so classification/parsing is unit-tested with no network; the default transport wires `dart:io`'s `HttpClient` for HTTP proxies and the `socks5_proxy` package for SOCKS5. The Flutter `ProxyTab` becomes a `ConsumerStatefulWidget` that calls the tester and renders an inline status panel.

**Tech Stack:** Dart 3 / Flutter, Riverpod, `package:test` (core) + `flutter_test` (app), `socks5_proxy` for SOCKS5.

## Global Constraints

- `packages/cloak_core` is **pure Dart** — never import `package:flutter/*` there. `dart:io` and `dart:convert` are allowed (already used by the launcher/CDP code).
- New core dependency: `socks5_proxy: ^2.1.1` — import path is `package:socks5_proxy/socks_client.dart`.
- Echo endpoint is **hard-coded** to `https://ipwho.is/` (a `static const` on `ProxyTester`). Not configurable (YAGNI).
- `ProxyTester.test` **never throws** — every failure mode is caught and returned as a `ProxyTestResult`.
- The default transport always closes its `HttpClient` in a `finally` (`client.close(force: true)`).
- Core SDK floor: `>=3.3.0 <4.0.0` (unchanged).

### Architecture note: transport seam vs. the spec

The design says "injectable `HttpClient` factory." This plan refines that to an
injectable **`ProxyTransport` function** (`Future<ProxyHttpResponse> Function(ProxyConfig, Uri, Duration)`).
Rationale: faking `dart:io`'s `HttpClient` requires stubbing a very large
interface, whereas a transport function lets unit tests return canned responses
or throw, covering all five status outcomes with zero network. The intent of the
spec — "tests run against a fake with no network" — is fully met.

### File map

| File | Responsibility | Task |
|------|----------------|------|
| `packages/cloak_core/lib/src/proxy/proxy_test_result.dart` | Value types: `ProxyTestStatus`, `ProxyTestResult`, `ProxyHttpResponse`, `ProxyAuthException`, `ProxyTransport` typedef | 1 |
| `packages/cloak_core/lib/src/proxy/proxy_tester.dart` | `ProxyTester` — runs transport, classifies & parses into `ProxyTestResult` | 2, 3 |
| `packages/cloak_core/lib/src/proxy/proxy_transport.dart` | `defaultProxyTransport` — real `HttpClient`/SOCKS5 wiring | 3 |
| `packages/cloak_core/lib/cloak_core.dart` | Add exports | 1, 2, 3 |
| `packages/cloak_core/pubspec.yaml` | Add `socks5_proxy` dep | 3 |
| `lib/state/providers.dart` | `proxyTesterProvider` | 4 |
| `lib/screens/editor/proxy_tab.dart` | `ConsumerStatefulWidget` + inline result panel | 5 |

---

### Task 1: Proxy test value types

**Files:**
- Create: `packages/cloak_core/lib/src/proxy/proxy_test_result.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart`
- Test: `packages/cloak_core/test/proxy_test_result_test.dart`

**Interfaces:**
- Consumes: `ProxyConfig` from `src/models/proxy_config.dart` (existing).
- Produces:
  - `enum ProxyTestStatus { success, authFailed, unreachable, timeout, badResponse }`
  - `class ProxyHttpResponse { const ProxyHttpResponse(int statusCode, String body); final int statusCode; final String body; }`
  - `class ProxyAuthException implements Exception { const ProxyAuthException([String message]); final String message; }`
  - `typedef ProxyTransport = Future<ProxyHttpResponse> Function(ProxyConfig proxy, Uri url, Duration timeout);`
  - `class ProxyTestResult` with named fields `{required ProxyTestStatus status, required String message, Duration? latency, String? exitIp, String? country, String? city, String? timezone}` and value `==`/`hashCode`.

- [ ] **Step 1: Write the failing test**

Create `packages/cloak_core/test/proxy_test_result_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('ProxyTestResult has value equality', () {
    const a = ProxyTestResult(
        status: ProxyTestStatus.success, message: 'ok', exitIp: '1.2.3.4');
    const b = ProxyTestResult(
        status: ProxyTestStatus.success, message: 'ok', exitIp: '1.2.3.4');
    const c = ProxyTestResult(
        status: ProxyTestStatus.unreachable, message: 'no');
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
  });

  test('ProxyAuthException carries its message', () {
    expect(const ProxyAuthException('bad creds').message, 'bad creds');
  });

  test('ProxyHttpResponse stores status and body', () {
    const r = ProxyHttpResponse(200, '{}');
    expect(r.statusCode, 200);
    expect(r.body, '{}');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/proxy_test_result_test.dart`
Expected: FAIL — compile error, `ProxyTestResult`/`ProxyTestStatus`/`ProxyAuthException`/`ProxyHttpResponse` are undefined.

- [ ] **Step 3: Create the value types**

Create `packages/cloak_core/lib/src/proxy/proxy_test_result.dart`:

```dart
import '../models/proxy_config.dart';

/// Outcome category of a proxy connection test.
enum ProxyTestStatus { success, authFailed, unreachable, timeout, badResponse }

/// Minimal HTTP response captured by a [ProxyTransport].
class ProxyHttpResponse {
  const ProxyHttpResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

/// Thrown by a transport when the proxy rejects the supplied credentials.
class ProxyAuthException implements Exception {
  const ProxyAuthException([this.message = 'Proxy authentication failed.']);
  final String message;
  @override
  String toString() => 'ProxyAuthException: $message';
}

/// Performs a single GET through [proxy] to [url], honouring [timeout].
///
/// Returns the response, or throws [ProxyAuthException] (bad credentials),
/// `TimeoutException`, `SocketException` (unreachable), or another error.
typedef ProxyTransport = Future<ProxyHttpResponse> Function(
  ProxyConfig proxy,
  Uri url,
  Duration timeout,
);

/// Result of [ProxyTester.test]. Immutable; safe to compare by value.
class ProxyTestResult {
  const ProxyTestResult({
    required this.status,
    required this.message,
    this.latency,
    this.exitIp,
    this.country,
    this.city,
    this.timezone,
  });

  final ProxyTestStatus status;
  final String message;
  final Duration? latency;
  final String? exitIp;
  final String? country;
  final String? city;
  final String? timezone;

  @override
  bool operator ==(Object other) =>
      other is ProxyTestResult &&
      other.status == status &&
      other.message == message &&
      other.latency == latency &&
      other.exitIp == exitIp &&
      other.country == country &&
      other.city == city &&
      other.timezone == timezone;

  @override
  int get hashCode =>
      Object.hash(status, message, latency, exitIp, country, city, timezone);
}
```

- [ ] **Step 4: Export from the core barrel**

In `packages/cloak_core/lib/cloak_core.dart`, add after the existing `export 'src/models/proxy_config.dart';` line:

```dart
export 'src/proxy/proxy_test_result.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd packages/cloak_core && dart test test/proxy_test_result_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/cloak_core/lib/src/proxy/proxy_test_result.dart \
        packages/cloak_core/lib/cloak_core.dart \
        packages/cloak_core/test/proxy_test_result_test.dart
git commit -m "feat(cloak_core): add proxy test value types"
```

---

### Task 2: ProxyTester classification logic

**Files:**
- Create: `packages/cloak_core/lib/src/proxy/proxy_tester.dart`
- Modify: `packages/cloak_core/lib/cloak_core.dart`
- Test: `packages/cloak_core/test/proxy_tester_test.dart`

**Interfaces:**
- Consumes: `ProxyConfig`, `ProxyTestResult`, `ProxyTestStatus`, `ProxyHttpResponse`, `ProxyAuthException`, `ProxyTransport` (Task 1).
- Produces:
  - `class ProxyTester { ProxyTester({required ProxyTransport transport}); static const String echoUrl = 'https://ipwho.is/'; Future<ProxyTestResult> test(ProxyConfig proxy, {Duration timeout = const Duration(seconds: 12)}); }`
  - (In Task 3 the constructor gains a default so `transport` becomes optional.)

- [ ] **Step 1: Write the failing tests**

Create `packages/cloak_core/test/proxy_tester_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

const _proxy = ProxyConfig(
  enabled: true,
  type: ProxyType.http,
  host: 'proxy.test',
  port: 8080,
  username: 'u',
  password: 'p',
);

void main() {
  test('success parses ip, geo, timezone and sets latency', () async {
    final tester = ProxyTester(
      transport: (_, __, ___) async => const ProxyHttpResponse(
        200,
        '{"success":true,"ip":"203.0.113.7","country":"France",'
        '"city":"Paris","timezone":{"id":"Europe/Paris"}}',
      ),
    );
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.success);
    expect(r.exitIp, '203.0.113.7');
    expect(r.country, 'France');
    expect(r.city, 'Paris');
    expect(r.timezone, 'Europe/Paris');
    expect(r.latency, isNotNull);
  });

  test('HTTP 407 maps to authFailed', () async {
    final tester = ProxyTester(
        transport: (_, __, ___) async => const ProxyHttpResponse(407, ''));
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.authFailed);
  });

  test('ProxyAuthException maps to authFailed and keeps message', () async {
    final tester = ProxyTester(
        transport: (_, __, ___) async =>
            throw const ProxyAuthException('bad creds'));
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.authFailed);
    expect(r.message, 'bad creds');
  });

  test('SocketException maps to unreachable', () async {
    final tester = ProxyTester(
        transport: (_, __, ___) async => throw const SocketException('refused'));
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.unreachable);
  });

  test('TimeoutException maps to timeout', () async {
    final tester = ProxyTester(
        transport: (_, __, ___) async => throw TimeoutException('slow'));
    final r = await tester.test(_proxy, timeout: const Duration(seconds: 5));
    expect(r.status, ProxyTestStatus.timeout);
  });

  test('success:false body maps to badResponse', () async {
    final tester = ProxyTester(
      transport: (_, __, ___) async =>
          const ProxyHttpResponse(200, '{"success":false,"message":"no route"}'),
    );
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.badResponse);
  });

  test('non-JSON body maps to badResponse', () async {
    final tester = ProxyTester(
        transport: (_, __, ___) async => const ProxyHttpResponse(200, '<html>'));
    final r = await tester.test(_proxy);
    expect(r.status, ProxyTestStatus.badResponse);
  });
}
```

Note: `const SocketException('refused')` is valid — `SocketException`'s default constructor is `const`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/cloak_core && dart test test/proxy_tester_test.dart`
Expected: FAIL — `ProxyTester` is undefined.

- [ ] **Step 3: Implement ProxyTester**

Create `packages/cloak_core/lib/src/proxy/proxy_tester.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/proxy_config.dart';
import 'proxy_test_result.dart';

/// Runs a single through-proxy request and classifies the outcome.
///
/// The network call is delegated to an injectable [ProxyTransport] so the
/// classification/parsing logic here can be unit-tested with no network.
class ProxyTester {
  ProxyTester({required ProxyTransport transport}) : _transport = transport;

  final ProxyTransport _transport;

  /// Endpoint hit through the proxy to learn the exit IP and geo.
  static const String echoUrl = 'https://ipwho.is/';

  /// Tests [proxy]. Never throws: failures become a [ProxyTestResult].
  Future<ProxyTestResult> test(
    ProxyConfig proxy, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final sw = Stopwatch()..start();
    try {
      final res = await _transport(proxy, Uri.parse(echoUrl), timeout);
      sw.stop();

      if (res.statusCode == 407) {
        return const ProxyTestResult(
          status: ProxyTestStatus.authFailed,
          message: 'Proxy rejected the credentials (HTTP 407).',
        );
      }
      if (res.statusCode != 200) {
        return ProxyTestResult(
          status: ProxyTestStatus.badResponse,
          message: 'Unexpected response from echo service '
              '(HTTP ${res.statusCode}).',
        );
      }

      Map<String, dynamic> json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return const ProxyTestResult(
          status: ProxyTestStatus.badResponse,
          message: 'Could not parse the echo service response.',
        );
      }

      if (json['success'] != true) {
        final msg = json['message'];
        return ProxyTestResult(
          status: ProxyTestStatus.badResponse,
          message:
              'Echo service reported failure${msg is String ? ': $msg' : ''}.',
        );
      }

      final tz = json['timezone'];
      return ProxyTestResult(
        status: ProxyTestStatus.success,
        latency: sw.elapsed,
        exitIp: json['ip'] as String?,
        country: json['country'] as String?,
        city: json['city'] as String?,
        timezone: tz is Map<String, dynamic> ? tz['id'] as String? : null,
        message: 'Connected through the proxy.',
      );
    } on ProxyAuthException catch (e) {
      return ProxyTestResult(
          status: ProxyTestStatus.authFailed, message: e.message);
    } on TimeoutException {
      return ProxyTestResult(
        status: ProxyTestStatus.timeout,
        message: 'Proxy test timed out after ${timeout.inSeconds}s.',
      );
    } on SocketException catch (e) {
      return ProxyTestResult(
        status: ProxyTestStatus.unreachable,
        message: 'Could not reach the proxy: ${e.message}.',
      );
    } catch (e) {
      return ProxyTestResult(
        status: ProxyTestStatus.unreachable,
        message: 'Proxy test failed: $e',
      );
    }
  }
}
```

- [ ] **Step 4: Export from the core barrel**

In `packages/cloak_core/lib/cloak_core.dart`, add after the `proxy_test_result.dart` export:

```dart
export 'src/proxy/proxy_tester.dart';
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/cloak_core && dart test test/proxy_tester_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/cloak_core/lib/src/proxy/proxy_tester.dart \
        packages/cloak_core/lib/cloak_core.dart \
        packages/cloak_core/test/proxy_tester_test.dart
git commit -m "feat(cloak_core): add ProxyTester result classification"
```

---

### Task 3: Default transport (real HTTP + SOCKS5)

**Files:**
- Create: `packages/cloak_core/lib/src/proxy/proxy_transport.dart`
- Modify: `packages/cloak_core/lib/src/proxy/proxy_tester.dart` (constructor default)
- Modify: `packages/cloak_core/lib/cloak_core.dart` (export transport)
- Modify: `packages/cloak_core/pubspec.yaml` (add `socks5_proxy`)
- Test: `packages/cloak_core/test/proxy_transport_test.dart`

**Interfaces:**
- Consumes: `ProxyConfig`, `ProxyType` (from `enums.dart`), `ProxyHttpResponse`, `ProxyAuthException` (Task 1).
- Produces:
  - `Future<ProxyHttpResponse> defaultProxyTransport(ProxyConfig proxy, Uri url, Duration timeout)`
  - `ProxyTester` constructor becomes `ProxyTester({ProxyTransport? transport})` defaulting to `defaultProxyTransport`.

- [ ] **Step 1: Add the dependency**

In `packages/cloak_core/pubspec.yaml`, under `dependencies:` (after `web_socket_channel: ^3.0.0`), add:

```yaml
  socks5_proxy: ^2.1.1
```

Run: `cd packages/cloak_core && dart pub get`
Expected: resolves and downloads `socks5_proxy 2.1.x`.

- [ ] **Step 2: Write the failing integration tests**

Create `packages/cloak_core/test/proxy_transport_test.dart`. These connect to a
closed local port (`127.0.0.1:1`) — no external network — and assert the default
transport surfaces a connection failure as `unreachable`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('default HTTP proxy on a closed port -> unreachable', () async {
    final r = await ProxyTester().test(
      const ProxyConfig(
          enabled: true, type: ProxyType.http, host: '127.0.0.1', port: 1),
      timeout: const Duration(seconds: 5),
    );
    expect(r.status, ProxyTestStatus.unreachable);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('default SOCKS5 proxy on a closed port -> unreachable', () async {
    final r = await ProxyTester().test(
      const ProxyConfig(
          enabled: true, type: ProxyType.socks5, host: '127.0.0.1', port: 1),
      timeout: const Duration(seconds: 5),
    );
    expect(r.status, ProxyTestStatus.unreachable);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd packages/cloak_core && dart test test/proxy_transport_test.dart`
Expected: FAIL — `ProxyTester()` requires a `transport:` argument (no default yet).

- [ ] **Step 4: Implement the default transport**

Create `packages/cloak_core/lib/src/proxy/proxy_transport.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:socks5_proxy/socks_client.dart';

import '../models/enums.dart';
import '../models/proxy_config.dart';
import 'proxy_test_result.dart';

/// Real network transport used by [ProxyTester] in production.
///
/// HTTP proxies use `HttpClient.findProxy` + `addProxyCredentials`; SOCKS5
/// proxies are routed via the `socks5_proxy` package. The client is always
/// closed in a `finally`.
Future<ProxyHttpResponse> defaultProxyTransport(
  ProxyConfig proxy,
  Uri url,
  Duration timeout,
) async {
  final client = HttpClient();
  try {
    final hasAuth = proxy.username != null && proxy.username!.isNotEmpty;

    if (proxy.type == ProxyType.socks5) {
      final addrs = await InternetAddress.lookup(proxy.host).timeout(timeout);
      if (addrs.isEmpty) {
        throw const SocketException('Could not resolve proxy host');
      }
      SocksTCPClient.assignToHttpClient(client, [
        ProxySettings(
          addrs.first,
          proxy.port,
          username: hasAuth ? proxy.username : null,
          password: hasAuth ? proxy.password : null,
        ),
      ]);
    } else {
      client.findProxy = (_) => 'PROXY ${proxy.host}:${proxy.port}';
      if (hasAuth) {
        client.addProxyCredentials(
          proxy.host,
          proxy.port,
          '',
          HttpClientBasicCredentials(proxy.username!, proxy.password ?? ''),
        );
      }
    }

    final request = await client.getUrl(url).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final body = await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join()
        .timeout(timeout);

    if (response.statusCode == 407) {
      throw const ProxyAuthException('Proxy rejected the credentials (HTTP 407).');
    }
    return ProxyHttpResponse(response.statusCode, body);
  } on HttpException catch (e) {
    // For HTTPS-over-HTTP-proxy, a bad-credential 407 surfaces as a failed
    // CONNECT tunnel rather than a normal response.
    final m = e.message.toLowerCase();
    if (m.contains('407') || m.contains('proxy')) {
      throw const ProxyAuthException('Proxy rejected the credentials.');
    }
    rethrow;
  } finally {
    client.close(force: true);
  }
}
```

- [ ] **Step 5: Wire the default into ProxyTester**

In `packages/cloak_core/lib/src/proxy/proxy_tester.dart`, add the import near the
top (after `import 'proxy_test_result.dart';`):

```dart
import 'proxy_transport.dart';
```

Then change the constructor line from:

```dart
  ProxyTester({required ProxyTransport transport}) : _transport = transport;
```

to:

```dart
  ProxyTester({ProxyTransport? transport})
      : _transport = transport ?? defaultProxyTransport;
```

- [ ] **Step 6: Export the transport from the core barrel**

In `packages/cloak_core/lib/cloak_core.dart`, add after the `proxy_tester.dart` export:

```dart
export 'src/proxy/proxy_transport.dart';
```

- [ ] **Step 7: Run the full core suite to verify it passes**

Run: `cd packages/cloak_core && dart test test/proxy_transport_test.dart test/proxy_tester_test.dart test/proxy_test_result_test.dart`
Expected: PASS — both transport tests report `unreachable`; Task 1 and Task 2 tests still pass (the optional `transport:` named arg keeps their `ProxyTester(transport: ...)` calls valid).

- [ ] **Step 8: Commit**

Note: `pubspec.lock` is gitignored at the repo root — do NOT commit it.

```bash
git add packages/cloak_core/pubspec.yaml \
        packages/cloak_core/lib/src/proxy/proxy_transport.dart \
        packages/cloak_core/lib/src/proxy/proxy_tester.dart \
        packages/cloak_core/lib/cloak_core.dart \
        packages/cloak_core/test/proxy_transport_test.dart
git commit -m "feat(cloak_core): real HTTP/SOCKS5 proxy test transport"
```

---

### Task 4: Riverpod provider

**Files:**
- Modify: `lib/state/providers.dart`
- Test: `test/proxy_tester_provider_test.dart`

**Interfaces:**
- Consumes: `ProxyTester` (Task 2/3).
- Produces: `final proxyTesterProvider = Provider<ProxyTester>(...)`.

- [ ] **Step 1: Write the failing test**

Create `test/proxy_tester_provider_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proxyTesterProvider exposes a ProxyTester', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(proxyTesterProvider), isA<ProxyTester>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/proxy_tester_provider_test.dart`
Expected: FAIL — `proxyTesterProvider` is undefined.

- [ ] **Step 3: Add the provider**

In `lib/state/providers.dart`, add at the end of the file:

```dart
final proxyTesterProvider = Provider<ProxyTester>((ref) => ProxyTester());
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/proxy_tester_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/state/providers.dart test/proxy_tester_provider_test.dart
git commit -m "feat(app): add proxyTesterProvider"
```

---

### Task 5: Proxy tab inline result panel

**Files:**
- Modify: `lib/screens/editor/proxy_tab.dart` (full rewrite — convert to `ConsumerStatefulWidget`)
- Test: `test/proxy_tab_test.dart`

**Interfaces:**
- Consumes: `proxyTesterProvider` (Task 4), `ProxyTester`, `ProxyTestResult`, `ProxyTestStatus`, `ProxyHttpResponse`, `ProxyAuthException` (Tasks 1–3).
- Produces: no new public API — `ProxyTab({required Profile draft, required ValueChanged<Profile> onChanged})` constructor is unchanged, so `editor_screen.dart` needs no edits.

- [ ] **Step 1: Write the failing widget tests**

Create `test/proxy_tab_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/editor/proxy_tab.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile() => Profile(
      id: 'p1',
      name: 'Work',
      colorHex: '#fff',
      iconName: 'person',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      startUrl: 'https://example.com',
      stealth: StealthConfig(
        fingerprintSeed: 'seed',
        proxy: const ProxyConfig(
          enabled: true,
          type: ProxyType.http,
          host: 'proxy.test',
          port: 8080,
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, ProxyTester fake) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [proxyTesterProvider.overrideWithValue(fake)],
    child: MaterialApp(
      home: Scaffold(
        body: ProxyTab(draft: _profile(), onChanged: (_) {}),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('shows success panel with exit IP and geo', (tester) async {
    final fake = ProxyTester(
      transport: (_, __, ___) async => const ProxyHttpResponse(
        200,
        '{"success":true,"ip":"203.0.113.7","country":"France",'
        '"city":"Paris","timezone":{"id":"Europe/Paris"}}',
      ),
    );
    await _pump(tester, fake);
    await tester.tap(find.text('Test Connection'));
    await tester.pump(); // kick off async test (spinner)
    await tester.pump(const Duration(milliseconds: 50)); // future resolves
    expect(find.text('Proxy OK'), findsOneWidget);
    expect(find.textContaining('203.0.113.7'), findsOneWidget);
    expect(find.textContaining('Paris, France'), findsOneWidget);
  });

  testWidgets('shows error panel on auth failure', (tester) async {
    final fake = ProxyTester(
      transport: (_, __, ___) async =>
          throw const ProxyAuthException('bad creds'),
    );
    await _pump(tester, fake);
    await tester.tap(find.text('Test Connection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Proxy test failed'), findsOneWidget);
    expect(find.textContaining('bad creds'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/proxy_tab_test.dart`
Expected: FAIL — the success/error panels (`Proxy OK` / `Proxy test failed`) don't exist yet; the current stub only shows a snackbar.

- [ ] **Step 3: Rewrite ProxyTab**

Replace the entire contents of `lib/screens/editor/proxy_tab.dart` with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../widgets/draft_text_field.dart';
import '../../widgets/labeled_field.dart';

class ProxyTab extends ConsumerStatefulWidget {
  const ProxyTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  @override
  ConsumerState<ProxyTab> createState() => _ProxyTabState();
}

class _ProxyTabState extends ConsumerState<ProxyTab> {
  bool _testing = false;
  ProxyTestResult? _result;

  ProxyConfig get px => widget.draft.stealth.proxy;

  void _set(ProxyConfig next) => widget.onChanged(
      widget.draft.copyWith(stealth: widget.draft.stealth.copyWith(proxy: next)));

  bool get _canTest =>
      px.enabled && px.host.isNotEmpty && px.port > 0 && !_testing;

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final result = await ref.read(proxyTesterProvider).test(px);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LabeledField(
          label: 'Enabled',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Switch(
                value: px.enabled,
                onChanged: (v) => _set(px.copyWith(enabled: v))),
          ),
        ),
        LabeledField(
          label: 'Type',
          child: DropdownButton<ProxyType>(
            value: px.type,
            items: [
              for (final t in ProxyType.values)
                DropdownMenuItem(value: t, child: Text(t.name)),
            ],
            onChanged: (v) => _set(px.copyWith(type: v)),
          ),
        ),
        LabeledField(
          label: 'Host',
          child: DraftTextField(
            initialValue: px.host,
            onChanged: (v) => _set(px.copyWith(host: v)),
          ),
        ),
        LabeledField(
          label: 'Port',
          child: DraftTextField(
            initialValue: px.port == 0 ? '' : '${px.port}',
            keyboardType: TextInputType.number,
            onChanged: (v) => _set(px.copyWith(port: int.tryParse(v) ?? 0)),
          ),
        ),
        LabeledField(
          label: 'Username',
          child: DraftTextField(
            initialValue: px.username ?? '',
            onChanged: (v) => _set(px.copyWith(username: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Password',
          child: DraftTextField(
            initialValue: px.password ?? '',
            obscureText: true,
            onChanged: (v) => _set(px.copyWith(password: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Bypass list',
          child: DraftTextField(
            initialValue: px.bypassList,
            hintText: 'localhost,127.0.0.1',
            onChanged: (v) => _set(px.copyWith(bypassList: v)),
          ),
        ),
        LabeledField(
          label: 'GeoIP (timezone/locale from exit IP)',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Switch(
                value: px.geoipEnabled,
                onChanged: (v) => _set(px.copyWith(geoipEnabled: v))),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Test Connection'),
            onPressed: _canTest ? _test : null,
          ),
        ),
        if (_testing || _result != null) ...[
          const SizedBox(height: 12),
          _ProxyTestPanel(testing: _testing, result: _result),
        ],
      ],
    );
  }
}

class _ProxyTestPanel extends StatelessWidget {
  const _ProxyTestPanel({required this.testing, required this.result});
  final bool testing;
  final ProxyTestResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (testing) {
      return Row(
        children: const [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Testing…'),
        ],
      );
    }

    final r = result!;
    final ok = r.status == ProxyTestStatus.success;
    final color = ok ? Colors.green.shade700 : theme.colorScheme.error;

    final lines = <String>[];
    if (ok) {
      if (r.latency != null) lines.add('Latency: ${r.latency!.inMilliseconds} ms');
      if (r.exitIp != null) lines.add('Exit IP: ${r.exitIp}');
      final geo = [r.city, r.country]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
      if (geo.isNotEmpty) lines.add('Location: $geo');
      if (r.timezone != null) lines.add('Timezone: ${r.timezone}');
    } else {
      lines.add(r.message);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.error, color: color, size: 18),
              const SizedBox(width: 8),
              Text(ok ? 'Proxy OK' : 'Proxy test failed',
                  style: theme.textTheme.titleSmall?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 8),
          for (final l in lines) Text(l),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/proxy_tab_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Run the full suite (no regressions)**

Run: `flutter test` and `cd packages/cloak_core && dart test`
Expected: All pass. (`editor_screen.dart` is unaffected — `ProxyTab`'s constructor is unchanged.)

- [ ] **Step 6: Commit**

```bash
git add lib/screens/editor/proxy_tab.dart test/proxy_tab_test.dart
git commit -m "feat(ui): real proxy connection test with inline result panel"
```

---

## Self-Review

**Spec coverage:**
- Reachable + latency → Task 2 (`latency` from `Stopwatch`), shown in Task 5 panel. ✓
- Exit IP → Task 2 parse `ip`, Task 5 display. ✓
- Exit geo (country/city/timezone) → Task 2 parse `country`/`city`/`timezone.id`, Task 5 display. ✓
- Auth validation → Task 2 (`407` + `ProxyAuthException` → `authFailed`), Task 3 maps real failures, Task 5 error panel. ✓
- HTTP proxy support → Task 3 `findProxy` + `addProxyCredentials`. ✓
- SOCKS5 support via `socks5_proxy` → Task 3 `SocksTCPClient.assignToHttpClient` + `InternetAddress.lookup`. ✓
- `ipwho.is` hard-coded → Task 2 `echoUrl` const. ✓
- `ProxyTester.test` never throws → Task 2 catch-all. ✓
- `HttpClient` closed in `finally` → Task 3. ✓
- Exports → Tasks 1–3. ✓
- `proxyTesterProvider` → Task 4. ✓
- `ConsumerStatefulWidget` + inline panel + button-enable rule → Task 5. ✓
- Unit tests for all five statuses → Task 2; widget success + error → Task 5. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases" — every code step shows full code. ✓

**Type consistency:** `ProxyHttpResponse(statusCode, body)` positional throughout; `ProxyTransport` signature `(ProxyConfig, Uri, Duration)` identical in typedef, fakes, and `defaultProxyTransport`; `ProxyTester({transport})` named arg consistent across Tasks 2–5; `ProxyTestStatus` values `success/authFailed/unreachable/timeout/badResponse` used identically everywhere. ✓
