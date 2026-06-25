# CloakManager Implementation Plans

Cross-platform (Windows/Linux/macOS) Flutter desktop manager for CloakHQ/CloakBrowser.
Design spec: [`../specs/2026-06-25-cloakmanager-crossplatform-design.md`](../specs/2026-06-25-cloakmanager-crossplatform-design.md).

Implement the milestones **in order**. Each produces working, independently testable software.

| # | Plan | Delivers | Tested with |
|---|---|---|---|
| M1 | [m1-cloak-core-foundation](2026-06-25-m1-cloak-core-foundation.md) | Pure-Dart models, `StealthArgsBuilder`, `PlatformInfo`, `PortAllocator` | `dart test` |
| M2 | [m2-binary-management](2026-06-25-m2-binary-management.md) | `AppPaths`, chunked+resumable download, SHA-256 verify, extract, multi-version manifest | `dart test` (mock `HttpServer`) |
| M3 | [m3-launcher-cdp](2026-06-25-m3-launcher-cdp.md) | `LaunchArgsComposer`, `BrowserLauncher`, `ProcessRegistry`, `CdpClient` | `dart test` (spawn seam + mock CDP) |
| M4 | [m4-flutter-shell-persistence](2026-06-25-m4-flutter-shell-persistence.md) | Flutter app, Drift DB + `ProfileDao`, Riverpod state, onboarding gate | `flutter test` (in-memory Drift) |
| M5 | [m5-ui-full-parity](2026-06-25-m5-ui-full-parity.md) | Onboarding, sidebar, 4-tab editor, settings/versions, shortcuts, launch/stop | `flutter test` + manual run |

**Prerequisite:** Flutter SDK (includes Dart) with desktop enabled. M1–M3 only need `dart`; M4–M5 need `flutter`.
