import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
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
        ? theme.primaryColor.withValues(alpha: 0.18)
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
