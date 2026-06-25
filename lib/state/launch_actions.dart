import 'package:cloak_core/cloak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_list.dart';
import 'providers.dart';

/// Launches [profile] with the active CloakBrowser binary.
/// Returns null on success, or an error message string on failure.
Future<String?> launchProfile(WidgetRef ref, Profile profile) async {
  final bm = ref.read(binaryManagerProvider);
  final manifest = await bm.loadManifest();
  final active = manifest.active;
  if (active == null) return 'No active CloakBrowser version installed.';
  final exe = bm.executablePathFor(active);
  try {
    await ref
        .read(browserLauncherProvider)
        .launch(profile: profile, executablePath: exe);
    await ref
        .read(profileListProvider.notifier)
        .save(profile.copyWith(lastLaunchedAt: DateTime.now().toUtc()));
    return null;
  } catch (e) {
    return e.toString();
  }
}

Future<void> stopProfile(WidgetRef ref, String profileId) =>
    ref.read(browserLauncherProvider).stop(profileId);

Future<void> stopAllProfiles(WidgetRef ref) =>
    ref.read(browserLauncherProvider).stopAll();

/// Stops the profile if running, removes its DB row, and deletes its
/// on-disk user-data directory.
Future<void> deleteProfile(WidgetRef ref, String profileId) async {
  await stopProfile(ref, profileId);
  final dir = ref.read(appPathsProvider).profileDir(profileId);
  await ref.read(profileListProvider.notifier).remove(profileId);
  if (await dir.exists()) await dir.delete(recursive: true);
}
