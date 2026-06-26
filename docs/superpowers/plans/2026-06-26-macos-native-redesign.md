# CloakManager Native macOS Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace CloakManager's Material 3 UI with the native `macos_ui` design language across all screens, following the system light/dark mode and accent color.

**Architecture:** Swap `MaterialApp` for `MacosApp`, render the main window with `MacosWindow` (native translucent `Sidebar` + `MacosScaffold`/`ToolBar`), drive the editor tabs with a toolbar `MacosSegmentedControl`, and open Settings as a `MacosSheet`. State management (Riverpod), data model, launch/proxy logic, and persistence are unchanged — presentation only. Material widgets remain renderable mid-migration because `MacosApp` registers the default Material/Cupertino localization delegates.

**Tech Stack:** Flutter (stable 3.44.4), Dart 3, `macos_ui ^2.2.2`, `system_theme`, `macos_window_utils` (transitively via `macos_ui`), Riverpod, Drift.

## Global Constraints

- Flutter stable channel only; `macos_ui` requires Flutter `>= 3.35.0` (installed: 3.44.4). One line each below copied from the spec:
- Theme follows macOS system light/dark via `themeMode: ThemeMode.system`, plus the live system accent color.
- Editor tab switcher is a `MacosSegmentedControl` in the window toolbar; action buttons (Launch/Stop, Save, Delete) on the toolbar.
- Settings opens as a native modal `MacosSheet`.
- Profile icons use Cupertino / SF-style icons (`CupertinoIcons`); fallback is `CupertinoIcons.person`.
- No changes to `packages/cloak_core`, the data model, or launch/proxy logic.
- The empty-state string `'Select or create a profile'` must be preserved verbatim (asserted by `home_shell_test`).
- All proxy-panel strings (`'Test Connection'`, `'Proxy OK'`, `'Proxy test failed'`, latency/IP/geo lines) preserved (asserted by `proxy_tab_test`).
- All onboarding strings preserved (`'Download CloakBrowser'`, `'Retry'`, `%` progress, error message).
- After every task: `flutter analyze` clean and `flutter test` green.

---

### Task 1: Add dependencies and native window chrome

**Files:**
- Modify: `pubspec.yaml` (dependencies)
- Modify: `lib/main.dart`
- Modify: `macos/Runner/MainFlutterWindow.swift`

**Interfaces:**
- Produces: `macos_ui`, `system_theme`, `macos_window_utils` available to the project; native window initialized for the modern unified toolbar look.

- [ ] **Step 1: Add dependencies to `pubspec.yaml`**

Under `dependencies:` (after `path: ^1.9.0`), add:

```yaml
  macos_ui: ^2.2.2
  system_theme: ^3.0.0
  macos_window_utils: ^1.9.0
```

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: resolves successfully, `pubspec.lock` updated with the three packages.

- [ ] **Step 3: Initialize the native window in `lib/main.dart`**

Replace the entire file with:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:system_theme/system_theme.dart';

import 'app.dart';

Future<void> _configureWindow() async {
  const config = MacosWindowUtilsConfig(
    toolbarStyle: NSWindowToolbarStyle.unified,
  );
  await config.apply();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemTheme.fallbackColor = const Color(0xFF5E81F4);
  await SystemTheme.accentColor.load();
  await _configureWindow();
  runApp(const ProviderScope(child: CloakManagerApp()));
}
```

- [ ] **Step 4: Update `macos/Runner/MainFlutterWindow.swift` for macos_window_utils**

Replace the entire file with:

```swift
import Cocoa
import FlutterMacOS
import macos_window_utils

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let windowFrame = self.frame
    let macOSWindowUtilsViewController = MacOSWindowUtilsViewController()
    self.contentViewController = macOSWindowUtilsViewController
    self.setFrame(windowFrame, display: true)

    /* Initialize the macos_window_utils plugin */
    MainFlutterWindowManipulator.start(mainFlutterWindow: self)

    RegisterGeneratedPlugins(registry: macOSWindowUtilsViewController.flutterViewController)

    super.awakeFromNib()
  }
}
```

- [ ] **Step 5: Verify analyze and tests still pass**

Run: `flutter analyze`
Expected: No issues found.
Run: `flutter test`
Expected: All tests pass (UI unchanged so far; `app.dart` still `MaterialApp`).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart macos/Runner/MainFlutterWindow.swift
git commit -m "build: add macos_ui deps and native window chrome

Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>"
```

---

### Task 2: MacosApp root, theme, onboarding, and home-shell states

**Files:**
- Create: `lib/theme/app_theme.dart`
- Modify: `lib/app.dart`
- Modify: `lib/screens/home/home_shell.dart`
- Modify: `lib/screens/onboarding/onboarding_screen.dart`
- Test: `test/onboarding_test.dart`, `test/home_shell_test.dart`

**Interfaces:**
- Consumes: `binaryStateProvider` (unchanged).
- Produces: `buildLightTheme()` / `buildDarkTheme()` returning `MacosThemeData`; app root is `MacosApp`; onboarding + shell loading/error states rendered with `macos_ui`.

- [ ] **Step 1: Update `test/onboarding_test.dart` to expect macOS widgets**

Replace the entire file with:

```dart
import 'package:cloakmanager/screens/onboarding/onboarding_screen.dart';
import 'package:cloakmanager/state/binary_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, BinaryInstallState s) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [binaryStateProvider.overrideWith(() => _Stub(s))],
      child: const MacosApp(home: OnboardingScreen()),
    ));
    await tester.pump();
  }

  testWidgets('shows download button when not installed', (tester) async {
    await pump(tester, const NotInstalled());
    expect(find.text('Download CloakBrowser'), findsOneWidget);
  });

  testWidgets('shows progress while downloading', (tester) async {
    await pump(tester, const Downloading(0.5, 50, 100));
    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget);
  });

  testWidgets('shows retry on failure', (tester) async {
    await pump(tester, const Failed('boom'));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });
}

class _Stub extends BinaryStateController {
  _Stub(this._s);
  final BinaryInstallState _s;
  @override
  Future<BinaryInstallState> build() async => _s;
}
```

- [ ] **Step 2: Update `test/home_shell_test.dart` to use MacosApp**

In `test/home_shell_test.dart`, change the imports and the `pump` wrapper only:
- Add `import 'package:macos_ui/macos_ui.dart';`
- Replace `child: const MaterialApp(home: HomeShell()),` with `child: const MacosApp(home: HomeShell()),`

Leave the rest (assertions on `OnboardingScreen`, `HomeScreen`, and the `'Select or create a profile'` text) unchanged.

- [ ] **Step 3: Run the two tests to verify they fail**

Run: `flutter test test/onboarding_test.dart test/home_shell_test.dart`
Expected: FAIL — `ProgressBar` not found / `MacosApp` undefined until source is updated, or macOS widgets lack a `MacosTheme`.

- [ ] **Step 4: Create `lib/theme/app_theme.dart`**

```dart
import 'package:macos_ui/macos_ui.dart';
import 'package:system_theme/system_theme.dart';

MacosThemeData buildLightTheme() => MacosThemeData.light().copyWith(
      primaryColor: SystemTheme.accentColor.accent,
    );

MacosThemeData buildDarkTheme() => MacosThemeData.dark().copyWith(
      primaryColor: SystemTheme.accentColor.accent,
    );
```

- [ ] **Step 5: Convert `lib/app.dart` to `MacosApp`**

Replace the entire file with:

```dart
import 'package:flutter/material.dart' show ThemeMode;
import 'package:macos_ui/macos_ui.dart';

import 'screens/home/home_shell.dart';
import 'theme/app_theme.dart';

class CloakManagerApp extends StatelessWidget {
  const CloakManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'CloakManager',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
```

- [ ] **Step 6: Convert `lib/screens/home/home_shell.dart` loading/error states**

Replace the entire file with:

```dart
import 'package:macos_ui/macos_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/binary_state.dart';
import '../onboarding/onboarding_screen.dart';
import 'home_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(binaryStateProvider);
    return state.when(
      loading: () => const Center(child: ProgressCircle()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (s) => switch (s) {
        Installed() => const HomeScreen(),
        _ => const OnboardingScreen(),
      },
    );
  }
}
```

- [ ] **Step 7: Convert `lib/screens/onboarding/onboarding_screen.dart`**

Replace the entire file with:

```dart
import 'package:macos_ui/macos_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/binary_state.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(binaryStateProvider);
    final notifier = ref.read(binaryStateProvider.notifier);
    final typography = MacosTheme.of(context).typography;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: async.when(
          loading: () => const ProgressCircle(),
          error: (e, _) => Text('Error: $e'),
          data: (state) => switch (state) {
            Downloading(:final fraction, :final received, :final total) =>
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Downloading CloakBrowser…'),
                const SizedBox(height: 12),
                ProgressBar(value: (fraction * 100).clamp(0, 100)),
                const SizedBox(height: 8),
                Text('${(fraction * 100).round()}%  '
                    '(${received ~/ 1000000} / ${total ~/ 1000000} MB)'),
              ]),
            Verifying() => const Text('Verifying download…'),
            Extracting() => const Text('Extracting…'),
            Failed(:final message) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Download failed: $message'),
                  const SizedBox(height: 12),
                  PushButton(
                    controlSize: ControlSize.large,
                    onPressed: notifier.downloadLatest,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            _ => Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Welcome to CloakManager', style: typography.largeTitle),
                const SizedBox(height: 8),
                const Text(
                    'Download the stealth Chromium binary to get started.'),
                const SizedBox(height: 16),
                PushButton(
                  controlSize: ControlSize.large,
                  onPressed: notifier.downloadLatest,
                  child: const Text('Download CloakBrowser'),
                ),
              ]),
          },
        ),
      ),
    );
  }
}
```

Note: `ProgressBar.value` is a `0–100` percentage in `macos_ui`.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/onboarding_test.dart test/home_shell_test.dart`
Expected: PASS.

- [ ] **Step 9: Verify full suite + analyze**

Run: `flutter analyze`
Expected: No issues.
Run: `flutter test`
Expected: All pass (`smoke_test` still passes — it asserts `find.byType(CloakManagerApp)`).

- [ ] **Step 10: Commit**

```bash
git add lib/theme/app_theme.dart lib/app.dart lib/screens/home/home_shell.dart lib/screens/onboarding/onboarding_screen.dart test/onboarding_test.dart test/home_shell_test.dart
git commit -m "feat(ui): MacosApp root, macOS theme, and onboarding redesign

Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>"
```

---

### Task 3: Shared widgets — Cupertino icons, status dot, fields, labels

**Files:**
- Modify: `lib/widgets/icon_catalog.dart`
- Modify: `lib/widgets/status_dot.dart`
- Modify: `lib/widgets/draft_text_field.dart`
- Modify: `lib/widgets/labeled_field.dart`
- Test: `test/icon_catalog_test.dart`

**Interfaces:**
- Produces: `IconCatalog.iconFor(String) -> IconData` (Cupertino), fallback `CupertinoIcons.person`; `DraftTextField` rendering `MacosTextField` with the same public API (`initialValue`, `onChanged`, `hintText`, `obscureText`, `maxLines`, `keyboardType`); `StatusDot(running:)`; `LabeledField(label:, child:)`.

- [ ] **Step 1: Update `test/icon_catalog_test.dart`**

Replace the first test's fallback assertion. Change imports and body:

```dart
import 'package:cloakmanager/widgets/color_hex.dart';
import 'package:cloakmanager/widgets/icon_catalog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iconFor returns a fallback for unknown names', () {
    expect(IconCatalog.iconFor('definitely-not-an-icon'), CupertinoIcons.person);
    expect(IconCatalog.names, contains('person'));
  });

  test('colorFromHex parses #RRGGBB', () {
    expect(colorFromHex('#5E81F4'), const Color(0xFF5E81F4));
    expect(colorFromHex('bad'), const Color(0xFF5E81F4)); // fallback
  });
}
```

- [ ] **Step 2: Run icon test to verify it fails**

Run: `flutter test test/icon_catalog_test.dart`
Expected: FAIL — `iconFor` still returns `Icons.person`.

- [ ] **Step 3: Convert `lib/widgets/icon_catalog.dart` to Cupertino icons**

Replace the entire file with:

```dart
import 'package:flutter/cupertino.dart';

/// Maps stored icon-name strings to Cupertino (SF-style) [IconData].
class IconCatalog {
  static const Map<String, IconData> _icons = {
    'person': CupertinoIcons.person,
    'work': CupertinoIcons.briefcase,
    'shopping': CupertinoIcons.cart,
    'shield': CupertinoIcons.shield,
    'globe': CupertinoIcons.globe,
    'star': CupertinoIcons.star,
    'bolt': CupertinoIcons.bolt,
    'bug': CupertinoIcons.ant,
    'rocket': CupertinoIcons.rocket,
    'flask': CupertinoIcons.lab_flask,
  };

  static IconData iconFor(String name) => _icons[name] ?? CupertinoIcons.person;
  static List<String> get names => _icons.keys.toList();
}
```

- [ ] **Step 4: Convert `lib/widgets/status_dot.dart`**

Replace the entire file with:

```dart
import 'package:macos_ui/macos_ui.dart';

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.running});
  final bool running;

  @override
  Widget build(BuildContext context) => Icon(
        CupertinoIcons.circle_fill,
        size: 10,
        color: running ? MacosColors.systemGreenColor : MacosColors.systemGrayColor,
      );
}
```

- [ ] **Step 5: Convert `lib/widgets/draft_text_field.dart` to `MacosTextField`**

Replace the entire file with:

```dart
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

/// A text field that owns a persistent [TextEditingController], created once
/// from [initialValue], so the caret does not jump while typing. Give the
/// surrounding widget a new key to reset the field (e.g. switching profiles).
class DraftTextField extends StatefulWidget {
  const DraftTextField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final bool obscureText;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  State<DraftTextField> createState() => _DraftTextFieldState();
}

class _DraftTextFieldState extends State<DraftTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MacosTextField(
      controller: _controller,
      obscureText: widget.obscureText,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      keyboardType: widget.keyboardType,
      placeholder: widget.hintText,
      onChanged: widget.onChanged,
    );
  }
}
```

- [ ] **Step 6: Tighten `lib/widgets/labeled_field.dart` for macOS spacing**

Replace the entire file with:

```dart
import 'package:macos_ui/macos_ui.dart';

class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: MacosTheme.of(context).typography.body,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Run icon test to verify it passes**

Run: `flutter test test/icon_catalog_test.dart`
Expected: PASS.

- [ ] **Step 8: Verify analyze (full test suite runs in Task 4/5 where dependent screens are wrapped)**

Run: `flutter analyze`
Expected: No issues.

Note: `proxy_tab_test`, `editor_switch_test`, and `delete_profile_test` render these fields under a bare `MaterialApp`. They are updated to wrap in `MacosApp`/`MacosWindow` in Tasks 4–5. Until then they may fail because `MacosTextField` needs a `MacosTheme` ancestor. Run those specific tests after Task 5. Run the unaffected suite now:

Run: `flutter test test/icon_catalog_test.dart test/sidebar_test.dart test/editor_test.dart test/onboarding_test.dart test/settings_test.dart test/database_test.dart test/profile_dao_test.dart test/profile_list_test.dart test/providers_test.dart test/selection_test.dart test/proxy_tester_provider_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/icon_catalog.dart lib/widgets/status_dot.dart lib/widgets/draft_text_field.dart lib/widgets/labeled_field.dart test/icon_catalog_test.dart
git commit -m "feat(ui): Cupertino icons and macOS form primitives

Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>"
```

---

### Task 4: Editor screen — MacosScaffold, toolbar segmented control, actions

**Files:**
- Modify: `lib/screens/editor/editor_screen.dart`
- Test: `test/editor_switch_test.dart`, `test/delete_profile_test.dart`

**Interfaces:**
- Consumes: `findById`, `profileListProvider`, `runningProfilesProvider`, `launchProfile`, `stopProfile`, `deleteProfile`, `selectedProfileIdProvider` (unchanged); the four tab widgets `GeneralTab`, `StealthTab`, `ProxyTab`, `AdvancedTab` (still Material content until Task 5).
- Produces: `EditorScreen({required String profileId})` returning a `MacosScaffold` whose `ToolBar` hosts a `MacosSegmentedControl` (General/Stealth/Proxy/Advanced) as the title and `ToolBarIconButton`s labeled `Launch`/`Stop`, `Save`, `Delete`. Must be hosted inside a `MacosWindow`.

- [ ] **Step 1: Update `test/editor_switch_test.dart`**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/data/database.dart';
import 'package:cloakmanager/data/profile_dao.dart';
import 'package:cloakmanager/screens/editor/editor_screen.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';

Profile _profile(String id, String name) => Profile(
      id: id,
      name: name,
      colorHex: '#fff',
      iconName: 'person',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      stealth: StealthConfig.defaults(),
    );

void main() {
  late AppDatabase db;
  late ProfileDao dao;

  setUp(() async {
    db = AppDatabase.memory();
    dao = ProfileDao(db);
    await dao.upsert(_profile('p1', 'Alpha'));
    await dao.upsert(_profile('p2', 'Beta'));
  });
  tearDown(() => db.close());

  String nameFieldText(WidgetTester tester) => tester
      .widget<MacosTextField>(find.byType(MacosTextField).first)
      .controller!
      .text;

  testWidgets('editor shows a Launch button and resets when profile changes',
      (tester) async {
    var selected = 'p1';
    late StateSetter rebuild;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        profileDaoProvider.overrideWithValue(dao),
      ],
      child: MacosApp(
        home: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return MacosWindow(
            child: EditorScreen(key: ValueKey(selected), profileId: selected),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Launch'), findsOneWidget);
    expect(nameFieldText(tester), 'Alpha');

    rebuild(() => selected = 'p2');
    await tester.pumpAndSettle();
    expect(nameFieldText(tester), 'Beta');
  });
}
```

- [ ] **Step 2: Update `test/delete_profile_test.dart`**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/data/database.dart';
import 'package:cloakmanager/data/profile_dao.dart';
import 'package:cloakmanager/screens/editor/editor_screen.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';

Profile _profile(String id, String name) => Profile(
      id: id,
      name: name,
      colorHex: '#fff',
      iconName: 'person',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      stealth: StealthConfig.defaults(),
    );

void main() {
  testWidgets('delete button removes the profile after confirmation',
      (tester) async {
    final db = AppDatabase.memory();
    final dao = ProfileDao(db);
    addTearDown(db.close);
    await dao.upsert(_profile('p1', 'Alpha'));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        profileDaoProvider.overrideWithValue(dao),
      ],
      child: const MacosApp(
        home: MacosWindow(child: EditorScreen(profileId: 'p1')),
      ),
    ));
    await tester.pumpAndSettle();

    // Toolbar delete button (only 'Delete' label on screen before dialog).
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete profile?'), findsOneWidget);

    // Confirm via the dialog's primary push button.
    await tester.tap(find.widgetWithText(PushButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await dao.all(), isEmpty);
  });
}
```

- [ ] **Step 3: Run editor tests to verify they fail**

Run: `flutter test test/editor_switch_test.dart test/delete_profile_test.dart`
Expected: FAIL — current `EditorScreen` has no `MacosScaffold`/toolbar, uses `FilledButton`, and the dialog is a Material `AlertDialog`.

- [ ] **Step 4: Rewrite `lib/screens/editor/editor_screen.dart`**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../state/launch_actions.dart';
import '../../state/profile_list.dart';
import '../../state/selection.dart';
import '../home/home_screen.dart' show findById;
import 'advanced_tab.dart';
import 'general_tab.dart';
import 'proxy_tab.dart';
import 'stealth_tab.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.profileId});
  final String profileId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  Profile? _draft;
  final _tabController = MacosTabController(initialIndex: 0, length: 4);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profileListProvider).valueOrNull ?? const [];
    final current = findById(profiles, widget.profileId);
    if (current == null) {
      return const Center(child: Text('Profile not found'));
    }
    final draft = _draft ??= current;
    void onChanged(Profile next) => setState(() => _draft = next);

    final canSave = draft.name.trim().isNotEmpty;
    final running = ref.watch(runningProfilesProvider).valueOrNull ?? <String>{};
    final isRunning = running.contains(widget.profileId);

    return MacosScaffold(
      toolBar: ToolBar(
        title: SizedBox(
          width: 340,
          child: MacosSegmentedControl(
            controller: _tabController,
            tabs: const [
              MacosTab(label: 'General'),
              MacosTab(label: 'Stealth'),
              MacosTab(label: 'Proxy'),
              MacosTab(label: 'Advanced'),
            ],
          ),
        ),
        titleWidth: 360,
        actions: [
          ToolBarIconButton(
            label: isRunning ? 'Stop' : 'Launch',
            showLabel: true,
            icon: MacosIcon(
              isRunning ? CupertinoIcons.stop_fill : CupertinoIcons.play_fill,
            ),
            onPressed: () async {
              if (isRunning) {
                await stopProfile(ref, widget.profileId);
              } else {
                final error = await launchProfile(ref, draft);
                if (error != null && context.mounted) {
                  await showMacosAlertDialog(
                    context: context,
                    builder: (_) => MacosAlertDialog(
                      appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle),
                      title: const Text('Launch failed'),
                      message: Text(error),
                      primaryButton: PushButton(
                        controlSize: ControlSize.large,
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ),
                  );
                }
              }
            },
          ),
          ToolBarIconButton(
            label: 'Save',
            showLabel: true,
            icon: const MacosIcon(CupertinoIcons.tray_arrow_down),
            onPressed: canSave
                ? () async {
                    await ref.read(profileListProvider.notifier).save(
                        draft.copyWith(updatedAt: DateTime.now().toUtc()));
                  }
                : null,
          ),
          ToolBarIconButton(
            label: 'Delete',
            showLabel: true,
            icon: const MacosIcon(CupertinoIcons.trash),
            onPressed: () => _confirmDelete(context, draft.name),
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) => AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) => IndexedStack(
              index: _tabController.index,
              children: [
                GeneralTab(draft: draft, onChanged: onChanged),
                StealthTab(draft: draft, onChanged: onChanged),
                ProxyTab(draft: draft, onChanged: onChanged),
                AdvancedTab(draft: draft, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final confirmed = await showMacosAlertDialog<bool>(
      context: context,
      builder: (ctx) => MacosAlertDialog(
        appIcon: const MacosIcon(CupertinoIcons.trash),
        title: const Text('Delete profile?'),
        message: Text(
          'This permanently removes "$name" and its browser data. '
          'This cannot be undone.',
          textAlign: TextAlign.center,
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          color: MacosColors.systemRedColor,
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (confirmed != true) return;
    await deleteProfile(ref, widget.profileId);
    ref.read(selectedProfileIdProvider.notifier).state = null;
  }
}
```

Note: previously Save/Launch showed a `SnackBar` ("Saved" / errors). macOS has no snackbar; Save is silent (the toolbar action completes), and launch errors use a `MacosAlertDialog`. No test asserts the "Saved" snackbar.

- [ ] **Step 5: Run editor tests to verify they pass**

Run: `flutter test test/editor_switch_test.dart test/delete_profile_test.dart`
Expected: PASS.

- [ ] **Step 6: Verify analyze**

Run: `flutter analyze`
Expected: No issues. (The four tab bodies are still Material content rendered inside `ContentArea`; they render fine under `MacosApp`.)

- [ ] **Step 7: Commit**

```bash
git add lib/screens/editor/editor_screen.dart test/editor_switch_test.dart test/delete_profile_test.dart
git commit -m "feat(ui): macOS editor scaffold with toolbar segmented control

Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>"
```

---

### Task 5: Editor tabs — macOS popups, switches, and panels

**Files:**
- Modify: `lib/screens/editor/general_tab.dart`
- Modify: `lib/screens/editor/stealth_tab.dart`
- Modify: `lib/screens/editor/proxy_tab.dart`
- Modify: `lib/screens/editor/advanced_tab.dart`
- Test: `test/proxy_tab_test.dart`

**Interfaces:**
- Consumes: `DraftTextField` (now `MacosTextField`-backed), `LabeledField`, `IconCatalog`, `proxyTesterProvider`, `computedArgsPreview` (unchanged signature).
- Produces: all four tabs rendered with `macos_ui` controls; `computedArgsPreview(Profile)` unchanged.

- [ ] **Step 1: Update `test/proxy_tab_test.dart` to host the tab in macOS context**

Replace the `_pump` helper and imports only. Change:
- `import 'package:flutter/material.dart';` → `import 'package:flutter/widgets.dart';` and add `import 'package:macos_ui/macos_ui.dart';`
- Replace the `_pump` body's widget tree with:

```dart
Future<void> _pump(WidgetTester tester, ProxyTester fake) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [proxyTesterProvider.overrideWithValue(fake)],
    child: MacosApp(
      home: MacosWindow(
        child: MacosScaffold(
          children: [
            ContentArea(
              builder: (context, _) =>
                  ProxyTab(draft: _profile(), onChanged: (_) {}),
            ),
          ],
        ),
      ),
    ),
  ));
  await tester.pump();
}
```

Leave both `testWidgets` bodies and their assertions (`'Test Connection'`, `'Proxy OK'`, `'203.0.113.7'`, `'Paris, France'`, `'Proxy test failed'`, `'bad creds'`) unchanged.

- [ ] **Step 2: Run proxy test to verify it fails**

Run: `flutter test test/proxy_tab_test.dart`
Expected: FAIL — `ProxyTab` still uses Material `Switch`/`DropdownButton`/`OutlinedButton` and the `MacosTextField` inside needs the macOS tree (now provided), but the tap target `OutlinedButton`/panel styling differs; primarily the test compiles against the new tree once the tab is converted.

- [ ] **Step 3: Convert `lib/screens/editor/general_tab.dart`**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../widgets/draft_text_field.dart';
import '../../widgets/icon_catalog.dart';
import '../../widgets/labeled_field.dart';

class GeneralTab extends StatelessWidget {
  const GeneralTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final iconValue = IconCatalog.names.contains(draft.iconName)
        ? draft.iconName
        : IconCatalog.names.first;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LabeledField(
          label: 'Name',
          child: DraftTextField(
            initialValue: draft.name,
            onChanged: (v) => onChanged(draft.copyWith(name: v)),
          ),
        ),
        LabeledField(
          label: 'Group',
          child: DraftTextField(
            initialValue: draft.groupName ?? '',
            onChanged: (v) =>
                onChanged(draft.copyWith(groupName: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Icon',
          child: Align(
            alignment: Alignment.centerLeft,
            child: MacosPopupButton<String>(
              value: iconValue,
              onChanged: (v) => onChanged(draft.copyWith(iconName: v)),
              items: [
                for (final n in IconCatalog.names)
                  MacosPopupMenuItem(
                    value: n,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      MacosIcon(IconCatalog.iconFor(n)),
                      const SizedBox(width: 8),
                      Text(n),
                    ]),
                  ),
              ],
            ),
          ),
        ),
        LabeledField(
          label: 'Persistent',
          child: Align(
            alignment: Alignment.centerLeft,
            child: MacosSwitch(
              value: draft.persistent,
              onChanged: (v) => onChanged(draft.copyWith(persistent: v)),
            ),
          ),
        ),
        LabeledField(
          label: 'Start URL',
          child: DraftTextField(
            initialValue: draft.startUrl,
            onChanged: (v) => onChanged(draft.copyWith(startUrl: v)),
          ),
        ),
        LabeledField(
          label: 'Notes',
          child: DraftTextField(
            initialValue: draft.notes,
            maxLines: 3,
            onChanged: (v) => onChanged(draft.copyWith(notes: v)),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Convert `lib/screens/editor/stealth_tab.dart`**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../widgets/draft_text_field.dart';
import '../../widgets/labeled_field.dart';

class StealthTab extends StatelessWidget {
  const StealthTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  StealthConfig get s => draft.stealth;
  void _set(StealthConfig next) => onChanged(draft.copyWith(stealth: next));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _section(context, 'Identity'),
        LabeledField(
          label: 'Fingerprint seed',
          child: DraftTextField(
            initialValue: s.fingerprintSeed ?? '',
            hintText: 'blank = random each launch',
            onChanged: (v) =>
                _set(s.copyWith(fingerprintSeed: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Fingerprint noise',
          child: Align(
            alignment: Alignment.centerLeft,
            child: MacosSwitch(
              value: s.noiseEnabled,
              onChanged: (v) => _set(s.copyWith(noiseEnabled: v)),
            ),
          ),
        ),
        _section(context, 'Platform'),
        LabeledField(
          label: 'Platform',
          child: _popup<SpoofPlatform>(
            value: s.platform,
            values: SpoofPlatform.values,
            label: (e) => e.name,
            onChanged: (v) => _set(s.copyWith(platform: v)),
          ),
        ),
        _section(context, 'Brand'),
        LabeledField(
          label: 'Brand',
          child: _popup<BrowserBrand>(
            value: s.brand,
            values: BrowserBrand.values,
            label: (e) => e.name,
            onChanged: (v) => _set(s.copyWith(brand: v)),
          ),
        ),
        LabeledField(
          label: 'Brand version',
          child: DraftTextField(
            initialValue: s.brandVersion ?? '',
            hintText: s.brand.defaultVersion,
            onChanged: (v) =>
                _set(s.copyWith(brandVersion: v.isEmpty ? null : v)),
          ),
        ),
        _section(context, 'Hardware'),
        _intField(context, 'CPU cores', s.hardwareConcurrency,
            (n) => _set(s.copyWith(hardwareConcurrency: n))),
        _intField(context, 'Device memory (GB)', s.deviceMemoryGB,
            (n) => _set(s.copyWith(deviceMemoryGB: n))),
        _intField(context, 'Screen width', s.screenWidth,
            (n) => _set(s.copyWith(screenWidth: n))),
        _intField(context, 'Screen height', s.screenHeight,
            (n) => _set(s.copyWith(screenHeight: n))),
        _section(context, 'Locale'),
        _strField(context, 'Timezone', s.timezone,
            (v) => _set(s.copyWith(timezone: v)), hint: 'America/New_York'),
        _strField(context, 'Locale', s.locale,
            (v) => _set(s.copyWith(locale: v)), hint: 'en-US'),
        _section(context, 'GPU'),
        _strField(context, 'GPU vendor', s.gpuVendor,
            (v) => _set(s.copyWith(gpuVendor: v))),
        _strField(context, 'GPU renderer', s.gpuRenderer,
            (v) => _set(s.copyWith(gpuRenderer: v))),
        _section(context, 'Advanced'),
        _intField(context, 'Storage quota (MB)', s.storageQuotaMB,
            (n) => _set(s.copyWith(storageQuotaMB: n))),
        LabeledField(
          label: 'WebRTC IP policy',
          child: _popup<WebRtcIpPolicy>(
            value: s.webrtcIpPolicy,
            values: WebRtcIpPolicy.values,
            label: (e) => e.name,
            onChanged: (v) => _set(s.copyWith(webrtcIpPolicy: v)),
          ),
        ),
        if (s.webrtcIpPolicy == WebRtcIpPolicy.spoofExplicit)
          _strField(context, 'Explicit WebRTC IP', s.explicitWebRtcIp,
              (v) => _set(s.copyWith(explicitWebRtcIp: v))),
      ],
    );
  }

  Widget _section(BuildContext c, String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(title, style: MacosTheme.of(c).typography.title3),
      );

  Widget _popup<T>({
    required T value,
    required List<T> values,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) =>
      Align(
        alignment: Alignment.centerLeft,
        child: MacosPopupButton<T>(
          value: value,
          onChanged: onChanged,
          items: [
            for (final e in values)
              MacosPopupMenuItem(value: e, child: Text(label(e))),
          ],
        ),
      );

  Widget _strField(BuildContext c, String label, String? value,
          ValueChanged<String?> onChanged, {String? hint}) =>
      LabeledField(
        label: label,
        child: DraftTextField(
          initialValue: value ?? '',
          hintText: hint,
          onChanged: (v) => onChanged(v.isEmpty ? null : v),
        ),
      );

  Widget _intField(BuildContext c, String label, int? value,
          ValueChanged<int?> onChanged) =>
      LabeledField(
        label: label,
        child: DraftTextField(
          initialValue: value?.toString() ?? '',
          keyboardType: TextInputType.number,
          onChanged: (v) => onChanged(v.isEmpty ? null : int.tryParse(v)),
        ),
      );
}
```

- [ ] **Step 5: Convert `lib/screens/editor/proxy_tab.dart`**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

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

  void _set(ProxyConfig next) => widget.onChanged(widget.draft
      .copyWith(stealth: widget.draft.stealth.copyWith(proxy: next)));

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
      padding: const EdgeInsets.all(20),
      children: [
        LabeledField(
          label: 'Enabled',
          child: Align(
            alignment: Alignment.centerLeft,
            child: MacosSwitch(
                value: px.enabled,
                onChanged: (v) => _set(px.copyWith(enabled: v))),
          ),
        ),
        LabeledField(
          label: 'Type',
          child: Align(
            alignment: Alignment.centerLeft,
            child: MacosPopupButton<ProxyType>(
              value: px.type,
              onChanged: (v) => _set(px.copyWith(type: v)),
              items: [
                for (final t in ProxyType.values)
                  MacosPopupMenuItem(value: t, child: Text(t.name)),
              ],
            ),
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
            child: MacosSwitch(
                value: px.geoipEnabled,
                onChanged: (v) => _set(px.copyWith(geoipEnabled: v))),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: PushButton(
            controlSize: ControlSize.large,
            secondary: true,
            onPressed: _canTest ? _test : null,
            child: const Text('Test Connection'),
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
    final typography = MacosTheme.of(context).typography;
    if (testing) {
      return Row(
        children: const [
          SizedBox(width: 16, height: 16, child: ProgressCircle()),
          SizedBox(width: 12),
          Text('Testing…'),
        ],
      );
    }

    if (result == null) return const SizedBox.shrink();
    final r = result!;
    final ok = r.status == ProxyTestStatus.success;
    final color =
        ok ? MacosColors.systemGreenColor : MacosColors.systemRedColor;

    final lines = <String>[];
    if (ok) {
      if (r.latency != null) {
        lines.add('Latency: ${r.latency!.inMilliseconds} ms');
      }
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
              MacosIcon(
                  ok
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.xmark_circle_fill,
                  color: color,
                  size: 18),
              const SizedBox(width: 8),
              Text(ok ? 'Proxy OK' : 'Proxy test failed',
                  style: typography.headline.copyWith(color: color)),
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

Note: add `import 'package:flutter/cupertino.dart' show CupertinoIcons;` is not needed — `macos_ui` re-exports `CupertinoIcons`. If `flutter analyze` reports `CupertinoIcons` undefined, add `import 'package:flutter/cupertino.dart';` to the file.

- [ ] **Step 6: Convert `lib/screens/editor/advanced_tab.dart`**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../widgets/draft_text_field.dart';

/// Renders the exact launch argv (with placeholder dir/port) for the draft.
String computedArgsPreview(Profile draft) => LaunchArgsComposer.compose(
      profile: draft,
      userDataDir: '<profiles>/${draft.id}',
      debugPort: 9222,
    ).join('\n');

class AdvancedTab extends StatelessWidget {
  const AdvancedTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Custom Chromium args (one per line)',
            style: theme.typography.headline),
        const SizedBox(height: 6),
        DraftTextField(
          maxLines: 4,
          initialValue: draft.customArgs.join('\n'),
          onChanged: (v) => onChanged(draft.copyWith(
            customArgs: v
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
          )),
        ),
        const SizedBox(height: 16),
        Text('Environment variables (KEY=VALUE per line)',
            style: theme.typography.headline),
        const SizedBox(height: 6),
        DraftTextField(
          maxLines: 3,
          initialValue:
              draft.customEnv.entries.map((e) => '${e.key}=${e.value}').join('\n'),
          onChanged: (v) => onChanged(draft.copyWith(customEnv: _parseEnv(v))),
        ),
        const SizedBox(height: 16),
        Text('Computed arguments', style: theme.typography.headline),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.canvasColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MacosColors.systemGrayColor.withOpacity(0.3)),
          ),
          child: SelectableText(
            computedArgsPreview(draft),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }

  static Map<String, String> _parseEnv(String text) {
    final map = <String, String>{};
    for (final line in text.split('\n')) {
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
    }
    return map;
  }
}
```

- [ ] **Step 7: Run proxy test + editor tests + analyze**

Run: `flutter test test/proxy_tab_test.dart test/editor_switch_test.dart test/delete_profile_test.dart test/editor_test.dart`
Expected: PASS.
Run: `flutter analyze`
Expected: No issues. (If `CupertinoIcons` is reported undefined in `proxy_tab.dart`, add `import 'package:flutter/cupertino.dart';` and re-run.)

- [ ] **Step 8: Commit**

```bash
git add lib/screens/editor/general_tab.dart lib/screens/editor/stealth_tab.dart lib/screens/editor/proxy_tab.dart lib/screens/editor/advanced_tab.dart test/proxy_tab_test.dart
git commit -m "feat(ui): macOS controls across editor tabs

Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>"
```

---

### Task 6: Main window — MacosWindow with native sidebar

**Files:**
- Modify: `lib/screens/home/home_screen.dart`
- Modify: `lib/screens/home/sidebar.dart`

**Interfaces:**
- Consumes: `selectedProfileIdProvider`, `profileListProvider`, `runningProfilesProvider`, `tabTitlesProvider`, `launch/stop` actions, `filterProfiles` (kept), `IconCatalog`, `StatusDot`.
- Produces: `HomeScreen` returning a `MacosWindow` with a translucent `Sidebar` (search in `top`, grouped profile list in `builder`, new/settings buttons in `bottom`) and the detail pane (`EditorScreen` or empty state) as `child`. `filterProfiles(List<Profile>, String)` signature unchanged (asserted by `sidebar_test`). Settings is invoked via `openSettingsSheet(context, ref)` (added in Task 7).

- [ ] **Step 1: Rewrite `lib/screens/home/sidebar.dart`**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../state/profile_list.dart';
import '../../state/selection.dart';
import '../../state/tab_titles.dart';
import '../../widgets/icon_catalog.dart';
import '../../widgets/status_dot.dart';

/// Pure filter used by the sidebar search box. Matches name or any tag.
List<Profile> filterProfiles(List<Profile> profiles, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return profiles;
  return profiles
      .where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q)))
      .toList();
}

/// Grouped, selectable profile list rendered inside the macOS sidebar.
class SidebarProfileList extends ConsumerWidget {
  const SidebarProfileList({
    super.key,
    required this.query,
    required this.scrollController,
  });

  final String query;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profileListProvider);
    final running =
        ref.watch(runningProfilesProvider).valueOrNull ?? <String>{};
    final tabTitles =
        ref.watch(tabTitlesProvider).valueOrNull ?? const <String, String>{};
    final selected = ref.watch(selectedProfileIdProvider);
    final theme = MacosTheme.of(context);

    return profilesAsync.when(
      loading: () => const Center(child: ProgressCircle()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profiles) {
        final filtered = filterProfiles(profiles, query);
        final groups = <String, List<Profile>>{};
        for (final p in filtered) {
          groups.putIfAbsent(p.groupName ?? 'Ungrouped', () => []).add(p);
        }
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: [
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  entry.key.toUpperCase(),
                  style: theme.typography.caption1.copyWith(
                    color: MacosColors.systemGrayColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final p in entry.value)
                _ProfileRow(
                  profile: p,
                  selected: p.id == selected,
                  running: running.contains(p.id),
                  subtitle: running.contains(p.id) ? tabTitles[p.id] : null,
                  onTap: () => ref
                      .read(selectedProfileIdProvider.notifier)
                      .state = p.id,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.selected,
    required this.running,
    required this.subtitle,
    required this.onTap,
  });

  final Profile profile;
  final bool selected;
  final bool running;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    final bg = selected
        ? theme.primaryColor.withOpacity(0.18)
        : const Color(0x00000000);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            MacosIcon(IconCatalog.iconFor(profile.iconName), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption1
                            .copyWith(color: MacosColors.systemGrayColor)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            StatusDot(running: running),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Rewrite `lib/screens/home/home_screen.dart`**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../state/launch_actions.dart';
import '../../state/profile_list.dart';
import '../../state/selection.dart';
import '../editor/editor_screen.dart';
import '../settings/settings_screen.dart';
import 'sidebar.dart';

Profile? findById(List<Profile> profiles, String? id) {
  if (id == null) return null;
  for (final p in profiles) {
    if (p.id == id) return p;
  }
  return null;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedProfileIdProvider);
    final profiles = ref.watch(profileListProvider).valueOrNull ?? const [];
    final selected = findById(profiles, selectedId);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            () => _create(ref),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            () => _create(ref),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
            () => _launch(ref),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            () => _launch(ref),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true, shift: true):
            () => _stop(ref),
        const SingleActivator(LogicalKeyboardKey.keyR,
            control: true, shift: true): () => _stop(ref),
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true, shift: true):
            () => _stopAll(ref),
        const SingleActivator(LogicalKeyboardKey.keyW,
            control: true, shift: true): () => _stopAll(ref),
      },
      child: Focus(
        autofocus: true,
        child: MacosWindow(
          sidebar: Sidebar(
            minWidth: 250,
            startWidth: 280,
            maxWidth: 360,
            top: MacosSearchField(
              placeholder: 'Search',
              onChanged: (v) => setState(() => _query = v),
            ),
            builder: (context, scrollController) =>
                SidebarProfileList(query: _query, scrollController: scrollController),
            bottom: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MacosIconButton(
                    icon: const MacosIcon(CupertinoIcons.gear),
                    onPressed: () => openSettingsSheet(context),
                  ),
                  const SizedBox(width: 4),
                  MacosIconButton(
                    icon: const MacosIcon(CupertinoIcons.add),
                    onPressed: () => _create(ref),
                  ),
                ],
              ),
            ),
          ),
          child: selected == null
              ? const Center(child: Text('Select or create a profile'))
              : EditorScreen(key: ValueKey(selected.id), profileId: selected.id),
        ),
      ),
    );
  }

  Future<void> _create(WidgetRef ref) async {
    final p =
        await ref.read(profileListProvider.notifier).create('New Profile');
    ref.read(selectedProfileIdProvider.notifier).state = p.id;
  }

  Future<void> _launch(WidgetRef ref) async {
    final id = ref.read(selectedProfileIdProvider);
    if (id == null) return;
    final profiles = ref.read(profileListProvider).valueOrNull ?? const [];
    final profile = findById(profiles, id);
    if (profile == null) return;
    await launchProfile(ref, profile);
  }

  Future<void> _stop(WidgetRef ref) async {
    final id = ref.read(selectedProfileIdProvider);
    if (id != null) await stopProfile(ref, id);
  }

  Future<void> _stopAll(WidgetRef ref) => stopAllProfiles(ref);
}
```

Note: `openSettingsSheet(BuildContext)` is defined in Task 7 (`settings_screen.dart`). This task will not compile standalone — do Tasks 6 and 7 together before running tests, or temporarily stub `openSettingsSheet` and complete it in Task 7. Run tests at the end of Task 7.

- [ ] **Step 3: Commit (after Task 7 compiles)**

Deferred — see Task 7 Step 6, which stages and commits Tasks 6 + 7 together.

---

### Task 7: Settings as a MacosSheet

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart`
- Test: `test/settings_test.dart`

**Interfaces:**
- Consumes: `binaryManagerProvider`, `binaryStateProvider`.
- Produces: `openSettingsSheet(BuildContext context)` showing a `MacosSheet` with a `MacosSegmentedControl` (Versions/About); `VersionsList` remains a pure presentational widget with the same constructor parameters (`versions`, `activeVersion`, `onSetActive`, `onDelete`, `onDownloadLatest`) and still shows the `'active'` badge (asserted by `settings_test`).

- [ ] **Step 1: Update `test/settings_test.dart` to wrap in macOS theme**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/settings/settings_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';

void main() {
  testWidgets('Versions list renders installed versions', (tester) async {
    final versions = [
      InstalledVersion(
        version: '146.0.1',
        releaseTag: 'chromium-v146.0.1',
        appPath: 'binary/146.0.1',
        sizeBytes: 200000000,
        sha256: 'abc',
        installedAt: DateTime.utc(2026),
      ),
    ];
    await tester.pumpWidget(MacosApp(
      home: MacosWindow(
        child: MacosScaffold(
          children: [
            ContentArea(
              builder: (context, _) => VersionsList(
                versions: versions,
                activeVersion: '146.0.1',
                onSetActive: (_) {},
                onDelete: (_) {},
                onDownloadLatest: () {},
              ),
            ),
          ],
        ),
      ),
    ));
    expect(find.textContaining('146.0.1'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run settings test to verify it fails**

Run: `flutter test test/settings_test.dart`
Expected: FAIL — `VersionsList` still uses Material `Card`/`ListTile`/`FilledButton` and `openSettingsSheet` doesn't exist yet (compile error from `home_screen.dart` import in Task 6).

- [ ] **Step 3: Rewrite `lib/screens/settings/settings_screen.dart`**

Replace the entire file with:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../state/binary_state.dart';
import '../../state/providers.dart';

/// Opens the settings UI as a native modal sheet.
Future<void> openSettingsSheet(BuildContext context) {
  return showMacosSheet(
    context: context,
    builder: (_) => const _SettingsSheet(),
  );
}

/// Presentational versions list (kept widget-test friendly: no providers).
class VersionsList extends StatelessWidget {
  const VersionsList({
    super.key,
    required this.versions,
    required this.activeVersion,
    required this.onSetActive,
    required this.onDelete,
    required this.onDownloadLatest,
  });

  final List<InstalledVersion> versions;
  final String? activeVersion;
  final ValueChanged<String> onSetActive;
  final ValueChanged<String> onDelete;
  final VoidCallback onDownloadLatest;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text('Installed versions', style: theme.typography.title3),
          const Spacer(),
          PushButton(
            controlSize: ControlSize.regular,
            onPressed: onDownloadLatest,
            child: const Text('Download latest'),
          ),
        ]),
        const SizedBox(height: 8),
        for (final v in versions)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.canvasColor,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: MacosColors.systemGrayColor.withOpacity(0.3)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chromium ${v.version}', style: theme.typography.body),
                    Text(
                      '${(v.sizeBytes / 1000000).round()} MB · '
                      'sha256 ${v.sha256.substring(0, v.sha256.length.clamp(0, 8))}',
                      style: theme.typography.caption1
                          .copyWith(color: MacosColors.systemGrayColor),
                    ),
                  ],
                ),
              ),
              if (v.version == activeVersion)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text('active',
                      style: TextStyle(color: MacosColors.systemGreenColor)),
                )
              else
                PushButton(
                  controlSize: ControlSize.small,
                  secondary: true,
                  onPressed: () => onSetActive(v.version),
                  child: const Text('Set active'),
                ),
              MacosIconButton(
                icon: const MacosIcon(CupertinoIcons.trash),
                onPressed:
                    v.version == activeVersion ? null : () => onDelete(v.version),
              ),
            ]),
          ),
      ],
    );
  }
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();
  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  final _tabController = MacosTabController(initialIndex: 0, length: 2);
  BinaryManifest? _manifest;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final m = await ref.read(binaryManagerProvider).loadManifest();
    if (mounted) setState(() => _manifest = m);
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _manifest;
    return MacosSheet(
      child: Column(
        children: [
          const SizedBox(height: 16),
          SizedBox(
            width: 280,
            child: MacosSegmentedControl(
              controller: _tabController,
              tabs: const [
                MacosTab(label: 'Versions'),
                MacosTab(label: 'About'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) => IndexedStack(
                index: _tabController.index,
                children: [
                  if (manifest == null)
                    const Center(child: ProgressCircle())
                  else
                    VersionsList(
                      versions: manifest.versions,
                      activeVersion: manifest.activeVersion,
                      onSetActive: (v) async {
                        final bm = ref.read(binaryManagerProvider);
                        await bm.saveManifest(manifest.withActive(v));
                        ref.invalidate(binaryStateProvider);
                        await _reload();
                      },
                      onDelete: (v) async {
                        final bm = ref.read(binaryManagerProvider);
                        final dir = bm.paths.binaryVersionDir(v);
                        if (await dir.exists()) await dir.delete(recursive: true);
                        await bm.saveManifest(manifest.withVersionRemoved(v));
                        await _reload();
                      },
                      onDownloadLatest: () => ref
                          .read(binaryStateProvider.notifier)
                          .downloadLatest(),
                    ),
                  const _AboutTab(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();
  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('CloakManager', style: theme.typography.largeTitle),
        const SizedBox(height: 4),
        const Text('Cross-platform CloakBrowser profile manager'),
        const SizedBox(height: 4),
        const SelectableText('github.com/CloakHQ/cloakbrowser'),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run the dependent tests to verify they pass**

Run: `flutter test test/settings_test.dart test/home_shell_test.dart`
Expected: PASS.

- [ ] **Step 5: Full analyze + suite**

Run: `flutter analyze`
Expected: No issues.
Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 6: Commit Tasks 6 + 7**

```bash
git add lib/screens/home/home_screen.dart lib/screens/home/sidebar.dart lib/screens/settings/settings_screen.dart test/settings_test.dart
git commit -m "feat(ui): MacosWindow sidebar and settings sheet

Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>"
```

---

### Task 8: Final verification on macOS

**Files:** none (verification only)

- [ ] **Step 1: Confirm no Material scaffolding remains in the UI layer**

Run: `rg -n "MaterialApp|Scaffold\(|AppBar\(|TabBar\(|FilledButton|OutlinedButton" lib/`
Expected: No matches in `lib/` (Material `Scaffold`/`AppBar`/`TabBar`/buttons fully replaced). `import 'package:flutter/material.dart' show ThemeMode;` in `app.dart` is allowed.

- [ ] **Step 2: Full analyze + tests**

Run: `flutter analyze && flutter test`
Expected: No issues; all tests pass.

- [ ] **Step 3: Build and run the macOS app**

Run: `flutter run -d macos`
Expected: App launches with a native translucent titlebar; sidebar with search, grouped profiles, and gear/+ buttons; editor toolbar with the General/Stealth/Proxy/Advanced segmented control and Launch/Save/Delete; switching system Appearance (light/dark) and accent color is reflected after relaunch. Manually verify: create a profile, edit fields, open Settings sheet, trigger the delete dialog.

- [ ] **Step 4: Commit any fixes found during manual verification**

```bash
git add -A
git commit -m "fix(ui): macOS redesign polish from manual verification

Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>"
```

---

## Self-Review

**Spec coverage:**
- Dependencies + window chrome → Task 1. ✅
- System light/dark + accent theme → Task 2 (`app_theme.dart`, `themeMode: ThemeMode.system`). ✅
- MacosApp root → Task 2. ✅
- Sidebar with MacosSearchField + grouped rows + status dots + new/settings → Task 6. ✅
- Editor segmented control in toolbar + Launch/Stop/Save/Delete + form primitives + proxy panel + advanced panel + delete dialog → Tasks 4 & 5. ✅
- Onboarding (ProgressBar/PushButton) → Task 2. ✅
- Settings as MacosSheet (Versions/About) → Task 7. ✅
- Cupertino icons + fallback → Task 3. ✅
- All noted test updates (onboarding, home_shell, icon_catalog, editor_switch, delete_profile, proxy_tab, settings) → Tasks 2–7. ✅

**Placeholder scan:** No TBD/TODO; every code step shows full file contents; finder strategy and expected outputs given. The only cross-task dependency (`openSettingsSheet`) is called out explicitly in Tasks 6 and 7 with combined commit.

**Type consistency:** `openSettingsSheet(BuildContext)` defined in Task 7, called in Task 6 with one arg. `filterProfiles(List<Profile>, String)` and `computedArgsPreview(Profile)` signatures preserved. `VersionsList` constructor parameters unchanged. `DraftTextField` public API unchanged. `MacosTabController(initialIndex:, length:)` used consistently in editor and settings.
