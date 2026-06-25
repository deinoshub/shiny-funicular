# CloakManager

A cross-platform (**Windows / Linux / macOS**) desktop app for managing
[CloakHQ/CloakBrowser](https://github.com/CloakHQ/cloakbrowser) — a stealth
Chromium that passes Cloudflare Turnstile, reCAPTCHA v3, FingerprintJS, and
common detection sites.

Each profile launches an isolated Chromium window with its own fingerprint,
proxy, cookies, and persistent storage, so accounts and sessions stay
compartmentalised across windows.

```
┌─────────────────────────────────────────────────────────────┐
│ [Search]                              [⚙]  [+ New]           │
├──────────────────┬──────────────────────────────────────────┤
│ Ungrouped        │ [General][Stealth][Proxy][Advanced] [Save]│
│ ● Personal     ● │ ┌──────────────────────────────────────┐ │
│ ○ Work           │ │ Name:    [Personal              ]    │ │
│ ○ Shopping       │ │ Icon:    [person ▼]   Persistent: ◉  │ │
│                  │ │ Start:   [https://app.example.com]   │ │
│                  │ └──────────────────────────────────────┘ │
└──────────────────┴──────────────────────────────────────────┘
```

## Features

- **Built-in CloakBrowser** — auto-downloads the official stealth Chromium from
  GitHub Releases on first launch. Picks the newest release that ships a build for
  your OS/arch, verifies SHA-256 against `SHA256SUMS`, and extracts it (strips
  macOS Gatekeeper quarantine).
- **Fast, parallel downloads** — multi-connection HTTP Range downloader with a
  single-stream fallback.
- **Per-profile stealth** — full surface area mapped to CloakBrowser
  `--fingerprint-*` flags: fingerprint seed, platform spoof
  (Auto/macOS/Windows/Linux), brand (Chrome/Edge/Opera/Vivaldi) + version,
  hardware (CPU cores, RAM, screen), locale + timezone, GPU vendor/renderer,
  WebRTC IP policy, storage-quota override, fingerprint noise toggle.
- **Per-profile proxy** — HTTP or SOCKS5 with credentials, bypass list, and a
  GeoIP toggle (timezone/locale from the proxy exit IP).
- **Persistent or ephemeral** context per profile.
- **Multi-version management** — install several Chromium versions, set the active
  one, delete old ones (Settings → Versions).
- **CDP client** — talks to each running profile over the Chrome DevTools Protocol
  for tab discovery and navigation.
- **Keyboard shortcuts** — ⌘/Ctrl+N new, ⌘/Ctrl+R launch, ⌘/Ctrl+⇧R stop,
  ⌘/Ctrl+⇧W stop all.
- **Computed-args preview** — see the exact Chromium argv a profile will launch
  with (Advanced tab).

## Architecture

Two layers with a hard boundary:

- **`packages/cloak_core`** — pure Dart, no Flutter. All CloakBrowser interaction:
  stealth-arg generation, binary download/verify/extract, multi-version manifest,
  process launching, and the CDP client. Fully unit-tested without a UI.
- **Flutter app (`lib/`)** — UI + [Riverpod](https://riverpod.dev) state +
  [Drift](https://drift.simonbinder.eu) (SQLite) persistence.

```
CloakManager/
├── packages/cloak_core/         ← pure-Dart core (models, stealth, binary, launcher, cdp)
│   ├── lib/src/{models,stealth,binary,launcher,cdp,platform,storage}/
│   └── tool/e2e_verify.dart      ← headless end-to-end verifier
├── lib/
│   ├── data/                     ← Drift database + ProfileDao
│   ├── state/                    ← Riverpod providers + controllers
│   ├── screens/{onboarding,home,editor,settings}/
│   └── widgets/
├── docs/superpowers/{specs,plans}/  ← design spec + per-milestone implementation plans
├── windows/ · linux/ · macos/    ← desktop runners
└── README.md
```

See [`docs/superpowers/specs/2026-06-25-cloakmanager-crossplatform-design.md`](docs/superpowers/specs/2026-06-25-cloakmanager-crossplatform-design.md)
for the design and [`docs/superpowers/plans/`](docs/superpowers/plans/) for the
milestone-by-milestone build plans (M1–M5).

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) (stable channel, desktop
  enabled) — includes the Dart SDK (3.3+).
- ~250 MB disk for the downloaded CloakBrowser binary.
- Internet access on first run (to download the binary).

Enable desktop targets once:

```bash
flutter config --enable-macos-desktop --enable-windows-desktop --enable-linux-desktop
```

## Build & run

```bash
# Resolve dependencies
flutter pub get

# Generate Drift code (required after a fresh clone — *.g.dart is git-ignored)
dart run build_runner build

# Run on the current desktop OS
flutter run -d macos        # or: -d windows / -d linux

# Build a runnable app
flutter build macos         # or: windows / linux
```

First launch shows onboarding → **Download CloakBrowser** → the main window.

### Data layout

Per-OS application-support directory (`%APPDATA%\CloakManager` on Windows,
`~/Library/Application Support/CloakManager` on macOS,
`$XDG_DATA_HOME/CloakManager` on Linux):

```
cloakmanager.sqlite      profiles (Drift)
manifest.json            installed binary versions + active version
binary/<version>/        extracted Chromium
profiles/<id>/           per-profile user-data-dir
downloads/<sha256>.json  in-flight download resume state
```

## Testing

```bash
# Pure-Dart core (fast, no Flutter)
cd packages/cloak_core && dart test && dart analyze

# Flutter app (widget + unit tests)
flutter test && flutter analyze
```

Current status: **67 core tests + 22 app tests, analyzer clean.**

### End-to-end verification

A headless script exercises the whole real stack — discover release → download
(~150 MB) → SHA-256 verify → extract → launch real Chromium → CDP → stop:

```bash
cd packages/cloak_core && dart run tool/e2e_verify.dart
```

## Roadmap

Planned expansions, roughly in priority order. None of these are required for the
current feature set; they extend it.

### Packaging & distribution
- [ ] Installers per OS: `.msi`/`.exe` (Windows), `.dmg` (macOS), `.deb`/AppImage (Linux)
- [ ] Code signing (Windows) + notarization (macOS)
- [ ] CI matrix that builds + tests on all three OSes
- [ ] App auto-update

### Binary management
- [ ] Wire `ResumeStore` into `BinaryManager.install` so interrupted downloads
      resume across app restarts (the store + state model exist and are tested;
      `install()` does not consume them yet)
- [ ] Per-row download progress + cancel in the Versions tab
- [ ] Pro binary support (license-gated releases)
- [ ] Verify the `SHA256SUMS.sig` signature, not just the digest

### Profiles & sessions
- [ ] Drag-to-reorder profiles (the `sort_order` column is reserved for this)
- [ ] Live CDP tab-title polling into the sidebar subtitle
- [ ] Per-profile launch/stop buttons in the editor header (shortcuts already cover it)
- [ ] Real through-proxy reachability check for "Test Connection"
      (currently echoes the composed proxy string)
- [ ] Cookie / session import & export
- [ ] Profile templates and bulk-create
- [ ] Tags-based filtering and saved views in the sidebar

### Stealth & networking
- [ ] **Authenticated proxy support** — Chromium's `--proxy-server` rejects inline
      `user:pass@` credentials (causes `ERR_NO_SUPPORTED_PROXIES`), so credentials
      are currently stripped from the launch flag. Handle proxy auth via CDP
      (`Fetch.enable` + `Fetch.continueWithAuth`) so authenticated proxies work
      without a 407 prompt.
- [ ] Proxy rotation / proxy pools
- [ ] Browser-extension manager
- [ ] GeoIP preview (show the resolved timezone/locale before launch)

### Platform & UX
- [ ] Multi-language UI (currently English only)
- [ ] Embedded Chromium view inside the app (currently separate windows)
- [ ] Cloud sync of profiles across machines
- [ ] Light/dark theme polish and density options

## License

- **App code** (this repo): MIT.
- **CloakBrowser binary**: downloaded at runtime from the upstream GitHub Releases;
  subject to its own license. The app does not redistribute it.
