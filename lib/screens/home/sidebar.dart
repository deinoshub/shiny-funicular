import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/profile_list.dart';
import '../../state/selection.dart';
import '../../state/tab_titles.dart';
import '../../widgets/icon_catalog.dart';
import '../../widgets/status_dot.dart';
import '../settings/settings_screen.dart';

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
    final tabTitles =
        ref.watch(tabTitlesProvider).valueOrNull ?? const <String, String>{};
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
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
                          subtitle: running.contains(p.id) &&
                                  tabTitles[p.id] != null
                              ? Text(
                                  tabTitles[p.id]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
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
