# CloakManager — Native macOS UI Redesign

**Date:** 2026-06-26
**Status:** Approved design (pending implementation plan)

## Goal

Redesign CloakManager's UI to feel modern and native on macOS by adopting the
`macos_ui` design language in place of Material 3. The app keeps all existing
behavior (Riverpod state, profile CRUD, launch/stop, proxy test, binary
download/onboarding); only the presentation layer changes.

## Decisions

- **Framework:** Adopt `macos_ui` (most native).
- **Scope:** All screens — sidebar, editor, settings, onboarding.
- **Theme:** Follow macOS system light/dark and system accent color.
- **Editor tabs:** `MacosSegmentedControl` centered in the window toolbar
  (Finder / System Settings style), with action buttons on the toolbar's right.
- **Settings:** Open as a native modal `MacosSheet` over the main window.
- **Profile icons:** Switch from Material icons to Cupertino / SF-style icons.

## Dependencies (new)

Add to `pubspec.yaml`:

- `macos_ui` — macOS widget set and themes.
- `system_theme` — read and listen to the macOS system accent color.
- `macos_window_utils` — native translucent, full-size-content titlebar so the
  toolbar blends with the traffic lights.

## Architecture changes

### Window chrome & entry (`lib/main.dart`, `macos/Runner/MainFlutterWindow.swift`)

- `main()`: `WidgetsFlutterBinding.ensureInitialized()`, then
  `WindowManipulator.initialize()` (from `macos_window_utils`) and configure a
  transparent / full-size-content titlebar. Read `SystemTheme.accentColor`
  before `runApp`.
- `MainFlutterWindow.swift`: enable full-size content view so Flutter draws
  under the titlebar.

### Theme (`lib/theme/app_theme.dart` — new)

- Build `MacosThemeData.light()` and `.dark()`, injecting the live system accent
  color into both.
- Exposed as helpers consumed by `app.dart`.

### App root (`lib/app.dart`)

- Replace `MaterialApp` with `MacosApp`:
  - `theme:` light macOS theme, `darkTheme:` dark macOS theme,
    `themeMode: ThemeMode.system`.
  - `home: const HomeShell()` (unchanged routing logic).

### Home shell (`lib/screens/home/home_shell.dart`)

- Same binary-state branching (loading / error / installed → HomeScreen,
  otherwise → OnboardingScreen). Loading/error states restyled with macOS
  widgets (`ProgressCircle`, centered text).

### Main window (`lib/screens/home/home_screen.dart` + `sidebar.dart`)

- Wrap the screen in `MacosWindow`:
  - **Sidebar** (`Sidebar`, resizable, min ~250px):
    - `top`: `MacosSearchField` (replaces Material search box; same
      `filterProfiles` logic).
    - body builder: grouped profile list rebuilt as custom selectable rows
      (Cupertino icon + name + running tab-title subtitle + green status dot)
      with hover and selection highlight.
    - `bottom`: gear (open Settings sheet) and `+` (new profile) icon buttons.
  - **Detail pane:** `MacosScaffold` whose `ToolBar` shows the profile name as
    title, the editor's `MacosSegmentedControl` in the center, and
    `ToolBarIconButton`s for Launch/Stop, Save, Delete on the right.
- `CallbackShortcuts` keyboard bindings preserved verbatim.
- Empty state ("Select or create a profile") restyled but text preserved (a
  test asserts this string).

### Editor (`lib/screens/editor/editor_screen.dart` + 4 tabs)

- Replace `DefaultTabController` / Material `TabBar` / `TabBarView` with a
  segmented control (in the toolbar) driving an `IndexedStack` of the four tab
  bodies. Draft state, save/launch/stop/delete logic unchanged.
- Form primitive swaps across all tabs:
  - `TextField` / `DraftTextField` → `MacosTextField`.
  - `Switch` → `MacosSwitch`.
  - `DropdownButton` → `MacosPopupButton`.
  - `FilledButton` / `OutlinedButton` → `PushButton` (primary/secondary).
  - `IconButton` → `MacosIconButton` / `ToolBarIconButton`.
- `LabeledField` kept; label column width/typography tightened to macOS spacing.
- Proxy "Test Connection" result panel restyled as a macOS card; spinner →
  `ProgressCircle`. Existing texts ("Test Connection", "Proxy OK",
  "Proxy test failed", latency/IP/geo lines) preserved (tests assert them).
- Advanced "Computed arguments" box restyled as a monospaced macOS panel;
  `computedArgsPreview` output unchanged.
- Delete confirmation dialog → `showMacosAlertDialog`.

### Onboarding (`lib/screens/onboarding/onboarding_screen.dart`)

- Centered macOS layout. `PushButton` for "Download CloakBrowser" / "Retry".
- `LinearProgressIndicator` → `ProgressBar`. All status texts preserved
  ("Download CloakBrowser", "%" progress, "Retry", error message).

### Settings (`lib/screens/settings/settings_screen.dart`)

- Opened as a modal `MacosSheet` from the sidebar gear button (was a pushed
  Material route).
- `MacosSegmentedControl` toggles **Versions / About**.
- `VersionsList` rebuilt with macOS list rows; "Download latest" → `PushButton`,
  delete → `MacosIconButton`, "active" badge preserved. `VersionsList` stays a
  pure presentational widget (a test renders it directly).

### Shared widgets

- `lib/widgets/draft_text_field.dart`: render `MacosTextField` (keep persistent
  controller behavior and API).
- `lib/widgets/status_dot.dart`: use `MacosColors.systemGreen` / secondary gray.
- `lib/widgets/icon_catalog.dart`: remap the same name keys to `CupertinoIcons`;
  fallback becomes `CupertinoIcons.person`. `IconCatalog.names` unchanged.
- `lib/widgets/labeled_field.dart`: minor spacing/typography tuning.

## Test impact

- **Logic tests unchanged:** `sidebar_test` (filterProfiles), `editor_test`
  (computedArgsPreview), database/dao/provider/selection tests.
- **`icon_catalog_test`:** update fallback assertion from `Icons.person` to
  `CupertinoIcons.person`; `names` contains 'person' still holds.
- **Widget-test harness updates** (wrap pumps so a `MacosTheme` ancestor
  exists — e.g. `MacosApp` instead of `MaterialApp`):
  - `home_shell_test` — assertions on `HomeScreen` / `OnboardingScreen` types
    and "Select or create a profile" text preserved.
  - `proxy_tab_test` — wrap in macOS theme; text assertions preserved.
  - `settings_test` — wrap in macOS theme; "active" + version text preserved.
  - `onboarding_test` — wrap in macOS theme; replace
    `find.byType(LinearProgressIndicator)` with `find.byType(ProgressBar)`;
    text assertions preserved.

## Out of scope

- No changes to `cloak_core` package, data model, launch/proxy logic, or
  persistence.
- No new features; presentation only.
- Windows/Linux desktop styling unchanged (macos_ui targets macOS; other
  platforms continue to render via the same widgets, acceptable for this pass).

## Success criteria

- App builds and runs on macOS with native window chrome, system light/dark,
  and system accent color.
- All screens use `macos_ui` widgets; no Material `Scaffold`/`AppBar`/`TabBar`
  remain in the UI layer.
- `flutter analyze` clean; `flutter test` green after the noted test updates.
