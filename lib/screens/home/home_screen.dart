import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/profile_list.dart';
import '../../state/providers.dart';
import '../../state/selection.dart';
import '../editor/editor_screen.dart';
import 'sidebar.dart';

Profile? findById(List<Profile> profiles, String? id) {
  if (id == null) return null;
  for (final p in profiles) {
    if (p.id == id) return p;
  }
  return null;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final profile = findById(profiles, id);
    if (profile == null) return;
    final bm = ref.read(binaryManagerProvider);
    final manifest = await bm.loadManifest();
    final active = manifest.active;
    if (active == null) return;
    final exe = bm.executablePathFor(active);
    await ref
        .read(browserLauncherProvider)
        .launch(profile: profile, executablePath: exe);
    await ref
        .read(profileListProvider.notifier)
        .save(profile.copyWith(lastLaunchedAt: DateTime.now().toUtc()));
  }

  Future<void> _stop(WidgetRef ref) async {
    final id = ref.read(selectedProfileIdProvider);
    if (id != null) await ref.read(browserLauncherProvider).stop(id);
  }

  Future<void> _stopAll(WidgetRef ref) =>
      ref.read(browserLauncherProvider).stopAll();
}
