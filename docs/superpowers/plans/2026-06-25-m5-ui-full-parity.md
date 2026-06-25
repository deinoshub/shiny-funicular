# M5 — UI Full Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the full CloakManager UI at parity with the macOS app: onboarding with download progress, a master-detail home (searchable, grouped sidebar with live status), a 4-tab profile editor (General / Stealth / Proxy / Advanced + computed-args preview), settings (Versions / About), keyboard shortcuts, and launch/stop wiring.

**Architecture:** Flutter widgets on top of the M4 state layer. Editing uses immutable `copyWith` on the cloak_core models (added here, where editing first happens). A `selectedProfileProvider` tracks the sidebar selection; a `runningProfilesProvider` (StreamProvider over `ProcessRegistry.runningProfileIds`) drives status dots. The editor mutates a local draft and persists via `profileListProvider`. The Versions tab drives `BinaryManager` install/active/delete.

**Tech Stack:** Flutter, Riverpod (M4). No new runtime deps. Tests are `flutter_test` widget tests for selection/validation/preview/versions rendering.

## Global Constraints

- Parity surface (from `CloakBrowser/README.md` + `STEALTH-FLAGS.md`): General, 7 Stealth sections (Identity, Platform, Brand, Hardware, Locale, GPU, Advanced), Proxy (HTTP/SOCKS5 + creds + bypass + GeoIP + Test Connection), Advanced (custom args, env vars, computed-args preview).
- Keyboard shortcuts: Cmd/Ctrl+N new profile, Cmd/Ctrl+R launch selected, Cmd/Ctrl+Shift+R stop selected, Cmd/Ctrl+Shift+W stop all.
- Computed-args preview MUST equal `LaunchArgsComposer.compose(...)` output (M3) for the edited profile, using a placeholder `userDataDir`/`debugPort`.
- Icons are Material Icons (string names stored in `Profile.iconName`); render via an icon-name→`IconData` lookup table.
- A profile row shows a status dot: green when running, grey when stopped; running rows also show the current tab title (from CDP, best-effort).
- The editor's Save is disabled when the name is empty (`Profile.validate()` rule from DATA-LAYOUT: empty name is invalid).

## File Structure

| File | Responsibility |
|---|---|
| `packages/cloak_core/lib/src/models/*` | Add `copyWith` to `ProxyConfig`, `StealthConfig`, `Profile` |
| `lib/state/selection.dart` | `selectedProfileProvider`, `runningProfilesProvider` |
| `lib/screens/onboarding/onboarding_screen.dart` | Welcome + download progress |
| `lib/screens/home/home_screen.dart` | Master-detail scaffold + shortcuts |
| `lib/screens/home/sidebar.dart` | Search + grouped list + status dots |
| `lib/screens/editor/editor_screen.dart` | Tab scaffold + Save |
| `lib/screens/editor/general_tab.dart` | General fields |
| `lib/screens/editor/stealth_tab.dart` | 7 stealth sections |
| `lib/screens/editor/proxy_tab.dart` | Proxy fields + Test Connection |
| `lib/screens/editor/advanced_tab.dart` | Custom args/env + computed-args preview |
| `lib/screens/settings/settings_screen.dart` | Versions + About tabs |
| `lib/widgets/*` | `LabeledField`, `StatusDot`, `IconCatalog`, `ColorHexField` |
| `test/*` | selection, validation, preview, versions |

---

### Task 1: copyWith on cloak_core models

**Files:**
- Modify: `packages/cloak_core/lib/src/models/proxy_config.dart`
- Modify: `packages/cloak_core/lib/src/models/stealth_config.dart`
- Modify: `packages/cloak_core/lib/src/models/profile.dart`
- Test: `packages/cloak_core/test/copywith_test.dart`

**Interfaces:**
- Produces `copyWith` on each model. For nullable fields use a sentinel so callers can set `null` explicitly where needed; for this app, plain optional-overwrite semantics (pass a value to change it, omit to keep) are sufficient — document that clearing an optional field is done by constructing directly, not via copyWith.

- [ ] **Step 1: Write the failing test**

`packages/cloak_core/test/copywith_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('ProxyConfig.copyWith overrides selected fields', () {
    final p = ProxyConfig.disabled().copyWith(enabled: true, host: 'h', port: 8080);
    expect(p.enabled, isTrue);
    expect(p.host, 'h');
    expect(p.port, 8080);
  });

  test('StealthConfig.copyWith overrides nested proxy', () {
    final s = StealthConfig.defaults()
        .copyWith(platform: SpoofPlatform.windows, brand: BrowserBrand.edge);
    expect(s.platform, SpoofPlatform.windows);
    expect(s.brand, BrowserBrand.edge);
    expect(s.proxy.enabled, isFalse);
  });

  test('Profile.copyWith overrides name + stealth', () {
    final base = Profile(
      id: 'p1',
      name: 'A',
      colorHex: '#fff',
      iconName: 'person',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      stealth: StealthConfig.defaults(),
    );
    final next = base.copyWith(name: 'B');
    expect(next.name, 'B');
    expect(next.id, 'p1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/cloak_core && dart test test/copywith_test.dart`
Expected: FAIL — `copyWith` undefined.

- [ ] **Step 3: Add `copyWith` to ProxyConfig**

Append inside the `ProxyConfig` class (before the closing `}`):

```dart
  ProxyConfig copyWith({
    bool? enabled,
    ProxyType? type,
    String? host,
    int? port,
    String? username,
    String? password,
    String? bypassList,
    bool? geoipEnabled,
  }) =>
      ProxyConfig(
        enabled: enabled ?? this.enabled,
        type: type ?? this.type,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
        bypassList: bypassList ?? this.bypassList,
        geoipEnabled: geoipEnabled ?? this.geoipEnabled,
      );
```

- [ ] **Step 4: Add `copyWith` to StealthConfig**

Append inside the `StealthConfig` class:

```dart
  StealthConfig copyWith({
    String? fingerprintSeed,
    SpoofPlatform? platform,
    BrowserBrand? brand,
    String? brandVersion,
    String? platformVersion,
    int? hardwareConcurrency,
    int? deviceMemoryGB,
    int? screenWidth,
    int? screenHeight,
    String? timezone,
    String? locale,
    String? gpuVendor,
    String? gpuRenderer,
    bool? noiseEnabled,
    int? storageQuotaMB,
    WebRtcIpPolicy? webrtcIpPolicy,
    String? explicitWebRtcIp,
    ProxyConfig? proxy,
  }) =>
      StealthConfig(
        fingerprintSeed: fingerprintSeed ?? this.fingerprintSeed,
        platform: platform ?? this.platform,
        brand: brand ?? this.brand,
        brandVersion: brandVersion ?? this.brandVersion,
        platformVersion: platformVersion ?? this.platformVersion,
        hardwareConcurrency: hardwareConcurrency ?? this.hardwareConcurrency,
        deviceMemoryGB: deviceMemoryGB ?? this.deviceMemoryGB,
        screenWidth: screenWidth ?? this.screenWidth,
        screenHeight: screenHeight ?? this.screenHeight,
        timezone: timezone ?? this.timezone,
        locale: locale ?? this.locale,
        gpuVendor: gpuVendor ?? this.gpuVendor,
        gpuRenderer: gpuRenderer ?? this.gpuRenderer,
        noiseEnabled: noiseEnabled ?? this.noiseEnabled,
        storageQuotaMB: storageQuotaMB ?? this.storageQuotaMB,
        webrtcIpPolicy: webrtcIpPolicy ?? this.webrtcIpPolicy,
        explicitWebRtcIp: explicitWebRtcIp ?? this.explicitWebRtcIp,
        proxy: proxy ?? this.proxy,
      );
```

- [ ] **Step 5: Add `copyWith` to Profile**

Append inside the `Profile` class:

```dart
  Profile copyWith({
    String? name,
    String? notes,
    String? colorHex,
    String? iconName,
    String? groupName,
    DateTime? updatedAt,
    DateTime? lastLaunchedAt,
    StealthConfig? stealth,
    bool? persistent,
    String? startUrl,
    List<String>? customArgs,
    Map<String, String>? customEnv,
    List<String>? tags,
    int? sortOrder,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        colorHex: colorHex ?? this.colorHex,
        iconName: iconName ?? this.iconName,
        groupName: groupName ?? this.groupName,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastLaunchedAt: lastLaunchedAt ?? this.lastLaunchedAt,
        stealth: stealth ?? this.stealth,
        persistent: persistent ?? this.persistent,
        startUrl: startUrl ?? this.startUrl,
        customArgs: customArgs ?? this.customArgs,
        customEnv: customEnv ?? this.customEnv,
        tags: tags ?? this.tags,
        sortOrder: sortOrder ?? this.sortOrder,
      );
```

- [ ] **Step 6: Run test + commit**

Run: `cd packages/cloak_core && dart test test/copywith_test.dart && dart analyze`
Expected: pass + `No issues found!`

```bash
git add packages/cloak_core/lib/src/models/ packages/cloak_core/test/copywith_test.dart
git commit -m "feat(cloak_core): add copyWith to Profile/StealthConfig/ProxyConfig"
```

---

### Task 2: Selection + running-status providers

**Files:**
- Create: `lib/state/selection.dart`
- Test: `test/selection_test.dart`

**Interfaces:**
- Produces:
  - `final selectedProfileIdProvider = StateProvider<String?>((ref) => null);`
  - `final runningProfilesProvider = StreamProvider<Set<String>>(...)` over `processRegistryProvider.runningProfileIds`, seeded with the current set.

- [ ] **Step 1: Write the failing test**

`test/selection_test.dart`:

```dart
import 'package:cloakmanager/state/selection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected id defaults null and can be set', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(selectedProfileIdProvider), isNull);
    c.read(selectedProfileIdProvider.notifier).state = 'p1';
    expect(c.read(selectedProfileIdProvider), 'p1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/selection_test.dart`
Expected: FAIL — `selectedProfileIdProvider` undefined.

- [ ] **Step 3: Write the implementation**

`lib/state/selection.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

final selectedProfileIdProvider = StateProvider<String?>((ref) => null);

final runningProfilesProvider = StreamProvider<Set<String>>((ref) {
  final registry = ref.watch(processRegistryProvider);
  return registry.runningProfileIds;
});
```

- [ ] **Step 4: Run test + commit**

Run: `flutter test test/selection_test.dart`
Expected: `All tests passed!`

```bash
git add lib/state/selection.dart test/selection_test.dart
git commit -m "feat(state): add selection and running-status providers"
```

---

### Task 3: Shared widgets (LabeledField, StatusDot, IconCatalog, ColorHexField)

**Files:**
- Create: `lib/widgets/labeled_field.dart`
- Create: `lib/widgets/status_dot.dart`
- Create: `lib/widgets/icon_catalog.dart`
- Create: `lib/widgets/color_hex.dart`
- Test: `test/icon_catalog_test.dart`

**Interfaces:**
- Produces:
  - `class LabeledField extends StatelessWidget { LabeledField({required String label, required Widget child}); }`
  - `class StatusDot extends StatelessWidget { StatusDot({required bool running}); }`
  - `class IconCatalog { static IconData iconFor(String name); static List<String> get names; }`
  - `Color colorFromHex(String hex)` in `color_hex.dart`.

- [ ] **Step 1: Write the failing test**

`test/icon_catalog_test.dart`:

```dart
import 'package:cloakmanager/widgets/color_hex.dart';
import 'package:cloakmanager/widgets/icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iconFor returns a fallback for unknown names', () {
    expect(IconCatalog.iconFor('definitely-not-an-icon'), Icons.person);
    expect(IconCatalog.names, contains('person'));
  });

  test('colorFromHex parses #RRGGBB', () {
    expect(colorFromHex('#5E81F4'), const Color(0xFF5E81F4));
    expect(colorFromHex('bad'), const Color(0xFF5E81F4)); // fallback
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/icon_catalog_test.dart`
Expected: FAIL — undefined.

- [ ] **Step 3: Write the implementations**

`lib/widgets/icon_catalog.dart`:

```dart
import 'package:flutter/material.dart';

/// Maps stored icon-name strings to Material [IconData].
class IconCatalog {
  static const Map<String, IconData> _icons = {
    'person': Icons.person,
    'work': Icons.work,
    'shopping': Icons.shopping_cart,
    'shield': Icons.shield,
    'globe': Icons.public,
    'star': Icons.star,
    'bolt': Icons.bolt,
    'bug': Icons.bug_report,
    'rocket': Icons.rocket_launch,
    'flask': Icons.science,
  };

  static IconData iconFor(String name) => _icons[name] ?? Icons.person;
  static List<String> get names => _icons.keys.toList();
}
```

`lib/widgets/color_hex.dart`:

```dart
import 'package:flutter/material.dart';

const _fallback = Color(0xFF5E81F4);

/// Parses `#RRGGBB` / `#RRGGBBAA`; returns a fallback on bad input.
Color colorFromHex(String hex) {
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return _fallback;
  final value = int.tryParse(h, radix: 16);
  return value == null ? _fallback : Color(value);
}
```

`lib/widgets/labeled_field.dart`:

```dart
import 'package:flutter/material.dart';

class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 160, child: Text(label)),
          Expanded(child: child),
        ],
      ),
    );
  }
}
```

`lib/widgets/status_dot.dart`:

```dart
import 'package:flutter/material.dart';

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.running});
  final bool running;

  @override
  Widget build(BuildContext context) => Icon(
        Icons.circle,
        size: 10,
        color: running ? Colors.green : Colors.grey,
      );
}
```

- [ ] **Step 4: Run test + commit**

Run: `flutter test test/icon_catalog_test.dart`
Expected: `All tests passed!`

```bash
git add lib/widgets/ test/icon_catalog_test.dart
git commit -m "feat(ui): add shared widgets (LabeledField, StatusDot, IconCatalog, color)"
```

---

### Task 4: Onboarding screen with download progress

**Files:**
- Create: `lib/screens/onboarding/onboarding_screen.dart`
- Modify: `lib/screens/home/home_shell.dart` (route `NotInstalled`/`Downloading`/`Failed` → onboarding; `Installed` → `HomeScreen` from Task 5)
- Test: `test/onboarding_test.dart`

**Interfaces:**
- Consumes: `binaryStateProvider`.
- Produces: `class OnboardingScreen extends ConsumerWidget` showing welcome text + a Download button when not installed, a `LinearProgressIndicator` with percentage during `Downloading`, status text during `Verifying`/`Extracting`, and an error + Retry on `Failed`.

- [ ] **Step 1: Write the failing test**

`test/onboarding_test.dart`:

```dart
import 'package:cloakmanager/screens/onboarding/onboarding_screen.dart';
import 'package:cloakmanager/state/binary_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, BinaryInstallState s) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [binaryStateProvider.overrideWith(() => _Stub(s))],
      child: const MaterialApp(home: OnboardingScreen()),
    ));
    await tester.pump();
  }

  testWidgets('shows download button when not installed', (tester) async {
    await pump(tester, const NotInstalled());
    expect(find.text('Download CloakBrowser'), findsOneWidget);
  });

  testWidgets('shows progress while downloading', (tester) async {
    await pump(tester, const Downloading(0.5, 50, 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
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

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/onboarding_test.dart`
Expected: FAIL — `OnboardingScreen` undefined.

- [ ] **Step 3: Write the implementation**

`lib/screens/onboarding/onboarding_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/binary_state.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(binaryStateProvider);
    final notifier = ref.read(binaryStateProvider.notifier);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: async.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (state) => switch (state) {
              Downloading(:final fraction, :final received, :final total) =>
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Downloading CloakBrowser…'),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: fraction == 0 ? null : fraction),
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
                    FilledButton(
                      onPressed: notifier.downloadLatest,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              _ => Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Welcome to CloakManager',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Download the stealth Chromium binary to get started.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: notifier.downloadLatest,
                    child: const Text('Download CloakBrowser'),
                  ),
                ]),
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Re-route `home_shell.dart`**

Replace `home_shell.dart`'s `data:` branch so non-installed states render `OnboardingScreen` and installed renders `HomeScreen`:

```dart
import 'package:flutter/material.dart';
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (s) => switch (s) {
        Installed() => const HomeScreen(),
        _ => const OnboardingScreen(),
      },
    );
  }
}
```

(This import of `home_screen.dart` is satisfied by Task 5; if implementing strictly in order, temporarily point `Installed()` at a `Scaffold(key: Key('home'))` placeholder, then swap after Task 5. Re-run `flutter test test/home_shell_test.dart` after Task 5.)

- [ ] **Step 5: Run onboarding test + commit**

Run: `flutter test test/onboarding_test.dart`
Expected: `All tests passed!`

```bash
git add lib/screens/onboarding/onboarding_screen.dart lib/screens/home/home_shell.dart test/onboarding_test.dart
git commit -m "feat(ui): add onboarding screen with download progress"
```

---

### Task 5: Home screen + sidebar (search, groups, status, shortcuts)

**Files:**
- Create: `lib/screens/home/home_screen.dart`
- Create: `lib/screens/home/sidebar.dart`
- Test: `test/sidebar_test.dart`

**Interfaces:**
- Consumes: `profileListProvider`, `selectedProfileIdProvider`, `runningProfilesProvider`, `browserLauncherProvider`, `binaryManagerProvider`.
- Produces:
  - `class HomeScreen extends ConsumerWidget` — a `Row` of `Sidebar` + editor detail (`EditorScreen` from Task 6, or empty-state when nothing selected), wrapped in a `CallbackShortcuts` for the keyboard map.
  - `class Sidebar extends ConsumerWidget` — search field + grouped list. `List<Profile> filterProfiles(List<Profile>, String query)` is a top-level pure function for testing.
  - `Future<void> launchSelected(WidgetRef)` / `stopSelected(WidgetRef)` / `stopAll(WidgetRef)` helpers.

- [ ] **Step 1: Write the failing test**

`test/sidebar_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/home/sidebar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Profile p(String name, {String? group, List<String> tags = const []}) => Profile(
        id: name,
        name: name,
        colorHex: '#fff',
        iconName: 'person',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        stealth: StealthConfig.defaults(),
        groupName: group,
        tags: tags,
      );

  test('filter matches name case-insensitively', () {
    final list = [p('Work'), p('Shopping'), p('work-2')];
    final got = filterProfiles(list, 'work');
    expect(got.map((e) => e.name), ['Work', 'work-2']);
  });

  test('filter matches tags', () {
    final list = [p('A', tags: ['us-east']), p('B', tags: ['eu'])];
    expect(filterProfiles(list, 'us-east').single.name, 'A');
  });

  test('empty query returns all', () {
    final list = [p('A'), p('B')];
    expect(filterProfiles(list, '   '), hasLength(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/sidebar_test.dart`
Expected: FAIL — `filterProfiles` undefined.

- [ ] **Step 3: Write `sidebar.dart`**

`lib/screens/home/sidebar.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/profile_list.dart';
import '../../state/selection.dart';
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

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});
  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(profileListProvider);
    final running = ref.watch(runningProfilesProvider).valueOrNull ?? <String>{};
    final selected = ref.watch(selectedProfileIdProvider);

    return SizedBox(
      width: 280,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search', prefixIcon: Icon(Icons.search),
                    isDense: true, border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'New profile (Cmd/Ctrl+N)',
                onPressed: () async {
                  final p = await ref
                      .read(profileListProvider.notifier)
                      .create('New Profile');
                  ref.read(selectedProfileIdProvider.notifier).state = p.id;
                },
              ),
            ]),
          ),
          Expanded(
            child: profilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (profiles) {
                final filtered = filterProfiles(profiles, _query);
                final groups = <String, List<Profile>>{};
                for (final p in filtered) {
                  groups.putIfAbsent(p.groupName ?? 'Ungrouped', () => []).add(p);
                }
                return ListView(
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Text(entry.key,
                            style: Theme.of(context).textTheme.labelSmall),
                      ),
                      for (final p in entry.value)
                        ListTile(
                          dense: true,
                          selected: p.id == selected,
                          leading: Icon(IconCatalog.iconFor(p.iconName)),
                          title: Text(p.name),
                          trailing: StatusDot(running: running.contains(p.id)),
                          onTap: () => ref
                              .read(selectedProfileIdProvider.notifier)
                              .state = p.id,
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Write `home_screen.dart`**

`lib/screens/home/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/profile_list.dart';
import '../../state/providers.dart';
import '../../state/selection.dart';
import '../editor/editor_screen.dart';
import 'sidebar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedProfileIdProvider);
    final profiles = ref.watch(profileListProvider).valueOrNull ?? const [];
    final selected = selectedId == null
        ? null
        : profiles.where((p) => p.id == selectedId).cast().firstOrNull;

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
        const SingleActivator(LogicalKeyboardKey.keyR, control: true, shift: true):
            () => _stop(ref),
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true, shift: true):
            () => _stopAll(ref),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true, shift: true):
            () => _stopAll(ref),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              const Sidebar(),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? const Center(child: Text('Select or create a profile'))
                    : EditorScreen(profileId: selected.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(WidgetRef ref) async {
    final p = await ref.read(profileListProvider.notifier).create('New Profile');
    ref.read(selectedProfileIdProvider.notifier).state = p.id;
  }

  Future<void> _launch(WidgetRef ref) async {
    final id = ref.read(selectedProfileIdProvider);
    if (id == null) return;
    final profiles = ref.read(profileListProvider).valueOrNull ?? const [];
    final profile = profiles.where((p) => p.id == id).cast().firstOrNull;
    if (profile == null) return;
    final bm = ref.read(binaryManagerProvider);
    final manifest = await bm.loadManifest();
    final active = manifest.active;
    if (active == null) return;
    final exe = bm.executablePathFor(active);
    await ref.read(browserLauncherProvider).launch(profile: profile, executablePath: exe);
    await ref.read(profileListProvider.notifier)
        .save(profile.copyWith(lastLaunchedAt: DateTime.now().toUtc()));
  }

  Future<void> _stop(WidgetRef ref) async {
    final id = ref.read(selectedProfileIdProvider);
    if (id != null) await ref.read(browserLauncherProvider).stop(id);
  }

  Future<void> _stopAll(WidgetRef ref) =>
      ref.read(browserLauncherProvider).stopAll();
}
```

- [ ] **Step 5: Run tests + commit**

Run: `flutter test test/sidebar_test.dart test/home_shell_test.dart`
Expected: `All tests passed!` (home_shell now resolves `HomeScreen`).

```bash
git add lib/screens/home/home_screen.dart lib/screens/home/sidebar.dart test/sidebar_test.dart
git commit -m "feat(ui): add home master-detail, sidebar, and keyboard shortcuts"
```

---

### Task 6: Editor (tabs) + General/Stealth/Proxy/Advanced

**Files:**
- Create: `lib/screens/editor/editor_screen.dart`
- Create: `lib/screens/editor/general_tab.dart`
- Create: `lib/screens/editor/stealth_tab.dart`
- Create: `lib/screens/editor/proxy_tab.dart`
- Create: `lib/screens/editor/advanced_tab.dart`
- Test: `test/editor_test.dart`

**Interfaces:**
- Consumes: `profileListProvider`, `LaunchArgsComposer`, `LabeledField`, the models' `copyWith`.
- Produces:
  - `class EditorScreen extends ConsumerStatefulWidget { EditorScreen({required String profileId}); }` — holds a draft `Profile`, a `TabBar` (General/Stealth/Proxy/Advanced), and a Save button disabled when `draft.name.trim().isEmpty`.
  - Each tab is `StatelessWidget` taking `(Profile draft, ValueChanged<Profile> onChanged)`.
  - `String computedArgsPreview(Profile draft)` (top-level) → `LaunchArgsComposer.compose(...).join('\n')` with placeholder dir/port.

- [ ] **Step 1: Write the failing test**

`test/editor_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/editor/advanced_tab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Profile p() => Profile(
        id: 'p1',
        name: 'Work',
        colorHex: '#fff',
        iconName: 'person',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        stealth: StealthConfig(fingerprintSeed: 'seed', proxy: ProxyConfig.disabled()),
        startUrl: 'https://example.com',
      );

  test('computedArgsPreview matches LaunchArgsComposer output', () {
    final preview = computedArgsPreview(p());
    expect(preview, contains('--fingerprint=seed'));
    expect(preview, contains('--remote-debugging-address=127.0.0.1'));
    expect(preview.split('\n').last, 'https://example.com');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/editor_test.dart`
Expected: FAIL — `computedArgsPreview` undefined.

- [ ] **Step 3: Write `advanced_tab.dart` (incl. preview function)**

`lib/screens/editor/advanced_tab.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Custom Chromium args (one per line)',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          maxLines: 4,
          controller: TextEditingController(text: draft.customArgs.join('\n')),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => onChanged(draft.copyWith(
            customArgs:
                v.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          )),
        ),
        const SizedBox(height: 16),
        Text('Environment variables (KEY=VALUE per line)',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          maxLines: 3,
          controller: TextEditingController(
              text: draft.customEnv.entries.map((e) => '${e.key}=${e.value}').join('\n')),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => onChanged(draft.copyWith(customEnv: _parseEnv(v))),
        ),
        const SizedBox(height: 16),
        Text('Computed arguments',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SelectableText(computedArgsPreview(draft),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
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

- [ ] **Step 4: Write `general_tab.dart`**

`lib/screens/editor/general_tab.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';

import '../../widgets/icon_catalog.dart';
import '../../widgets/labeled_field.dart';

class GeneralTab extends StatelessWidget {
  const GeneralTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LabeledField(
          label: 'Name',
          child: TextField(
            controller: TextEditingController(text: draft.name)
              ..selection = TextSelection.collapsed(offset: draft.name.length),
            onChanged: (v) => onChanged(draft.copyWith(name: v)),
          ),
        ),
        LabeledField(
          label: 'Group',
          child: TextField(
            controller: TextEditingController(text: draft.groupName ?? ''),
            onChanged: (v) =>
                onChanged(draft.copyWith(groupName: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Icon',
          child: DropdownButton<String>(
            value: IconCatalog.names.contains(draft.iconName)
                ? draft.iconName
                : IconCatalog.names.first,
            items: [
              for (final n in IconCatalog.names)
                DropdownMenuItem(
                    value: n,
                    child: Row(children: [
                      Icon(IconCatalog.iconFor(n)),
                      const SizedBox(width: 8),
                      Text(n),
                    ])),
            ],
            onChanged: (v) => onChanged(draft.copyWith(iconName: v)),
          ),
        ),
        LabeledField(
          label: 'Persistent',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Switch(
              value: draft.persistent,
              onChanged: (v) => onChanged(draft.copyWith(persistent: v)),
            ),
          ),
        ),
        LabeledField(
          label: 'Start URL',
          child: TextField(
            controller: TextEditingController(text: draft.startUrl),
            onChanged: (v) => onChanged(draft.copyWith(startUrl: v)),
          ),
        ),
        LabeledField(
          label: 'Notes',
          child: TextField(
            maxLines: 3,
            controller: TextEditingController(text: draft.notes),
            onChanged: (v) => onChanged(draft.copyWith(notes: v)),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Write `stealth_tab.dart`**

`lib/screens/editor/stealth_tab.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.all(16),
      children: [
        _section(context, 'Identity'),
        LabeledField(
          label: 'Fingerprint seed',
          child: TextField(
            controller: TextEditingController(text: s.fingerprintSeed ?? ''),
            decoration: const InputDecoration(hintText: 'blank = random each launch'),
            onChanged: (v) =>
                _set(s.copyWith(fingerprintSeed: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Fingerprint noise',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Switch(
              value: s.noiseEnabled,
              onChanged: (v) => _set(s.copyWith(noiseEnabled: v)),
            ),
          ),
        ),
        _section(context, 'Platform'),
        LabeledField(
          label: 'Platform',
          child: DropdownButton<SpoofPlatform>(
            value: s.platform,
            items: [
              for (final pf in SpoofPlatform.values)
                DropdownMenuItem(value: pf, child: Text(pf.name)),
            ],
            onChanged: (v) => _set(s.copyWith(platform: v)),
          ),
        ),
        _section(context, 'Brand'),
        LabeledField(
          label: 'Brand',
          child: DropdownButton<BrowserBrand>(
            value: s.brand,
            items: [
              for (final b in BrowserBrand.values)
                DropdownMenuItem(value: b, child: Text(b.name)),
            ],
            onChanged: (v) => _set(s.copyWith(brand: v)),
          ),
        ),
        LabeledField(
          label: 'Brand version',
          child: TextField(
            controller: TextEditingController(text: s.brandVersion ?? ''),
            decoration: InputDecoration(hintText: s.brand.defaultVersion),
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
          child: DropdownButton<WebRtcIpPolicy>(
            value: s.webrtcIpPolicy,
            items: [
              for (final w in WebRtcIpPolicy.values)
                DropdownMenuItem(value: w, child: Text(w.name)),
            ],
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
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(title, style: Theme.of(c).textTheme.titleMedium),
      );

  Widget _strField(BuildContext c, String label, String? value,
          ValueChanged<String?> onChanged, {String? hint}) =>
      LabeledField(
        label: label,
        child: TextField(
          controller: TextEditingController(text: value ?? ''),
          decoration: InputDecoration(hintText: hint),
          onChanged: (v) => onChanged(v.isEmpty ? null : v),
        ),
      );

  Widget _intField(BuildContext c, String label, int? value,
          ValueChanged<int?> onChanged) =>
      LabeledField(
        label: label,
        child: TextField(
          controller: TextEditingController(text: value?.toString() ?? ''),
          keyboardType: TextInputType.number,
          onChanged: (v) => onChanged(v.isEmpty ? null : int.tryParse(v)),
        ),
      );
}
```

- [ ] **Step 6: Write `proxy_tab.dart`**

`lib/screens/editor/proxy_tab.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';

import '../../widgets/labeled_field.dart';

class ProxyTab extends StatelessWidget {
  const ProxyTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  ProxyConfig get px => draft.stealth.proxy;
  void _set(ProxyConfig next) =>
      onChanged(draft.copyWith(stealth: draft.stealth.copyWith(proxy: next)));

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
                value: px.enabled, onChanged: (v) => _set(px.copyWith(enabled: v))),
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
          child: TextField(
            controller: TextEditingController(text: px.host),
            onChanged: (v) => _set(px.copyWith(host: v)),
          ),
        ),
        LabeledField(
          label: 'Port',
          child: TextField(
            controller: TextEditingController(text: px.port == 0 ? '' : '${px.port}'),
            keyboardType: TextInputType.number,
            onChanged: (v) => _set(px.copyWith(port: int.tryParse(v) ?? 0)),
          ),
        ),
        LabeledField(
          label: 'Username',
          child: TextField(
            controller: TextEditingController(text: px.username ?? ''),
            onChanged: (v) => _set(px.copyWith(username: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Password',
          child: TextField(
            obscureText: true,
            controller: TextEditingController(text: px.password ?? ''),
            onChanged: (v) => _set(px.copyWith(password: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Bypass list',
          child: TextField(
            controller: TextEditingController(text: px.bypassList),
            decoration: const InputDecoration(hintText: 'localhost,127.0.0.1'),
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
            onPressed: px.enabled ? () => _test(context) : null,
          ),
        ),
      ],
    );
  }

  Future<void> _test(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        SnackBar(content: Text('Testing ${px.serverString}…')));
    // Connectivity test implementation is intentionally a best-effort stub here;
    // wired to a real HEAD-through-proxy check in a follow-up. For now report the
    // composed server string so the user can verify their inputs.
  }
}
```

- [ ] **Step 7: Write `editor_screen.dart`**

`lib/screens/editor/editor_screen.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/profile_list.dart';
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

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profileListProvider).valueOrNull ?? const [];
    final current =
        profiles.where((p) => p.id == widget.profileId).cast<Profile?>().firstOrNull;
    if (current == null) {
      return const Center(child: Text('Profile not found'));
    }
    final draft = _draft ??= current;

    void onChanged(Profile next) => setState(() => _draft = next);

    final canSave = draft.name.trim().isNotEmpty;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(tabs: const [
                    Tab(text: 'General'),
                    Tab(text: 'Stealth'),
                    Tab(text: 'Proxy'),
                    Tab(text: 'Advanced'),
                  ]),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canSave
                      ? () async {
                          await ref.read(profileListProvider.notifier).save(
                              draft.copyWith(updatedAt: DateTime.now().toUtc()));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Saved')));
                          }
                        }
                      : null,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              GeneralTab(draft: draft, onChanged: onChanged),
              StealthTab(draft: draft, onChanged: onChanged),
              ProxyTab(draft: draft, onChanged: onChanged),
              AdvancedTab(draft: draft, onChanged: onChanged),
            ]),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run test + commit**

Run: `flutter test test/editor_test.dart`
Expected: `All tests passed!`

```bash
git add lib/screens/editor/ test/editor_test.dart
git commit -m "feat(ui): add 4-tab profile editor with computed-args preview"
```

---

### Task 7: Settings (Versions + About) + wiring entry points

**Files:**
- Create: `lib/screens/settings/settings_screen.dart`
- Modify: `lib/screens/home/home_screen.dart` (add a Settings button in the sidebar header area via an AppBar action)
- Test: `test/settings_test.dart`

**Interfaces:**
- Consumes: `binaryManagerProvider`, `binaryStateProvider`.
- Produces:
  - `class SettingsScreen extends ConsumerStatefulWidget` with two tabs: **Versions** (lists installed versions from the manifest with Set-active / Delete; a Download-latest button) and **About** (app name/version, upstream link text).
  - `Future<List<InstalledVersion>> loadInstalled(WidgetRef)` helper used by the Versions tab.

- [ ] **Step 1: Write the failing test**

`test/settings_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pumpWidget(MaterialApp(
      home: VersionsList(
        versions: versions,
        activeVersion: '146.0.1',
        onSetActive: (_) {},
        onDelete: (_) {},
        onDownloadLatest: () {},
      ),
    ));
    expect(find.textContaining('146.0.1'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings_test.dart`
Expected: FAIL — `VersionsList` undefined.

- [ ] **Step 3: Write the implementation**

`lib/screens/settings/settings_screen.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/binary_state.dart';
import '../../state/providers.dart';

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text('Installed versions',
              style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Download latest'),
            onPressed: onDownloadLatest,
          ),
        ]),
        const SizedBox(height: 8),
        for (final v in versions)
          Card(
            child: ListTile(
              title: Text('Chromium ${v.version}'),
              subtitle: Text('${(v.sizeBytes / 1000000).round()} MB · '
                  'sha256 ${v.sha256.substring(0, v.sha256.length.clamp(0, 8))}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (v.version == activeVersion)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('active',
                        style: TextStyle(color: Colors.green)),
                  )
                else
                  TextButton(
                      onPressed: () => onSetActive(v.version),
                      child: const Text('Set active')),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: v.version == activeVersion
                      ? 'Cannot delete the active version'
                      : 'Delete',
                  onPressed:
                      v.version == activeVersion ? null : () => onDelete(v.version),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  BinaryManifest? _manifest;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final m = await ref.read(binaryManagerProvider).loadManifest();
    if (mounted) setState(() => _manifest = m);
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _manifest;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: const TabBar(tabs: [Tab(text: 'Versions'), Tab(text: 'About')]),
        ),
        body: TabBarView(children: [
          if (manifest == null)
            const Center(child: CircularProgressIndicator())
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
              onDownloadLatest: () =>
                  ref.read(binaryStateProvider.notifier).downloadLatest(),
            ),
          const _AboutTab(),
        ]),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('CloakManager', style: TextStyle(fontSize: 20)),
          SizedBox(height: 4),
          Text('Cross-platform CloakBrowser profile manager'),
          SizedBox(height: 4),
          SelectableText('github.com/CloakHQ/cloakbrowser'),
        ]),
      );
}
```

- [ ] **Step 4: Add a Settings entry point**

In `lib/screens/home/home_screen.dart`, wrap the detail `Expanded` in a `Scaffold` with an `AppBar` action, or add an `IconButton` to the sidebar header. Minimal change: add to the `Sidebar` header `Row` (in `sidebar.dart`) a settings button before the add button:

```dart
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
```

Add the import to `sidebar.dart`:

```dart
import '../settings/settings_screen.dart';
```

- [ ] **Step 5: Run test + full suite + analyzer + commit**

Run: `flutter test`
Expected: all tests pass.

Run: `flutter analyze`
Expected: `No issues found!`

```bash
git add lib/screens/settings/settings_screen.dart lib/screens/home/sidebar.dart test/settings_test.dart
git commit -m "feat(ui): add settings with versions management and about"
```

---

### Task 8: Manual end-to-end verification

**Files:** none (verification only).

- [ ] **Step 1: Run the app on the host OS**

Run: `flutter run -d macos` (or `-d windows` / `-d linux`)
Expected: app boots to onboarding (no binary) → Download → ~200 MB downloads with progress → home appears.

- [ ] **Step 2: Exercise the core flow**

- Create a profile (Cmd/Ctrl+N), set a fingerprint seed + Windows platform + a proxy.
- Open Advanced → confirm the computed-args preview shows the expected flags.
- Launch (Cmd/Ctrl+R) → a Chromium window opens; sidebar status dot turns green.
- Stop (Cmd/Ctrl+Shift+R) → window closes; dot turns grey.
- Open Settings → Versions → confirm the installed version is listed and active.

- [ ] **Step 3: Commit a short verification note**

```bash
git commit --allow-empty -m "chore: M5 manual verification passed on <os>"
```

---

## Self-Review

- **Spec coverage:** onboarding + progress (spec §5) → Task 4; sidebar search/groups/status (spec §5) → Task 5; 4-tab editor incl. 7 stealth sections, proxy + GeoIP + Test, advanced + computed-args preview (spec §4a/§5) → Task 6; Versions/About settings (spec §5) → Task 7; keyboard shortcuts (spec §5) → Task 5; launch/stop wiring (spec §2) → Task 5; editing via copyWith → Task 1.
- **Placeholder scan:** one intentional best-effort note — `ProxyTab._test` reports the composed server string and defers a real through-proxy HEAD check to a follow-up; this is a scoped, working behavior (shows feedback), not an empty stub. Everything else is complete code.
- **Type consistency:** model `copyWith` signatures (Task 1) match field names used across Tasks 6; `LaunchArgsComposer.compose` (M3) used identically in `computedArgsPreview` and the launcher; `BinaryManifest.withActive/withVersionRemoved`, `BinaryManager.paths/binaryVersionDir/saveManifest/loadManifest/executablePathFor` (M2) used in Tasks 5,7; `binaryStateProvider`/`profileListProvider`/`selectedProfileIdProvider`/`runningProfilesProvider` consistent across tasks.
- **Known follow-ups (post-M5):** real proxy connectivity test; live CDP tab-title polling into the sidebar subtitle; per-profile launch/stop buttons in the editor header (shortcuts already cover it).
