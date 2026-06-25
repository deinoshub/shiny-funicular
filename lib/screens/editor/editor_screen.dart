import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/profile_list.dart';
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
