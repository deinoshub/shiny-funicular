import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../state/binary_state.dart';
import '../../state/providers.dart';

/// Opens the settings UI as a native modal sheet.
Future<void> openSettingsSheet(BuildContext context) {
  return showMacosSheet(
    context: context,
    builder: (_) => const _SettingsSheet(),
  );
}

/// Presentational versions list (kept widget-test friendly: no providers).
class VersionsList extends StatelessWidget {
  const VersionsList({
    super.key,
    required this.versions,
    required this.activeVersion,
    required this.onSetActive,
    required this.onDelete,
    required this.onDownloadLatest,
  });

  final List<InstalledVersion> versions;
  final String? activeVersion;
  final ValueChanged<String> onSetActive;
  final ValueChanged<String> onDelete;
  final VoidCallback onDownloadLatest;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text('Installed versions', style: theme.typography.title3),
          const Spacer(),
          PushButton(
            controlSize: ControlSize.regular,
            onPressed: onDownloadLatest,
            child: const Text('Download latest'),
          ),
        ]),
        const SizedBox(height: 8),
        for (final v in versions)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.canvasColor,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: MacosColors.systemGrayColor.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chromium ${v.version}', style: theme.typography.body),
                    Text(
                      '${(v.sizeBytes / 1000000).round()} MB · '
                      'sha256 ${v.sha256.substring(0, v.sha256.length.clamp(0, 8))}',
                      style: theme.typography.caption1
                          .copyWith(color: MacosColors.systemGrayColor),
                    ),
                  ],
                ),
              ),
              if (v.version == activeVersion)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text('active',
                      style: TextStyle(color: MacosColors.systemGreenColor)),
                )
              else
                PushButton(
                  controlSize: ControlSize.small,
                  secondary: true,
                  onPressed: () => onSetActive(v.version),
                  child: const Text('Set active'),
                ),
              MacosIconButton(
                icon: const MacosIcon(CupertinoIcons.trash),
                onPressed:
                    v.version == activeVersion ? null : () => onDelete(v.version),
              ),
            ]),
          ),
      ],
    );
  }
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();
  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  final _tabController = MacosTabController(initialIndex: 0, length: 2);
  BinaryManifest? _manifest;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final m = await ref.read(binaryManagerProvider).loadManifest();
    if (mounted) setState(() => _manifest = m);
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _manifest; // nullable — checked below
    return MacosSheet(
      child: Column(
        children: [
          const SizedBox(height: 16),
          SizedBox(
            width: 280,
            child: MacosSegmentedControl(
              controller: _tabController,
              tabs: const [
                MacosTab(label: 'Versions'),
                MacosTab(label: 'About'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) => IndexedStack(
                index: _tabController.index,
                children: [
                  if (manifest == null)
                    const Center(child: ProgressCircle())
                  else
                    VersionsList(
                      versions: manifest.versions,
                      activeVersion: manifest.activeVersion,
                      onSetActive: (v) async {
                        final bm = ref.read(binaryManagerProvider);
                        await bm.saveManifest(manifest.withActive(v));
                        ref.invalidate(binaryStateProvider);
                        await _reload();
                      },
                      onDelete: (v) async {
                        final bm = ref.read(binaryManagerProvider);
                        final dir = bm.paths.binaryVersionDir(v);
                        if (await dir.exists()) await dir.delete(recursive: true);
                        await bm.saveManifest(manifest.withVersionRemoved(v));
                        await _reload();
                      },
                      onDownloadLatest: () => ref
                          .read(binaryStateProvider.notifier)
                          .downloadLatest(),
                    ),
                  const _AboutTab(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();
  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('CloakManager', style: theme.typography.largeTitle),
        const SizedBox(height: 4),
        const Text('Cross-platform CloakBrowser profile manager'),
        const SizedBox(height: 4),
        const SelectableText('github.com/CloakHQ/cloakbrowser'),
      ]),
    );
  }
}
