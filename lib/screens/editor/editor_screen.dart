import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

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
  final _tabController = MacosTabController(initialIndex: 0, length: 4);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

    return MacosScaffold(
      toolBar: ToolBar(
        title: SizedBox(
          width: 500,
          child: MacosSegmentedControl(
            controller: _tabController,
            tabs: const [
              MacosTab(label: 'General'),
              MacosTab(label: 'Stealth'),
              MacosTab(label: 'Proxy'),
              MacosTab(label: 'Advanced'),
            ],
          ),
        ),
        titleWidth: 520,
        actions: [
          _toolBarAction(
            label: isRunning ? 'Stop' : 'Launch',
            icon: isRunning ? CupertinoIcons.stop_fill : CupertinoIcons.play_fill,
            onPressed: () async {
              if (isRunning) {
                await stopProfile(ref, widget.profileId);
              } else {
                final error = await launchProfile(ref, draft);
                if (error != null && context.mounted) {
                  await showMacosAlertDialog(
                    context: context,
                    builder: (_) => MacosAlertDialog(
                      appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle),
                      title: const Text('Launch failed'),
                      message: Text(error),
                      primaryButton: PushButton(
                        controlSize: ControlSize.large,
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ),
                  );
                }
              }
            },
          ),
          _toolBarAction(
            label: 'Save',
            icon: CupertinoIcons.tray_arrow_down,
            onPressed: canSave
                ? () async {
                    await ref.read(profileListProvider.notifier).save(
                        draft.copyWith(updatedAt: DateTime.now().toUtc()));
                  }
                : null,
          ),
          _toolBarAction(
            label: 'Delete',
            icon: CupertinoIcons.trash,
            onPressed: () => _confirmDelete(context, draft.name),
          ),
        ],
      ),
      children: [
        ContentArea(
          builder: (context, scrollController) => AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) => IndexedStack(
              index: _tabController.index,
              children: [
                GeneralTab(draft: draft, onChanged: onChanged),
                StealthTab(draft: draft, onChanged: onChanged),
                ProxyTab(draft: draft, onChanged: onChanged),
                AdvancedTab(draft: draft, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ],
    );
  }

  ToolbarItem _toolBarAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return CustomToolbarItem(
      inOverflowedBuilder: (context) =>
          ToolbarOverflowMenuItem(label: label, onPressed: onPressed),
      inToolbarBuilder: (context) {
        final enabled = onPressed != null;
        return MacosIconButton(
          backgroundColor: MacosColors.transparent,
          disabledColor: MacosColors.transparent,
          boxConstraints: const BoxConstraints(
            minHeight: 26,
            minWidth: 26,
            maxWidth: 64,
            maxHeight: 44,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          onPressed: onPressed,
          icon: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MacosIcon(
                icon,
                size: 16,
                color: MacosColors.systemGrayColor
                    .withValues(alpha: enabled ? 1 : 0.4),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: MacosColors.systemGrayColor
                      .withValues(alpha: enabled ? 1 : 0.4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final confirmed = await showMacosAlertDialog<bool>(
      context: context,
      builder: (ctx) => MacosAlertDialog(
        appIcon: const MacosIcon(CupertinoIcons.trash),
        title: const Text('Delete profile?'),
        message: Text(
          'This permanently removes "$name" and its browser data. '
          'This cannot be undone.',
          textAlign: TextAlign.center,
        ),
        primaryButton: PushButton(
          controlSize: ControlSize.large,
          color: MacosColors.systemRedColor,
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
        secondaryButton: PushButton(
          controlSize: ControlSize.large,
          secondary: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (confirmed != true) return;
    await deleteProfile(ref, widget.profileId);
    ref.read(selectedProfileIdProvider.notifier).state = null;
  }
}
