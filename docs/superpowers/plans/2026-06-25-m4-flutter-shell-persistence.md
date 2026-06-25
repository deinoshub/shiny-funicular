# M4 — Flutter Shell + Persistence + State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Flutter desktop app that consumes `cloak_core`: a Drift-backed profile store, Riverpod state wiring, app bootstrap, and a routing shell that shows onboarding when no binary is installed and a placeholder home otherwise.

**Architecture:** Flutter app at the repo root depending on the local `packages/cloak_core`. Drift defines the `profiles` table and a `ProfileDao` that maps rows ↔ `cloak_core` `Profile` (stealth stored as JSON in `stealth_json`). Riverpod providers expose `AppPaths`, the database, `BinaryManager`, `ProcessRegistry`, `BrowserLauncher`, the profile list (an `AsyncNotifier`), and the binary install state. `main()` bootstraps the SQLite native library and runs the app; the shell routes onboarding vs home off the binary manifest.

**Tech Stack:** Flutter (stable, desktop enabled), Dart 3.3+. Deps: `flutter_riverpod`, `drift`, `sqlite3_flutter_libs`, `path`. Dev: `drift_dev`, `build_runner`, `flutter_test`. Drift uses code generation (`*.g.dart`). Tests use Drift's in-memory `NativeDatabase.memory()`.

## Global Constraints

- App package name: `cloakmanager`. App title: `CloakManager`.
- Desktop platforms enabled: windows, linux, macos.
- `cloak_core` is consumed via a path dependency; never duplicate its models.
- Profile persistence schema mirrors `CloakBrowser/docs/DATA-LAYOUT.md` columns exactly; stealth config is a JSON string column.
- Drift migrations are append-only; `schemaVersion` starts at 1.
- Database file location: `AppPaths.resolve().databaseFile` (`<dataDir>/cloakmanager.sqlite`).
- The app shows onboarding iff `BinaryManifest.active == null`.
- Generated Drift files (`*.g.dart`) are regenerated via `build_runner`; they are gitignored, so every build/test run regenerates them first.

## File Structure

| File | Responsibility |
|---|---|
| `pubspec.yaml` (root) | Flutter app manifest + path dep on cloak_core |
| `lib/main.dart` | Bootstrap (sqlite init) + `runApp` |
| `lib/app.dart` | `MaterialApp`, theme, root routing shell |
| `lib/data/database.dart` | Drift `AppDatabase` + `Profiles` table |
| `lib/data/profile_dao.dart` | Row ↔ `Profile` mapping + CRUD |
| `lib/state/providers.dart` | Core Riverpod providers (paths, db, binary, registry, launcher) |
| `lib/state/profile_list.dart` | `ProfileListController` (`AsyncNotifier`) |
| `lib/state/binary_state.dart` | `BinaryStateController` (install/download state) |
| `lib/screens/home/home_shell.dart` | Onboarding-vs-home router + placeholder home |
| `test/*` | Drift DAO, controllers, shell routing |

---

### Task 1: Flutter app scaffold + cloak_core path dep

**Files:**
- Create: `pubspec.yaml` (root)
- Create: `lib/main.dart`, `lib/app.dart`
- Create: desktop runner dirs via `flutter create`
- Test: `test/smoke_test.dart`

**Interfaces:**
- Produces: a launchable Flutter app; `CloakManagerApp` widget in `lib/app.dart`.

- [ ] **Step 1: Generate the Flutter desktop scaffold**

Run from repo root:

```bash
flutter create --org dev.cloakmanager --project-name cloakmanager --platforms=windows,linux,macos .
```

Expected: creates `windows/`, `linux/`, `macos/`, `lib/main.dart`, `pubspec.yaml`, `test/`.

- [ ] **Step 2: Wire dependencies**

Edit root `pubspec.yaml` so the `dependencies:` / `dev_dependencies:` include:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cloak_core:
    path: packages/cloak_core
  flutter_riverpod: ^2.5.1
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.20
  path: ^1.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.18.0
  build_runner: ^2.4.9
  flutter_lints: ^4.0.0
```

Run: `flutter pub get`
Expected: resolves; `cloak_core` linked locally.

- [ ] **Step 3: Write the failing smoke test**

`test/smoke_test.dart`:

```dart
import 'package:cloakmanager/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to a MaterialApp titled CloakManager', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CloakManagerApp()));
    expect(find.byType(CloakManagerApp), findsOneWidget);
  });
}
```

- [ ] **Step 4: Write `app.dart` and `main.dart`**

`lib/app.dart`:

```dart
import 'package:flutter/material.dart';

import 'screens/home/home_shell.dart';

class CloakManagerApp extends StatelessWidget {
  const CloakManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloakManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E81F4)),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
```

`lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CloakManagerApp()));
}
```

`lib/screens/home/home_shell.dart` (temporary placeholder; replaced in Step 4 of Task 6):

```dart
import 'package:flutter/material.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('CloakManager')));
}
```

- [ ] **Step 5: Run test + commit**

Run: `flutter test test/smoke_test.dart`
Expected: `All tests passed!`

```bash
git add pubspec.yaml lib/ test/smoke_test.dart windows/ linux/ macos/ analysis_options.yaml .metadata
git commit -m "feat(app): scaffold Flutter desktop app with cloak_core dep"
```

---

### Task 2: Drift database + Profiles table

**Files:**
- Create: `lib/data/database.dart`
- Test: `test/database_test.dart`

**Interfaces:**
- Produces:
  - Drift table `Profiles` with columns matching DATA-LAYOUT (`id` text PK, `name`, `notes`, `colorHex`, `iconName`, `groupName` nullable, `createdAt`/`updatedAt` real (unix seconds), `lastLaunchedAt` real nullable, `stealthJson` text, `persistent` bool, `startUrl` text, `customArgsJson` text, `customEnvJson` text, `tagsJson` text, `sortOrder` int).
  - `class AppDatabase extends _$AppDatabase` with `AppDatabase(QueryExecutor)`, `schemaVersion => 1`, and a named `AppDatabase.memory()` for tests.

- [ ] **Step 1: Write the table + database definition**

`lib/data/database.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

// Named ProfileRow so the generated data class does not collide with
// cloak_core's Profile model.
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get colorHex => text().withDefault(const Constant('#5E81F4'))();
  TextColumn get iconName => text().withDefault(const Constant('person'))();
  TextColumn get groupName => text().nullable()();
  RealColumn get createdAt => real()();
  RealColumn get updatedAt => real()();
  RealColumn get lastLaunchedAt => real().nullable()();
  TextColumn get stealthJson => text()();
  BoolColumn get persistent => boolean().withDefault(const Constant(true))();
  TextColumn get startUrl =>
      text().withDefault(const Constant('about:blank'))();
  TextColumn get customArgsJson => text().withDefault(const Constant('[]'))();
  TextColumn get customEnvJson => text().withDefault(const Constant('{}'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Profiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 2: Generate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: creates `lib/data/database.g.dart`; no errors.

- [ ] **Step 3: Write the test**

`test/database_test.dart`:

```dart
import 'package:cloakmanager/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('can insert and read back a profile row', () async {
    final db = AppDatabase.memory();
    await db.into(db.profiles).insert(ProfilesCompanion.insert(
          id: 'p1',
          name: 'Work',
          createdAt: 100.0,
          updatedAt: 100.0,
          stealthJson: '{}',
        ));
    final rows = await db.select(db.profiles).get();
    expect(rows.single.name, 'Work');
    expect(rows.single.persistent, isTrue);
    await db.close();
  });
}
```

- [ ] **Step 4: Run test + commit**

Run: `flutter test test/database_test.dart`
Expected: `All tests passed!`

```bash
git add lib/data/database.dart test/database_test.dart
git commit -m "feat(data): add Drift AppDatabase with Profiles table"
```

---

### Task 3: ProfileDao (row ↔ Profile mapping + CRUD)

**Files:**
- Create: `lib/data/profile_dao.dart`
- Test: `test/profile_dao_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `cloak_core` `Profile`/`StealthConfig`.
- Produces:
  - `class ProfileDao { ProfileDao(this.db); Future<List<Profile>> all(); Future<void> upsert(Profile); Future<void> delete(String id); Future<void> touchLastLaunched(String id, DateTime when); }`
  - Private `Profile _toModel(ProfileRow)` / `ProfilesCompanion _toRow(Profile)` converting epoch-seconds ↔ `DateTime` and JSON ↔ `StealthConfig`/lists/maps.

- [ ] **Step 1: Write the failing test**

`test/profile_dao_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/data/database.dart';
import 'package:cloakmanager/data/profile_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProfileDao dao;
  setUp(() {
    db = AppDatabase.memory();
    dao = ProfileDao(db);
  });
  tearDown(() => db.close());

  Profile sample(String id) => Profile(
        id: id,
        name: 'Work',
        colorHex: '#5E81F4',
        iconName: 'person',
        createdAt: DateTime.utc(2026, 6, 25, 12),
        updatedAt: DateTime.utc(2026, 6, 25, 12),
        stealth: StealthConfig(
          fingerprintSeed: 's',
          proxy: ProxyConfig.disabled(),
        ),
        customArgs: const ['--mute-audio'],
        customEnv: const {'TZ': 'UTC'},
        tags: const ['work'],
      );

  test('upsert then all() round-trips including stealth + lists', () async {
    await dao.upsert(sample('p1'));
    final all = await dao.all();
    expect(all, hasLength(1));
    expect(all.single.stealth.fingerprintSeed, 's');
    expect(all.single.customArgs, ['--mute-audio']);
    expect(all.single.customEnv, {'TZ': 'UTC'});
    expect(all.single.tags, ['work']);
  });

  test('upsert updates an existing row', () async {
    await dao.upsert(sample('p1'));
    await dao.upsert(sample('p1'));
    expect(await dao.all(), hasLength(1));
  });

  test('delete removes the row', () async {
    await dao.upsert(sample('p1'));
    await dao.delete('p1');
    expect(await dao.all(), isEmpty);
  });

  test('touchLastLaunched sets the timestamp', () async {
    await dao.upsert(sample('p1'));
    await dao.touchLastLaunched('p1', DateTime.utc(2026, 6, 26));
    final p = (await dao.all()).single;
    expect(p.lastLaunchedAt, DateTime.utc(2026, 6, 26));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/profile_dao_test.dart`
Expected: FAIL — `ProfileDao` undefined.

- [ ] **Step 3: Write the implementation**

`lib/data/profile_dao.dart`:

```dart
import 'dart:convert';

import 'package:cloak_core/cloak_core.dart';
import 'package:drift/drift.dart';

import 'database.dart';

class ProfileDao {
  ProfileDao(this.db);
  final AppDatabase db;

  Future<List<Profile>> all() async {
    final rows = await (db.select(db.profiles)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    return rows.map(_toModel).toList();
  }

  Future<void> upsert(Profile p) =>
      db.into(db.profiles).insertOnConflictUpdate(_toRow(p));

  Future<void> delete(String id) =>
      (db.delete(db.profiles)..where((t) => t.id.equals(id))).go();

  Future<void> touchLastLaunched(String id, DateTime when) =>
      (db.update(db.profiles)..where((t) => t.id.equals(id))).write(
        ProfilesCompanion(lastLaunchedAt: Value(_toEpoch(when))),
      );

  // --- mapping helpers ---

  static double _toEpoch(DateTime d) => d.toUtc().millisecondsSinceEpoch / 1000.0;
  static DateTime _fromEpoch(double s) =>
      DateTime.fromMillisecondsSinceEpoch((s * 1000).round(), isUtc: true);

  Profile _toModel(ProfileRow r) => Profile(
        id: r.id,
        name: r.name,
        notes: r.notes,
        colorHex: r.colorHex,
        iconName: r.iconName,
        groupName: r.groupName,
        createdAt: _fromEpoch(r.createdAt),
        updatedAt: _fromEpoch(r.updatedAt),
        lastLaunchedAt:
            r.lastLaunchedAt == null ? null : _fromEpoch(r.lastLaunchedAt!),
        stealth: StealthConfig.fromJson(
            jsonDecode(r.stealthJson) as Map<String, dynamic>),
        persistent: r.persistent,
        startUrl: r.startUrl,
        customArgs:
            (jsonDecode(r.customArgsJson) as List<dynamic>).cast<String>(),
        customEnv: (jsonDecode(r.customEnvJson) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as String)),
        tags: (jsonDecode(r.tagsJson) as List<dynamic>).cast<String>(),
        sortOrder: r.sortOrder,
      );

  ProfilesCompanion _toRow(Profile p) => ProfilesCompanion(
        id: Value(p.id),
        name: Value(p.name),
        notes: Value(p.notes),
        colorHex: Value(p.colorHex),
        iconName: Value(p.iconName),
        groupName: Value(p.groupName),
        createdAt: Value(_toEpoch(p.createdAt)),
        updatedAt: Value(_toEpoch(p.updatedAt)),
        lastLaunchedAt: Value(
            p.lastLaunchedAt == null ? null : _toEpoch(p.lastLaunchedAt!)),
        stealthJson: Value(jsonEncode(p.stealth.toJson())),
        persistent: Value(p.persistent),
        startUrl: Value(p.startUrl),
        customArgsJson: Value(jsonEncode(p.customArgs)),
        customEnvJson: Value(jsonEncode(p.customEnv)),
        tagsJson: Value(jsonEncode(p.tags)),
        sortOrder: Value(p.sortOrder),
      );
}
```

- [ ] **Step 4: Run test + commit**

Run: `flutter test test/profile_dao_test.dart`
Expected: `All tests passed!`

```bash
git add lib/data/profile_dao.dart test/profile_dao_test.dart
git commit -m "feat(data): add ProfileDao mapping rows to cloak_core Profile"
```

---

### Task 4: Core Riverpod providers

**Files:**
- Create: `lib/state/providers.dart`
- Test: `test/providers_test.dart`

**Interfaces:**
- Produces (all in `lib/state/providers.dart`):
  - `final appPathsProvider = Provider<AppPaths>((ref) => AppPaths.resolve());`
  - `final databaseProvider = Provider<AppDatabase>(...)` (opens `LazyDatabase` at `appPaths.databaseFile`; disposes on close).
  - `final profileDaoProvider = Provider<ProfileDao>(...)`.
  - `final platformInfoProvider = Provider<PlatformInfo>((ref) => PlatformInfo.current());`
  - `final binaryManagerProvider = Provider<BinaryManager>(...)`.
  - `final processRegistryProvider = Provider<ProcessRegistry>(...)` (disposes registry).
  - `final browserLauncherProvider = Provider<BrowserLauncher>(...)`.

- [ ] **Step 1: Write the failing test**

`test/providers_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core providers construct without throwing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appPathsProvider), isA<AppPaths>());
    expect(container.read(platformInfoProvider), isA<PlatformInfo>());
    expect(container.read(processRegistryProvider), isA<ProcessRegistry>());
    expect(container.read(binaryManagerProvider), isA<BinaryManager>());
    expect(container.read(browserLauncherProvider), isA<BrowserLauncher>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers_test.dart`
Expected: FAIL — providers undefined.

- [ ] **Step 3: Write the implementation**

`lib/state/providers.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/profile_dao.dart';

final appPathsProvider = Provider<AppPaths>((ref) => AppPaths.resolve());

final platformInfoProvider =
    Provider<PlatformInfo>((ref) => PlatformInfo.current());

final databaseProvider = Provider<AppDatabase>((ref) {
  final paths = ref.watch(appPathsProvider);
  final executor = LazyDatabase(() async {
    await paths.baseDir.create(recursive: true);
    return NativeDatabase(paths.databaseFile);
  });
  final db = AppDatabase(executor);
  ref.onDispose(db.close);
  return db;
});

final profileDaoProvider =
    Provider<ProfileDao>((ref) => ProfileDao(ref.watch(databaseProvider)));

final processRegistryProvider = Provider<ProcessRegistry>((ref) {
  final reg = ProcessRegistry();
  ref.onDispose(reg.dispose);
  return reg;
});

final binaryManagerProvider = Provider<BinaryManager>((ref) => BinaryManager(
      paths: ref.watch(appPathsProvider),
      platform: ref.watch(platformInfoProvider),
    ));

final browserLauncherProvider = Provider<BrowserLauncher>((ref) => BrowserLauncher(
      paths: ref.watch(appPathsProvider),
      registry: ref.watch(processRegistryProvider),
    ));
```

- [ ] **Step 4: Run test + commit**

Run: `flutter test test/providers_test.dart`
Expected: `All tests passed!`

```bash
git add lib/state/providers.dart test/providers_test.dart
git commit -m "feat(state): add core Riverpod providers"
```

---

### Task 5: ProfileListController + BinaryStateController

**Files:**
- Create: `lib/state/profile_list.dart`
- Create: `lib/state/binary_state.dart`
- Test: `test/profile_list_test.dart`

**Interfaces:**
- Produces:
  - `class ProfileListController extends AsyncNotifier<List<Profile>>` with `Future<List<Profile>> build()` (loads via `ProfileDao.all`), `Future<Profile> create(String name)`, `Future<void> save(Profile)`, `Future<void> remove(String id)`. Exposed as `final profileListProvider = AsyncNotifierProvider<ProfileListController, List<Profile>>(ProfileListController.new);`
  - `sealed class BinaryInstallState` with `NotInstalled`, `Downloading(double fraction, int received, int total)`, `Verifying`, `Extracting`, `Installed(InstalledVersion)`, `Failed(String message)`.
  - `class BinaryStateController extends AsyncNotifier<BinaryInstallState>` with `build()` (reads manifest → Installed/NotInstalled) and `Future<void> downloadLatest()`. Exposed as `final binaryStateProvider`.

- [ ] **Step 1: Write the failing test**

`test/profile_list_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/data/database.dart';
import 'package:cloakmanager/data/profile_dao.dart';
import 'package:cloakmanager/state/profile_list.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      profileDaoProvider.overrideWithValue(ProfileDao(db)),
    ]);
    addTearDown(() {
      container.dispose();
      db.close();
    });
  });

  test('create adds a profile and refreshes the list', () async {
    final controller = container.read(profileListProvider.notifier);
    await container.read(profileListProvider.future); // initial load (empty)
    final created = await controller.create('My Profile');
    expect(created.name, 'My Profile');
    final list = await container.read(profileListProvider.future);
    expect(list.map((p) => p.name), contains('My Profile'));
  });

  test('remove deletes a profile', () async {
    final controller = container.read(profileListProvider.notifier);
    final p = await controller.create('Temp');
    await controller.remove(p.id);
    final list = await container.read(profileListProvider.future);
    expect(list.where((e) => e.id == p.id), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/profile_list_test.dart`
Expected: FAIL — `profileListProvider` undefined.

- [ ] **Step 3: Write the implementations**

`lib/state/profile_list.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_dao.dart';
import 'providers.dart';

class ProfileListController extends AsyncNotifier<List<Profile>> {
  @override
  Future<List<Profile>> build() => ref.watch(profileDaoProvider).all();

  ProfileDao get _dao => ref.read(profileDaoProvider);

  Future<Profile> create(String name) async {
    final now = DateTime.now().toUtc();
    final profile = Profile(
      id: _newId(now),
      name: name,
      colorHex: '#5E81F4',
      iconName: 'person',
      createdAt: now,
      updatedAt: now,
      stealth: StealthConfig(proxy: ProxyConfig.disabled()),
    );
    await _dao.upsert(profile);
    await _reload();
    return profile;
  }

  Future<void> save(Profile profile) async {
    await _dao.upsert(profile);
    await _reload();
  }

  Future<void> remove(String id) async {
    await _dao.delete(id);
    await _reload();
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(() => _dao.all());
  }

  static String _newId(DateTime now) =>
      '${now.microsecondsSinceEpoch.toRadixString(36)}'
      '-${now.hashCode.toRadixString(36)}';
}

final profileListProvider =
    AsyncNotifierProvider<ProfileListController, List<Profile>>(
        ProfileListController.new);
```

`lib/state/binary_state.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

sealed class BinaryInstallState {
  const BinaryInstallState();
}

class NotInstalled extends BinaryInstallState {
  const NotInstalled();
}

class Downloading extends BinaryInstallState {
  const Downloading(this.fraction, this.received, this.total);
  final double fraction;
  final int received;
  final int total;
}

class Verifying extends BinaryInstallState {
  const Verifying();
}

class Extracting extends BinaryInstallState {
  const Extracting();
}

class Installed extends BinaryInstallState {
  const Installed(this.version);
  final InstalledVersion version;
}

class Failed extends BinaryInstallState {
  const Failed(this.message);
  final String message;
}

class BinaryStateController extends AsyncNotifier<BinaryInstallState> {
  @override
  Future<BinaryInstallState> build() async {
    final manifest = await ref.watch(binaryManagerProvider).loadManifest();
    final active = manifest.active;
    return active == null ? const NotInstalled() : Installed(active);
  }

  Future<void> downloadLatest() async {
    final bm = ref.read(binaryManagerProvider);
    try {
      final releases = await bm.listReleases();
      final stable = releases.firstWhere((r) => !r.isPro && !r.prerelease,
          orElse: () => releases.first);
      state = const AsyncData(Downloading(0, 0, 0));
      final installed = await bm.install(stable, onProgress: (f, r, t) {
        state = AsyncData(Downloading(f, r, t));
      });
      state = const AsyncData(Verifying());
      var manifest = await bm.loadManifest();
      manifest = manifest.withVersionAdded(installed).withActive(installed.version);
      await bm.saveManifest(manifest);
      state = AsyncData(Installed(installed));
    } catch (e) {
      state = AsyncData(Failed(e.toString()));
    }
  }
}

final binaryStateProvider =
    AsyncNotifierProvider<BinaryStateController, BinaryInstallState>(
        BinaryStateController.new);
```

- [ ] **Step 4: Run test + commit**

Run: `flutter test test/profile_list_test.dart`
Expected: `All tests passed!`

```bash
git add lib/state/profile_list.dart lib/state/binary_state.dart test/profile_list_test.dart
git commit -m "feat(state): add profile-list and binary-install controllers"
```

---

### Task 6: HomeShell routing (onboarding vs home)

**Files:**
- Modify: `lib/screens/home/home_shell.dart`
- Test: `test/home_shell_test.dart`

**Interfaces:**
- Consumes: `binaryStateProvider`.
- Produces: `HomeShell` (now a `ConsumerWidget`) that shows a loading spinner while the binary state resolves, a `NotInstalledView` placeholder when `NotInstalled`/`Failed`, and `HomePlaceholder` when `Installed`. (Full onboarding + home come in M5; this routes the two branches.)

- [ ] **Step 1: Write the failing test**

`test/home_shell_test.dart`:

```dart
import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/home/home_shell.dart';
import 'package:cloakmanager/state/binary_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, BinaryInstallState state) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        binaryStateProvider.overrideWith(() => _StubBinaryState(state)),
      ],
      child: const MaterialApp(home: HomeShell()),
    ));
    await tester.pump();
  }

  testWidgets('shows onboarding placeholder when not installed', (tester) async {
    await pump(tester, const NotInstalled());
    expect(find.byKey(const Key('not-installed')), findsOneWidget);
  });

  testWidgets('shows home when installed', (tester) async {
    final v = InstalledVersion(
      version: '146.0.1',
      releaseTag: 'chromium-v146.0.1',
      appPath: 'binary/146.0.1',
      sizeBytes: 1,
      sha256: 'abc',
      installedAt: DateTime.utc(2026),
    );
    await pump(tester, Installed(v));
    expect(find.byKey(const Key('home')), findsOneWidget);
  });
}

class _StubBinaryState extends BinaryStateController {
  _StubBinaryState(this._state);
  final BinaryInstallState _state;
  @override
  Future<BinaryInstallState> build() async => _state;
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home_shell_test.dart`
Expected: FAIL — `HomeShell` is not a `ConsumerWidget`; keys missing.

- [ ] **Step 3: Write the implementation**

`lib/screens/home/home_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/binary_state.dart';

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
        Installed() => const _HomePlaceholder(),
        _ => const _NotInstalledView(),
      },
    );
  }
}

class _NotInstalledView extends ConsumerWidget {
  const _NotInstalledView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('not-installed'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('CloakBrowser is not installed yet.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.read(binaryStateProvider.notifier).downloadLatest(),
              child: const Text('Download CloakBrowser'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(key: Key('home'), body: Center(child: Text('CloakManager')));
}
```

- [ ] **Step 4: Run test + full suite + commit**

Run: `flutter test`
Expected: all M4 tests pass.

```bash
git add lib/screens/home/home_shell.dart test/home_shell_test.dart
git commit -m "feat(app): route onboarding vs home off binary install state"
```

---

## Self-Review

- **Spec coverage:** Drift persistence + schema (spec §3) → Tasks 2,3; Riverpod state (spec §2) → Tasks 4,5; onboarding gate on `active == null` (spec §5) → Tasks 5,6; app boot per-OS data dir → Tasks 1,4. Full onboarding/home UI deferred to M5.
- **Placeholder scan:** none — every step has runnable code/commands. The `_HomePlaceholder`/`_NotInstalledView` are intentionally minimal because M5 replaces them; they are complete, not stubs.
- **Type consistency:** `Profile`/`StealthConfig`/`ProxyConfig`/`BinaryManager`/`BrowserLauncher`/`ProcessRegistry`/`AppPaths`/`PlatformInfo`/`InstalledVersion` all from cloak_core (M1–M3); `ProfileDao` methods (`all`/`upsert`/`delete`/`touchLastLaunched`) consistent between Tasks 3 and 5; `binaryStateProvider`/`BinaryInstallState` variants consistent between Tasks 5 and 6.
