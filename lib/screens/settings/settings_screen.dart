import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/binary_state.dart';
import '../../state/providers.dart';

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Text('Installed versions',
              style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Download latest'),
            onPressed: onDownloadLatest,
          ),
        ]),
        const SizedBox(height: 8),
        for (final v in versions)
          Card(
            child: ListTile(
              title: Text('Chromium ${v.version}'),
              subtitle: Text('${(v.sizeBytes / 1000000).round()} MB · '
                  'sha256 ${v.sha256.substring(0, v.sha256.length.clamp(0, 8))}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (v.version == activeVersion)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('active',
                        style: TextStyle(color: Colors.green)),
                  )
                else
                  TextButton(
                      onPressed: () => onSetActive(v.version),
                      child: const Text('Set active')),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: v.version == activeVersion
                      ? 'Cannot delete the active version'
                      : 'Delete',
                  onPressed:
                      v.version == activeVersion ? null : () => onDelete(v.version),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  BinaryManifest? _manifest;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final m = await ref.read(binaryManagerProvider).loadManifest();
    if (mounted) setState(() => _manifest = m);
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _manifest;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: const TabBar(tabs: [Tab(text: 'Versions'), Tab(text: 'About')]),
        ),
        body: TabBarView(children: [
          if (manifest == null)
            const Center(child: CircularProgressIndicator())
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
              onDownloadLatest: () =>
                  ref.read(binaryStateProvider.notifier).downloadLatest(),
            ),
          const _AboutTab(),
        ]),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('CloakManager', style: TextStyle(fontSize: 20)),
          SizedBox(height: 4),
          Text('Cross-platform CloakBrowser profile manager'),
          SizedBox(height: 4),
          SelectableText('github.com/CloakHQ/cloakbrowser'),
        ]),
      );
}
