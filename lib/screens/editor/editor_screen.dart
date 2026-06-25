import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Expanded(
                  child: TabBar(tabs: [
                    Tab(text: 'General'),
                    Tab(text: 'Stealth'),
                    Tab(text: 'Proxy'),
                    Tab(text: 'Advanced'),
                  ]),
                ),
                const SizedBox(width: 8),
                if (isRunning)
                  OutlinedButton.icon(
                    onPressed: () => stopProfile(ref, widget.profileId),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () async {
                      final error = await launchProfile(ref, draft);
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error)));
                      }
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Launch'),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Delete profile',
                  onPressed: () => _confirmDelete(context, draft.name),
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

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text(
            'This permanently removes "$name" and its browser data. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await deleteProfile(ref, widget.profileId);
    ref.read(selectedProfileIdProvider.notifier).state = null;
  }
}
