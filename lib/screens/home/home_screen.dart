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
                    icon: const MacosIcon(CupertinoIcons.gear_solid),
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
