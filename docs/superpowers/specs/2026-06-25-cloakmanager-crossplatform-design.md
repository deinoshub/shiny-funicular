# Design: CloakManager — Cross-Platform CloakBrowser Manager

**Date:** 2026-06-25
**Status:** Approved (brainstorming complete) — ready for implementation plan

## 1. Overview

A cross-platform (Windows / Linux / macOS) desktop application that manages
[CloakHQ/CloakBrowser](https://github.com/CloakHQ/cloakbrowser) profiles and binary
packages. Each profile launches an isolated stealth-Chromium window with its own
fingerprint, proxy, cookies, and persistent storage. The app aims for **full feature
parity** with the existing macOS-native app (`CloakBrowser/CloakBrowserManager`), but
as a single Flutter codebase that runs on all three desktop OSes.

### Locked-in decisions

| Decision | Choice |
|---|---|
| Stack | **Flutter desktop (Dart)** |
| State management | **Riverpod** |
| Storage | **Drift** (type-safe SQLite, native on all 3 OS via `sqlite3_flutter_libs`) |
| Core logic isolation | Pure-Dart package **`cloak_core`** (no Flutter dependency) |
| v1 scope | **Full parity** with the macOS app |
| Distribution | **Runnable build per OS** — no installers / code signing in v1 |
| Repo location | `/Users/admin/Documents/CloakManager` (new git repo) |

### CloakBrowser cross-platform binaries (verified 2026-06-25)

GitHub releases publish, per version tag:

- `cloakbrowser-darwin-arm64.tar.gz`, `cloakbrowser-darwin-x64.tar.gz`
- `cloakbrowser-windows-x64.zip`
- `cloakbrowser-linux-x64.tar.gz`, `cloakbrowser-linux-arm64.tar.gz`
- `SHA256SUMS` (+ `SHA256SUMS.sig` signature)

Architecture/OS is auto-detected to pick the correct asset.

## 2. Architecture

Two layers with a hard boundary:

1. **`cloak_core`** — pure Dart, no Flutter. All CloakBrowser interaction: building
   stealth args, spawning/monitoring processes, CDP over WebSocket,
   downloading/extracting/verifying binaries. Fully unit-testable without a UI.
2. **Flutter app** — UI + Riverpod state + Drift persistence. Depends on `cloak_core`.

### Project structure

```
CloakManager/                          ← git repo
├── packages/
│   └── cloak_core/                    ← pure Dart, NO Flutter dependency
│       ├── lib/
│       │   ├── models/                (Profile, StealthConfig, ProxyConfig, enums,
│       │   │                           InstalledVersion, ReleaseInfo)
│       │   ├── stealth/               (StealthArgsBuilder)
│       │   ├── launcher/              (BrowserLauncher, ProcessRegistry, PortAllocator)
│       │   ├── cdp/                   (CdpClient, CdpDiscovery)
│       │   ├── binary/                (BinaryManager, ChunkedDownloader, ResumeStore,
│       │   │                           archive extract, SHA-256 verify)
│       │   └── platform/              (PlatformInfo — OS/arch → asset-name mapping)
│       └── test/
├── lib/                               ← Flutter app
│   ├── main.dart
│   ├── app.dart                       (MaterialApp, theme, routing)
│   ├── state/                         (Riverpod providers)
│   ├── data/                          (Drift database, ProfileDao, migrations)
│   ├── screens/
│   │   ├── onboarding/
│   │   ├── home/                      (master-detail: sidebar + editor)
│   │   ├── editor/                    (General / Stealth / Proxy / Advanced)
│   │   └── settings/                  (Versions, About)
│   └── widgets/
├── test/                              (Flutter widget tests)
├── integration_test/
├── docs/
└── pubspec.yaml                       (workspace: app + cloak_core)
```

### Data flow

```
[User] → [Sidebar] → [Launch]
            ↓
   BrowserLauncher.launch(profile)
            ↓
   PortAllocator → free port (9222–10222)
            ↓
   StealthArgsBuilder.build(stealth) → [args]
            ↓
   Process.start(binary, args, environment: customEnv)
            ↓
   ProcessRegistry.add(pid, cdpUrl)
            ↓
   CdpClient.connect(cdpUrl) → poll Target.getTargets (tab title)
            ↓
   Riverpod state updates → sidebar status dot + title
```

## 3. Data model & storage

Schema keeps the proven design of the macOS app, ported to Drift. Data directory
resolved per-OS via `path_provider`:

| OS | Data directory |
|---|---|
| Windows | `%APPDATA%\CloakManager\` |
| macOS | `~/Library/Application Support/CloakManager/` |
| Linux | `~/.local/share/CloakManager/` (XDG) |

```
<dataDir>/
├── cloakmanager.sqlite        ← Drift DB (profiles + schema_version)
├── manifest.json              ← installed binary versions + activeVersion
├── binary/<version>/          ← extracted Chromium (one dir per version)
├── profiles/<profile-id>/     ← per-profile user-data-dir
└── downloads/<sha256>.json    ← in-flight download resume state
```

### `profiles` table

Same columns as the macOS app:

```sql
CREATE TABLE profiles (
    id               TEXT PRIMARY KEY,
    name             TEXT NOT NULL,
    notes            TEXT NOT NULL DEFAULT '',
    color_hex        TEXT NOT NULL DEFAULT '#5E81F4',
    icon_name        TEXT NOT NULL DEFAULT 'person',   -- Material icon name
    group_name       TEXT,
    created_at       REAL NOT NULL,
    updated_at       REAL NOT NULL,
    last_launched_at REAL,
    stealth_json     TEXT NOT NULL,
    persistent       INTEGER NOT NULL DEFAULT 1,
    start_url        TEXT NOT NULL DEFAULT 'about:blank',
    custom_args_json TEXT NOT NULL DEFAULT '[]',
    custom_env_json  TEXT NOT NULL DEFAULT '{}',
    tags_json        TEXT NOT NULL DEFAULT '[]',
    sort_order       INTEGER NOT NULL DEFAULT 0
);
```

`StealthConfig` is JSON-encoded into `stealth_json`. Migrations are append-only
(never edit a shipped migration), tracked by Drift's `schemaVersion`.

### Differences from the macOS app

- **Icons:** Material Icons instead of SF Symbols (cross-platform).
- **No data migration** from the macOS app (different app, different directory).

## 4. `cloak_core` components

### 4a. StealthArgsBuilder

Maps `StealthConfig` → Chromium args per `STEALTH-FLAGS.md`:

```
--fingerprint=<seed>                         (omit when nil → binary randomizes)
--fingerprint-platform=<auto omits|macos|windows|linux>
--fingerprint-brand=<chrome|edge|opera|vivaldi>
--fingerprint-brand-version=<v>   --fingerprint-platform-version=<v>
--fingerprint-hardware-concurrency=<N>   --fingerprint-device-memory=<N>
--fingerprint-screen-width=<N>   --fingerprint-screen-height=<N>
--fingerprint-timezone=<tz>   --fingerprint-locale=<loc>
--fingerprint-gpu-vendor=<v>   --fingerprint-gpu-renderer=<r>
--fingerprint-noise=false        (only when noiseEnabled == false)
--fingerprint-storage-quota=<MB>
--fingerprint-webrtc-ip=<auto|ip>
--proxy-server=<scheme>://[u:p@]host:port   --proxy-bypass-list=<csv>
```

Manager-injected flags (always added):
`--user-data-dir`, `--remote-debugging-port=<free>`,
`--remote-debugging-address=127.0.0.1`, `--no-default-browser-check`,
`--no-first-run`, `--disable-background-mode`,
`--disable-features=TranslateUI,InfiniteSessionRestore`, then custom args, then
start URL. The Advanced tab shows the full computed arg list as a preview.

### 4b. BrowserLauncher + ProcessRegistry + PortAllocator

- `Process.start(exe, args, environment: customEnv)`.
- Executable path per OS: macOS `Chromium.app/Contents/MacOS/Chromium`,
  Windows `chrome.exe`, Linux `chrome` / `chromium`.
- Persistent → `profiles/<id>/`; ephemeral → auto-cleaned temp dir.
- `ProcessRegistry` maps `pid → state`, watches `process.exitCode`. Stop kills the
  pid; Stop-all iterates the registry.
- `PortAllocator` finds a free TCP port in 9222–10222; retries on conflict.

### 4c. CdpClient

`WebSocketChannel` to `cdpUrl`. Commands: `Target.getTargets` (tab title for the
sidebar — replaces the macOS-only `CGWindowList`, so this approach works on all 3
OSes), `Page.navigate`, `Target.activateTarget`, `Browser.getVersion`. Auto-reconnect
on drop.

### 4d. BinaryManager

Detects OS + arch → selects the matching asset:

| Platform | Asset | Extract |
|---|---|---|
| macOS arm64/x64 | `cloakbrowser-darwin-{arm64,x64}.tar.gz` | tar.gz, then `xattr -cr` to strip quarantine |
| Windows x64 | `cloakbrowser-windows-x64.zip` | unzip (`archive` package) |
| Linux x64/arm64 | `cloakbrowser-linux-{x64,arm64}.tar.gz` | tar.gz, then `chmod +x` |

- **ChunkedDownloader:** parallel HTTP Range chunks (default 6–8 × 32 MB) for speed.
- **ResumeStore:** per-download JSON state in `downloads/<sha256>.json`; resumes
  after interruption; expires stale state after 7 days.
- **SHA-256 verify** against `SHA256SUMS` before extracting.
- **Manifest:** `manifest.json` tracks multiple installed versions + `activeVersion`
  (per `PLAN-VERSION-MANAGER.md`). Release list via
  `https://api.github.com/repos/CloakHQ/cloakbrowser/releases`.

## 5. UI (full parity)

Master-detail layout (`Row`: sidebar + editor), equivalent to `NavigationSplitView`.

- **Onboarding:** Welcome → binary download (progress) → main app.
- **Sidebar:** search field, sections grouped by `group_name`, each row with a status
  dot (running/stopped) + current tab title; New button; keyboard shortcuts
  (Ctrl/Cmd+N new, Cmd+R launch, Cmd+Shift+R stop, Cmd+Shift+W stop all).
- **Editor — 4 tabs:**
  - **General:** name, color, icon, group, persistent toggle, start URL.
  - **Stealth:** 7 sections — Identity, Platform, Brand, Hardware, Locale, GPU,
    Advanced.
  - **Proxy:** HTTP/SOCKS5 + credentials + bypass list + GeoIP toggle + Test
    Connection button.
  - **Advanced:** custom Chromium args, env vars, computed-args preview.
- **Settings:** **Versions** tab (install / set active / delete versions, with
  progress) + **About** tab.

## 6. Error handling

| Failure | Handling |
|---|---|
| SHA-256 mismatch | Report + offer retry/resume; do not extract |
| Binary missing | Return to onboarding |
| Process spawn error | Snackbar with stderr; profile stays "stopped" |
| CDP disconnect | Mark profile stopped; auto-reconnect when needed |
| Port in use | `PortAllocator` retries another port |
| Download interrupted | Resume from `downloads/<sha256>.json` |

## 7. Testing

- **`cloak_core` (pure Dart):** StealthArgsBuilder ↔ expected arg strings; SHA256SUMS
  parsing; platform→asset detection; CDP JSON parse; resume logic.
- **Widget tests:** editor tabs + validation.
- **`integration_test`:** smoke — create profile → build args → (mock) launch.

## 8. Out of scope (v1)

- Installers / code signing / notarization
- Embedding the Chromium window inside the app (separate windows only)
- Pro binary support
- Cloud sync, proxy rotation, extension manager
- Multi-language UI (EN only)
- App auto-update

## 9. References

- Existing macOS app docs (reused conventions):
  `CloakBrowser/docs/STEALTH-FLAGS.md`, `DATA-LAYOUT.md`, `CDP.md`,
  `PLAN-VERSION-MANAGER.md`.
- Upstream: <https://github.com/CloakHQ/cloakbrowser>
