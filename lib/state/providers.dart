import 'package:cloak_core/cloak_core.dart';
import 'package:drift/drift.dart' show LazyDatabase;
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

final proxyTesterProvider = Provider<ProxyTester>((ref) => ProxyTester());
