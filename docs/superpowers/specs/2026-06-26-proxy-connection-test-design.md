# Proxy Connection Test — Design

**Date:** 2026-06-26
**Status:** Approved (design); pending implementation plan
**Topic:** Replace the stubbed "Test Connection" button in the Proxy tab with a real through-proxy reachability check.

## Problem

The Proxy tab's **Test Connection** button (`lib/screens/editor/proxy_tab.dart`)
is a stub: it only echoes the composed `serverString` in a snackbar. The code
itself flags "a real through-proxy reachability check" as a post-M5 follow-up.
Users cannot tell whether a proxy actually works, whether their credentials are
accepted, or what exit IP / location the proxy presents — all of which matter
for a stealth-browser tool where the proxy's exit geo drives fingerprint
expectations.

## Goal

When the user clicks **Test Connection**, send one real HTTP request *through
the configured proxy* and report:

- **Reachable + latency** — the request succeeded, with round-trip time.
- **Exit IP** — the public IP the proxy exits from (proves traffic is routed
  through it, not direct).
- **Exit geo** — country / city / timezone of the exit IP.
- **Auth validation** — distinguish an authentication failure (bad
  username/password) from a network/unreachable error, with a clear message.

Both proxy types in `ProxyType { http, socks5 }` must be supported.

## Approach

Chosen: **in-process Dart test**. A pure-Dart `ProxyTester` in `cloak_core`
issues a single `GET https://ipwho.is/` through the proxy using `dart:io`'s
`HttpClient`:

- **HTTP proxies** — `HttpClient` natively proxies via
  `client.findProxy = (uri) => 'PROXY host:port'`, with credentials supplied
  through `client.addProxyCredentials(host, port, realm, creds)`.
- **SOCKS5 proxies** — `dart:io` has no native SOCKS support, so we add the
  `socks5_proxy` package and route the client with
  `SocksTCPClient.assignToHttpClient(client, [ProxySettings(...)])`.

This is fast (one request), fully unit-testable behind a fake `HttpClient`, and
respects the existing hard boundary: all proxy logic lives in pure-Dart
`cloak_core`, the Flutter app only renders results.

### Alternatives rejected

- **Launch a hidden browser and read the exit IP over CDP.** Reuses
  `ProxyAuthenticator` and exercises the exact launch path, but is heavyweight
  (spawn Chromium, wait for readiness, navigate, scrape) and slow — overkill for
  validating a config field.
- **Shell out to `curl --proxy`.** Not reliably cross-platform (Windows curl,
  SOCKS auth quirks) and breaks the pure-Dart core.

## Architecture

Two layers, matching the existing boundary.

### Core — `packages/cloak_core`

**New dependency:** `socks5_proxy: ^2.1.1`
(import `package:socks_proxy/socks_client.dart`).

**`ProxyTestStatus`** — enum:
`success`, `authFailed`, `unreachable`, `timeout`, `badResponse`.

**`ProxyTestResult`** — immutable value type:

| Field      | Type        | Notes                                            |
|------------|-------------|--------------------------------------------------|
| `status`   | `ProxyTestStatus` | required                                    |
| `latency`  | `Duration?` | set on `success`                                 |
| `exitIp`   | `String?`   | set on `success`                                 |
| `country`  | `String?`   | set on `success`                                 |
| `city`     | `String?`   | set on `success`                                 |
| `timezone` | `String?`   | set on `success` (from `timezone.id`)            |
| `message`  | `String`    | human-readable summary / error, always set       |

Includes `==`/`hashCode` for testability.

**`ProxyTester`** — performs the test:

```dart
typedef HttpClientFactory = HttpClient Function();

class ProxyTester {
  ProxyTester({HttpClientFactory? httpClientFactory});

  static const echoUrl = 'https://ipwho.is/';

  Future<ProxyTestResult> test(
    ProxyConfig proxy, {
    Duration timeout = const Duration(seconds: 12),
  });
}
```

Behavior of `test`:

1. Build an `HttpClient` from the injectable factory (default `HttpClient.new`).
2. Configure routing by `proxy.type`:
   - `http`: `client.findProxy = (_) => 'PROXY ${proxy.host}:${proxy.port}';`
     and, when `proxy.username` is non-empty,
     `client.addProxyCredentials(proxy.host, proxy.port, '', HttpClientBasicCredentials(user, pass))`.
   - `socks5`: resolve host via `InternetAddress.lookup(proxy.host)` (first
     result), then
     `SocksTCPClient.assignToHttpClient(client, [ProxySettings(addr, proxy.port, username: user, password: pass)])`
     (omit `username`/`password` when no credentials).
3. Start a `Stopwatch`, issue `GET https://ipwho.is/` with `.timeout(timeout)`,
   read the body.
4. Parse JSON: `success` (bool), `ip`, `country`, `city`, `timezone.id`.
5. Map the outcome:
   - HTTP 407 / SOCKS auth rejection → `authFailed`
   - `SocketException` / SOCKS handshake failure → `unreachable`
   - `TimeoutException` → `timeout`
   - `success: false` or unparseable body → `badResponse`
   - otherwise → `success` (with latency, IP, geo, and a summary `message`)
6. Always `client.close(force: true)` in a `finally`.

**Exports:** add `ProxyTester`, `ProxyTestResult`, `ProxyTestStatus` to
`packages/cloak_core/lib/cloak_core.dart`.

### App — `lib/`

- **`proxyTesterProvider`** in `lib/state/providers.dart` — exposes a
  `ProxyTester` (default construction).
- **`ProxyTab`** converts from `StatelessWidget` to `ConsumerStatefulWidget`
  (`lib/screens/editor/proxy_tab.dart`) to hold local test state:
  `idle | testing | ProxyTestResult`.
- **Inline status panel** below the Test button replaces the snackbar:
  - while testing: a spinner + "Testing…"
  - on `success`: latency (ms), exit IP, `"$city, $country"`, timezone
  - on failure: the status-specific `message`
  - The button is enabled only when `proxy.enabled` and host is non-empty and
    port > 0; pressing it sets state to `testing`, awaits
    `proxyTester.test(proxy)`, then stores the result.

## Data flow

```
ProxyTab (Test pressed)
  → proxyTesterProvider.test(draft.stealth.proxy)
    → HttpClient (HTTP findProxy / SOCKS assignToHttpClient)
      → GET https://ipwho.is/  (through proxy)
    ← ProxyTestResult
  → setState → inline panel renders result
```

## Error handling

All failure modes are mapped to a `ProxyTestStatus` and a human-readable
`message`; `ProxyTester.test` never throws to the caller — exceptions are caught
and classified. The `HttpClient` is always closed in a `finally`.

## Testing

**`cloak_core` unit tests** (`test/proxy_tester_test.dart`) against a fake
`HttpClient`/request/response (no network):

- `success` — 200 with valid ipwho.is JSON → result has latency, IP, geo.
- `authFailed` — 407 response.
- `unreachable` — factory/connection throws `SocketException`.
- `timeout` — request exceeds the timeout.
- `badResponse` — 200 with `{"success": false, ...}` or non-JSON body.
- `ProxyTestResult` value semantics (`==`/`hashCode`).

**Widget test** (`test/.../proxy_tab_test.dart`) with an injected fake tester:

- pressing Test shows the spinner, then the success panel (IP + geo visible).
- a failing tester renders the error panel with the `message`.

## Out of scope (YAGNI)

- Proxy rotation / pools.
- Background / periodic health monitoring.
- Persisting test results.
- Bulk proxy import.
- A configurable echo endpoint (hard-code `https://ipwho.is/` for now).

## Privacy note

The test sends one request through the user's proxy to `ipwho.is` over HTTPS to
learn the exit IP/geo. This is inherent to the feature and uses HTTPS so the
lookup is not exposed in plaintext.
